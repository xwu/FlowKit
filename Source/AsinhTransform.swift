//
//  AsinhTransform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A parameterized inverse hyperbolic sine transform.

  The transform is defined by the function

  ```
  fasinh(x, T, M, A) = (asinh(x * sinh(M * ln(10)) / T) + A * ln(10)) / ((M + A) * ln(10))
  ```

  where _x_ is an unscaled real value, _T_ > 0, _M_ > 0, and 0 <= _A_ <= _M_.
  This transform is equivalent to a Logicle transform with parameters
  (_T_, 0, _M_, _A_).

  - SeeAlso: `TransformParameters`, `LogicleTransform`
*/
public struct AsinhTransform : Transform {
  public let parameters: TransformParameters
  public let bounds: (Float, Float)?
  // `_b` and `_x2` correspond to their counterparts in `LogicleTransform`
  // `_e` was chosen because it's not a parameter used in `LogicleTransform`
  internal let _b, _e, _x2: Float

  public init?(_ p: TransformParameters, bounds: (Float, Float)?) {
    guard p.T > 0 && p.M > 0 && p.A >= 0 && p.A <= p.M else { return nil }
    self.parameters = p
    self.bounds = bounds
    _b = (p.M + p.A) * log(10)
    _e = sinh(p.M * log(10)) / p.T
    _x2 = p.A / (p.M + p.A)
  }

  public func scaling(_ value: Float) -> Float {
    return clipping((asinh(value * _e) / _b) + _x2)
  }

  public func unscaling(_ value: Float) -> Float {
    return sinh((clipping(value) - _x2) * _b) / _e
  }

  public func scaling(_ values: [Float]) -> [Float] {
    var v0 = [Float](repeating: 0, count: values.count)
    var v1 = [Float](repeating: 0, count: values.count)
    let c = Int32(values.count), e = _e, ib = 1 / _b, x2 = _x2
    values.withUnsafeBufferPointer {
      vDSP_vsmul($0.baseAddress!, 1, [e], &v0, 1, UInt(values.count))
    }
    vvasinhf(&v1, v0, [c]) // This cannot be done in-place
    vDSP_vsmsa(v1, 1, [ib], [x2], &v1, 1, UInt(values.count))
    return clipping(v1)
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    var values = clipping(values)
    var result = [Float](repeating: 0, count: values.count)
    let nx2 = -_x2, b = _b, e = _e, c = Int32(values.count)
    vDSP_vsadd(values, 1, [nx2], &values, 1, UInt(values.count))
    vDSP_vsmul(values, 1, [b], &values, 1, UInt(values.count))
    vvsinhf(&result, values, [c]) // This cannot be done in-place
    vDSP_vsdiv(result, 1, [e], &result, 1, UInt(values.count))
    return result
  }
}

extension AsinhTransform : Equatable {
  public static func == (lhs: AsinhTransform, rhs: AsinhTransform) -> Bool {
    let unbounded = (-Float.infinity, Float.infinity)
    return (
      (lhs.bounds ?? unbounded) == (rhs.bounds ?? unbounded) &&
      lhs.parameters.T == rhs.parameters.T &&
      lhs.parameters.M == rhs.parameters.M &&
      lhs.parameters.A == rhs.parameters.A
    )
  }
}
