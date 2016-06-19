//
//  Compensation.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/18/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct Compensation {
  public let detectors: [String]
  public let fluorochromes: [String]?
  public let matrix: [Float] /* row-major */
  public let isInverted: Bool

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
    guard let c = strings.first, count = Int(c) else { return nil }
    // Matrix must be square (preceded by a list of parameter names)
    guard strings.count - 1 == count * (1 + count) else { return nil }
    let detectors = [String](strings[1...count])
    let matrix = strings.suffix(from: count + 1).map { Float($0) ?? Float.nan }
    // All matrix entries must be finite
    guard
      matrix.count == (matrix.filter { $0.isFinite }.count)
      else { return nil }
    self.init(detectors: detectors, matrix: matrix)
  }

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

  internal func _unscramble(for sample: Sample) -> ([String], [Float])? {
    let d = detectors.count
    let f = (fluorochromes ?? detectors).count
    let p = sample.parameters.count
    let map = detectors.map { sample.parameters.index(of: $0) }.flatMap { $0 }
    // We cannot proceed if any detector is not found in the sample's parameters
    guard d == map.count else { return nil }

    // Make a copy of `sample.parameters`, to be modified by substituting
    // fluorochrome names (if any) for detector names
    var parameters = sample.parameters
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
      //TODO: implement support for overdetermined systems
      return nil
    }
    return (parameters, result)
  }

  public func unmix(_ sample: Sample) {
    guard let (parameters, matrix) = _unscramble(for: sample) else { return }
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
          m, n, k, 1, matrix, m, $0.baseAddress, k, 1, &result, m
        )
      }
    } else if parameters.count != sample.parameters.count {
      //TODO: implement support for overdetermined systems
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

    // Populate `sample.events` with any new dimensions generated and replace
    // any existing dimensions that may have been modified by unmixing
    let s = Set(parameters)
      .subtracting(Set(sample.events.keys))
      .union(Set(fluorochromes ?? detectors))
    for (i, p) in parameters.enumerated() {
      guard s.contains(p) else { continue }
      sample.events[p] = [Float](
        result[i * sample.count..<(i + 1) * sample.count]
      )
    }
  }
}
