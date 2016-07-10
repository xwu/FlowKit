//
//  EllipsoidGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct EllipsoidGate : Gate {
  public let dimensions: [String]
  public let means: [Float]
  public let covariances: [Float]
  public let distanceSquared: Float
  internal let _lowerTriangle: [Float]?

  // The following properties are computed only for two-dimensional gates
  public let halfAxes: (Float, Float)?
  public let rotation: Float?

  public init(
    dimensions: [String],
    means: [Float], covariances: [Float], distanceSquared: Float
  ) {
    precondition(dimensions.count == means.count &&
      means.count * means.count == covariances.count)

    var halfAxes: (Float, Float)? = nil
    var rotation: Float? = nil
    if dimensions.count == 2 {
      let (a, b, c, d) =
        (covariances[0], covariances[1], covariances[2], covariances[3])
      let tr = a + d
      let det = a * d - b * c
      // We need a symmetric, positive-definite matrix
      if b == c && tr > 0 && det > 0 {
        // Compute eigenvalues
        let l1 = tr / 2 + sqrt(tr * tr / 4 - det)
        let l2 = tr / 2 - sqrt(tr * tr / 4 - det)
        halfAxes = (sqrt(l1 * distanceSquared), sqrt(l2 * distanceSquared))
        rotation = atan(c / (l1 - d))
      }
    }
    self.halfAxes = halfAxes
    self.rotation = rotation

    self.dimensions = dimensions
    self.means = means
    self.covariances = covariances
    self.distanceSquared = distanceSquared

    // Cholesky factorization of covariance matrix
    if dimensions.count > 1 {
      var uplo = "L".cString(using: .utf8)!
      var n = Int32(dimensions.count)
      var a = covariances, lda = n, info = 0 as Int32
      spotrf_(&uplo, &n, &a, &lda, &info)
      // If `info` isn't 0, covariance matrix had illegal values or wasn't
      // positive definite
      _lowerTriangle = (info == 0) ? a : nil
    } else {
      _lowerTriangle = nil
    }
  }

  public func masking(_ population: Population) -> Population? {
    let dc = dimensions.count, ec = population.root.count
    guard var a = _lowerTriangle else { return nil }

    // Subtract means from events
    var c = [Float](repeating: 0, count: dc * ec)
    for (i, d) in dimensions.enumerated() {
      catlas_sset(Int32(ec), -means[i], &c + i, Int32(dc))
      guard let values = population.root.events[d] else { return nil }
      values.withUnsafeBufferPointer {
        cblas_saxpy(Int32(ec), 1, $0.baseAddress!, 1, &c + i, Int32(dc))
      }
    }
    // Solve for b: covariance * b = c
    //
    // Note that `a` contains the triangular factor L from the Cholesky
    // factorization of the covariance matrix
    //
    // Recall again that LAPACK takes matrices in column-major order, which is
    // why `c` is laid out in memory the way it is, i.e.:
    // event 0 parameter 0, event 0 parameter 1, ... event 0 parameter n,
    // event 1 parameter 0, event 1 parameter 1, ... event 1 parameter n,
    // ...
    // event m parameter 0, event m parameter 1, ... event m parameter n
    var uplo = "L".cString(using: .utf8)!
    var n = Int32(dc), m = Int32(ec)
    var lda = n, b = c, ldb = lda, info = 0 as Int32
    spotrs_(&uplo, &n, &m, &a, &lda, &b, &ldb, &info)
    // If `info` isn't 0, unsuccessful computation of matrix solution
    guard info == 0 else { return nil }

    // Multiply c and b element-wise
    vDSP_vmul(&c, 1, &b, 1, &b, 1, UInt(dc * ec))
    // Sum elements of b row-wise; we'll reuse c for storage
    /* c.removeLast((dc - 1) * ec) */
    catlas_sset(Int32(ec), 0, &c, 1)
    for i in 0..<dc {
      b.withUnsafeMutableBufferPointer {
        cblas_saxpy(Int32(ec), 1, $0.baseAddress! + i, Int32(dc), &c, 1)
      }
    }

    var result = [UInt8](repeating: 0, count: ec)
    vDSP_vlim(c, 1, [distanceSquared.nextUp], [-1 as Float], &b, 1, UInt(ec))
    vDSP_vthres(b, 1, [0 as Float], &c, 1, UInt(ec))
    vDSP_vfixu8(c, 1, &result, 1, UInt(ec))
    let mask = BitVector(result)
    return Population(population, mask: mask)
  }
}
