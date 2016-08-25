//
//  LogTransform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A parameterized logarithmic transform.

  The transform is defined by the function

  ```
  flin(x, T, M) = (1 / M) * log10(x / T) + 1
  ```

  where _x_ is an unscaled real value, _T_ > 0 and _M_ > 0.

  - SeeAlso: `TransformParameters`
*/
public struct LogTransform : Transform {
  public let parameters: TransformParameters
  public let bounds: (Float, Float)?

  public init?(_ p: TransformParameters, bounds: (Float, Float)?) {
    guard p.T > 0 && p.M > 0 else { return nil }
    self.parameters = p
    self.bounds = bounds
  }

  public func scaling(_ value: Float) -> Float {
    return clipping(log10(value / parameters.T) / parameters.M + 1)
  }

  public func unscaling(_ value: Float) -> Float {
    return __exp10f((clipping(value) - 1) * parameters.M) * parameters.T
  }

  public func scaling(_ values: [Float]) -> [Float] {
    var v0 = [Float](repeating: 0, count: values.count)
    var v1 = [Float](repeating: 0, count: values.count)
    let c = Int32(values.count), im = 1 / parameters.M, t = parameters.T
    values.withUnsafeBufferPointer {
      vDSP_vsdiv($0.baseAddress!, 1, [t], &v0, 1, UInt(values.count))
    }
    vvlog10f(&v1, v0, [c]) // This cannot be done in-place
    vDSP_vsmsa(v1, 1, [im], [1 as Float], &v1, 1, UInt(values.count))
    return clipping(v1)
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    var values = clipping(values)
    var result = [Float](repeating: 0, count: values.count)
    let radix = [Float](repeating: 10, count: values.count)
    let c = Int32(values.count), m = parameters.M, t = parameters.T
    vDSP_vsadd(values, 1, [-1 as Float], &values, 1, UInt(values.count))
    vDSP_vsmul(values, 1, [m], &values, 1, UInt(values.count))
    vvpowf(&result, values, radix, [c]) // This cannot be done in-place
    vDSP_vsmul(result, 1, [t], &result, 1, UInt(values.count))
    return result
  }
}

extension LogTransform : Equatable {
  public static func == (lhs: LogTransform, rhs: LogTransform) -> Bool {
    let unbounded = (-Float.infinity, Float.infinity)
    return (
      (lhs.bounds ?? unbounded) == (rhs.bounds ?? unbounded) &&
      lhs.parameters.T == rhs.parameters.T &&
      lhs.parameters.M == rhs.parameters.M
    )
  }
}
