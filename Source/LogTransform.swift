//
//  LogTransform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct LogTransform : Transform {
  public let parameters: TransformParameters
  public let bounds: (Float, Float)?

  public init?(_ p: TransformParameters, bounds: (Float, Float)?) {
    guard p.T > 0 && p.M > 0 else { return nil }

    // We make new `TransformParameters` to reset any irrelevant parameters to
    // their default value
    self.parameters = TransformParameters(T: p.T, M: p.M)
    if let (a, b) = bounds where a > b {
      self.bounds = (b, a)
    } else {
      self.bounds = bounds
    }
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
    var t = parameters.T, c = Int32(values.count)
    var im = 1 / parameters.M, one = 1 as Float
    values.withUnsafeBufferPointer {
      vDSP_vsdiv($0.baseAddress!, 1, &t, &v0, 1, UInt(values.count))
    }
    vvlog10f(&v1, &v0, &c) // This cannot be done in-place
    vDSP_vsmsa(&v1, 1, &im, &one, &v1, 1, UInt(values.count))
    return clipping(v1)
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    var values = clipping(values)
    var negativeOne = -1 as Float, m = parameters.M
    var c = Int32(values.count), t = parameters.T
    var radix = [Float](repeating: 10, count: values.count)
    var result = [Float](repeating: 0, count: values.count)
    vDSP_vsadd(&values, 1, &negativeOne, &values, 1, UInt(values.count))
    vDSP_vsmul(&values, 1, &m, &values, 1, UInt(values.count))
    vvpowf(&result, &values, &radix, &c) // This cannot be done in-place
    vDSP_vsmul(&result, 1, &t, &result, 1, UInt(values.count))
    return result
  }
}
