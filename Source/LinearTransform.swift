//
//  LinearTransform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct LinearTransform : Transform {
  public let parameters: TransformParameters
  public let bounds: (Float, Float)?
  internal let _sum: Float

  public init?(
    parameters p: TransformParameters = TransformParameters(),
    bounds: (Float, Float)? = nil
  ) {
    guard p.T > 0 && p.A >= 0 && p.A <= p.T else { return nil }

    // We make new `TransformParameters` to reset any irrelevant parameters to
    // their default value
    self.parameters = TransformParameters(T: p.T, A: p.A)
    if let (a, b) = bounds where a > b {
      self.bounds = (b, a)
    } else {
      self.bounds = bounds
    }
    self._sum = p.T + p.A
  }

  public func scaling(_ value: Float) -> Float {
    return clipping((value + parameters.A) / _sum)
  }

  public func unscaling(_ value: Float) -> Float {
    return clipping(value) * _sum - parameters.A
  }

  public func scaling(_ values: [Float]) -> [Float] {
    var result = [Float](repeating: parameters.A, count: values.count)
    values.withUnsafeBufferPointer {
      cblas_saxpy(Int32(result.count), 1, $0.baseAddress, 1, &result, 1)
    }
    cblas_sscal(Int32(result.count), 1 / _sum, &result, 1)
    return clipping(result)
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    let values = clipping(values)
    var result = [Float](repeating: -parameters.A, count: values.count)
    cblas_saxpy(Int32(result.count), _sum, values, 1, &result, 1)
    return result
  }
}
