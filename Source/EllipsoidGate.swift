//
//  EllipsoidGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  An ellipsoid gate in two or more dimensions.

  The gate is defined by a vector of means _μ_ and a covariance matrix _C_,
  where an event, represented as _x_ in the space where _μ_ is defined, is in
  the gate if and only if _x_ is in
  
  ```
  G(μ, C, D^2) = { x : transpose(x - μ) * inverse(C) * (x - μ) <= D^2 }
  ```
  
  For a two-dimensional ellipse gate, half-axis lengths and rotation are
  computed to aid interpretation.
*/
public struct EllipsoidGate : Gate {
  public let dimensions: [String]

  /// The vector of means _μ_.
  public let means: [Float]

  /// The covariance matrix _C_, which must be symmetric and positive-definite.
  public let covariances: [Float]

  /// The square of the Mahalanobis distance (_D_^2).
  public let distanceSquared: Float

  internal let _lowerTriangle: [Float]?

  // ---------------------------------------------------------------------------
  // The following properties are computed only for two-dimensional gates
  // ---------------------------------------------------------------------------

  /**
    The length of the semi-major and semi-minor axes of a two-dimensional
    (ellipse) gate; `nil` if the gate has more than two dimensions.
  */
  public let halfAxes: (Float, Float)?

  /**
    The rotation, in radians, of a two-dimensional (ellipse) gate; `nil` if the
    gate has more than two dimensions.
  */
  public let rotation: Float?

  /**
    Create an ellipsoid gate with the given dimensions, vector of means,
    covariance matrix, and squared Mahalanobis distance.

    - Note: You can create an `EllipsoidGate` with a covariance matrix that is
      not symmetric and positive-definite, but every gating operation will give
      a result of `nil`.

    - Parameter dimensions: The dimensions to be gated. These names can be
      parameter short names (FCS terminology) or, equivalently, detector names
      (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
      terminology) after compensation using a non-acquisition-defined matrix.
    - Parameter means: The vector of means _μ_.
    - Parameter covariances: The covariance matrix _C_.
    - Parameter distanceSquared: The square of the Mahalanobis distance (_D_^2).
  */
  public init(
    dimensions: [String],
    means: [Float], covariances: [Float], distanceSquared: Float
  ) {
    precondition(dimensions.count == means.count &&
      means.count * means.count == covariances.count)

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
  }

  public func masking(_ population: Population) -> Population? {
    let dc = dimensions.count, ec = population.root.count
    guard var a = _lowerTriangle else { return nil }

    // Subtract means from events
    var c = [Float](repeating: 0, count: dc * ec)
    for (i, d) in dimensions.enumerated() {
      catlas_sset(Int32(ec), -means[i], &c + i, Int32(dc))
      guard let values = population.root.events[d] else { return nil }
      cblas_saxpy(Int32(ec), 1, values, 1, &c + i, Int32(dc))
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

    // Multiply `c` and `b` element-wise
    vDSP_vmul(c, 1, b, 1, &b, 1, UInt(dc * ec))
    // Sum elements of `b` row-wise; we'll reuse `c` for storage
    c.removeLast((dc - 1) * ec)
    catlas_sset(Int32(ec), 0, &c, 1)
    for i in 0..<dc {
      cblas_saxpy(Int32(ec), 1, &b + i, Int32(dc), &c, 1)
    }
    // Compare elements of `c` to `distanceSquared`
    vDSP_vlim(c, 1, [distanceSquared.nextUp], [-1 as Float], &c, 1, UInt(ec))
    vDSP_vthres(c, 1, [0 as Float], &c, 1, UInt(ec))
    return Population(population, mask: c)
  }
}
