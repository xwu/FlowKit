//
//  Compensation.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/18/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A compensation or spillover matrix to correct flow cytometry data for spectral
  emission overlap.

  You can create a compensation matrix based on keyword data from a given sample
  or from a row-major array of coefficients.
*/
public struct Compensation {
  /**
    The short names for uncompensated parameters, which are the columns of the
    compensation matrix (unless inverted).
  */
  public let detectors: [String]

  /**
    The optional short names for compensated parameters, which are the rows of
    the compensation matrix (unless inverted). If specified, they must be
    distinct from the short names of uncompensated parameters; if unspecified,
    compensated parameters use the same names as their uncompensated
    counterparts.
  */
  public let fluorochromes: [String]?

  /**
    The coefficients for the compensation matrix in _row-major_ order.
  */
  public let matrix: [Float]

  /**
    Indicates whether `matrix` is considered to hold the (pseudo)inverse of the
    compensation matrix.
  */
  public let isInverted: Bool

  /**
    Create the acquisition matrix of the given sample. The matrix must be square
    and coefficients must be finite.

    - Note: The matrix is created using the value for the first key in the
      following list contained in the sample's keywords: $SPILLOVER, SPILL,
      $COMP, SPILLOVER, $SPILL, COMP.
  */
  public init?(_ sample: Sample) {
    let keys = ["$SPILLOVER", "SPILL", "$COMP", "SPILLOVER", "$SPILL", "COMP"]
    var strings = [String]()
    for k in keys {
      if let v = sample.keywords[k] {
        strings = v.components(separatedBy: ",").map {
          $0.trimmingCharacters(in: .whitespaces)
        }
        break
      }
    }
    guard let c = strings.first, let count = Int(c) else { return nil }
    // Matrix must be square (preceded by a list of parameter names)
    guard strings.count - 1 == count * (1 + count) else { return nil }
    let detectors = [String](strings[1...count])
    let matrix = strings.suffix(from: count + 1).map { Float($0) ?? Float.nan }
    // All matrix coefficients must be finite
    guard
      matrix.count == (matrix.filter { $0.isFinite }.count)
      else { return nil }
    self.init(detectors: detectors, matrix: matrix)
  }

  /// Create a new compensation matrix with the given properties.
  public init(
    detectors: [String], fluorochromes: [String]? = nil,
    matrix: [Float], isInverted: Bool = false
  ) {
    let d = detectors.count, f = (fluorochromes ?? detectors).count
    precondition(d >= f && matrix.count == d * f)

    self.detectors = detectors
    self.fluorochromes = fluorochromes
    self.matrix = matrix
    self.isInverted = isInverted
  }

  internal func _unscramble(for parameters: [String]) -> ([String], [Float])? {
    // We'll eventually mutate `parameters` by substituting fluorochrome names
    // (if any) for detector names
    var parameters = parameters

    let d = detectors.count
    let f = (fluorochromes ?? detectors).count
    let p = parameters.count
#if swift(>=4.1)
    let map = detectors.map { parameters.index(of: $0) }.compactMap { $0 }
#else
    let map = detectors.map { parameters.index(of: $0) }.flatMap { $0 }
#endif
    // We cannot proceed if any detector is not found among `parameters`
    guard d == map.count else { return nil }

    // Set up an identity matrix so that parameters not being unmixed are
    // preserved after compensation is applied
    var result = [Float](repeating: 0, count: p * p)
    for i in 0..<p {
      result[i * (p + 1)] = 1
    }
    if d == f {
      if let fluorochromes = fluorochromes {
        for (i, j) in map.enumerated() {
          parameters[j] = fluorochromes[i]
        }
      }
      // Our task is greatly simplified when `d == f`
      // The following is correct whether or not `isInverted == true`
      for (i, v) in matrix.enumerated() {
        let oldRow = i / d, oldColumn = i % d
        let newRow = map[oldRow], newColumn = map[oldColumn]
        result[newRow * p + newColumn] = v
      }
    } else {
      //TODO: Implement support for overdetermined systems
      return nil
    }
    return (parameters, result)
  }

  /**
    Spectrally unmix the given sample using the receiver. If successful,
    compensated event data, separated by parameter, are stored in
    `sample.events` and keyed either to fluorochrome names if they are specified
    or detector names otherwise.

    - Note: Overdetermined systems (i.e., non-square compensation matrices) are
      not currently supported.
  */
  public func unmix(_ sample: Sample) {
    //TODO: Throw if unmixing is unsuccessful
    guard
      let (parameters, matrix) = _unscramble(for: sample.parameters)
      else { return }
    var result: [Float]

    if isInverted {
      // We need to compute `_rawEvents` * `matrix`
      //
      // We use BLAS here but LAPACK below, so for consistency stick with
      // column-major ordering, which is an option for BLAS but required for
      // LAPACK; thus, `_rawEvents` and the inverted `matrix` are in effect
      // transposed, and we need to compute instead:
      //
      // transpose(`matrix`) * transpose(`_rawEvents`)
      result = [Float](repeating: 0, count: parameters.count * sample.count)
      let m = Int32(parameters.count)
      let n = Int32(sample.count), k = Int32(sample.parameters.count)
      // Note the (potential) difference between `m` and `k`
      sample._rawEvents.withUnsafeBufferPointer {
        cblas_sgemm(
          CblasColMajor, CblasNoTrans, CblasNoTrans,
          m, n, k, 1, matrix, m, $0.baseAddress!, k, 1, &result, m
        )
      }
    } else if parameters.count != sample.parameters.count {
      //TODO: Implement support for overdetermined systems
      return
    } else {
      // We need to solve for b:
      // transpose(`matrix`) * `b` = transpose(`_rawEvents`)
      //
      // Since LAPACK takes matrices in column-major ordering, the existing
      // arrays `matrix` and `_rawEvents` are in effect transposed when passed
      // into LAPACK routines
      //
      // We use the LAPACK function `sgesv_()` to solve the system of linear
      // equations AX = B, using transpose(`matrix`) as A and using
      // transpose(`_rawEvents`) as B
      var n = Int32(parameters.count), lda = n, ldb = n
      var nrhs = Int32(sample.count)
      // After the routine returns, `a` will hold the factors L and U from the
      // factorization A = P*L*U
      var a = matrix
      var ipiv = [Int32]()
      ipiv.reserveCapacity(parameters.count)
      // We need a copy of `_rawEvents` to be modified in-place
      result = sample._rawEvents
      var info = 0 as Int32
      sgesv_(&n, &nrhs, &a, &lda, &ipiv, &result, &ldb, &info)
      // Computation was unsuccessful if `info != 0`
      guard info == 0 else { return }
    }

    // Transpose the result; note that vDSP takes matrices in row-major ordering
    vDSP_mtrans(
      result, 1, &result, 1, UInt(parameters.count), UInt(sample.count)
    )
    // Populate `sample.events` with any new dimensions generated and replace
    // any existing dimensions that may have been modified by unmixing
    let s = Set(parameters)
      .subtracting(Set(sample.events.keys))
      .union(Set(fluorochromes ?? detectors))
    for (i, p) in parameters.enumerated() where s.contains(p) {
      sample.events[p] = [Float](
        result[i * sample.count..<(i + 1) * sample.count]
      )
    }
  }
}

extension Compensation : Equatable {
  public static func == (lhs: Compensation, rhs: Compensation) -> Bool {
    // For simplicity, let's not try to compute a matrix inverse and determine
    // whether coefficients are _approximately_ equal
    guard lhs.isInverted == rhs.isInverted else { return false }

    // If detectors are listed in the same order, then the comparison is simple
    if lhs.detectors == rhs.detectors {
      let f0 = lhs.fluorochromes ?? lhs.detectors
      let f1 = rhs.fluorochromes ?? rhs.detectors
      return f0 == f1 && lhs.matrix == rhs.matrix
    }

    // Get a rearranged list of fluorochromes and a rearranged matrix for `lhs`
    // after matching the order of detectors to that of `rhs`; if any detectors
    // in `rhs` aren't found in `lhs`, then `_unscramble(for:)` returns nil
    guard
      lhs.detectors.count == rhs.detectors.count,
      let (f0, m0) = lhs._unscramble(for: rhs.detectors)
      else { return false }
    return f0 == (rhs.fluorochromes ?? rhs.detectors) && m0 == rhs.matrix
  }
}
