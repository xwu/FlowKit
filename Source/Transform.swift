//
//  Transform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct TransformParameters {
  public static var `default` = TransformParameters(
    T: 262144, W: 0.5, M: 4.5, A: 0
  )

  // These labels deliberately break with naming conventions because certain
  // lowercase letters are used in the specification to denote other parameters
  public let T: Float
  public let W: Float
  public let M: Float
  public let A: Float

  public init(_ T: Float, _ W: Float, _ M: Float, _ A: Float) {
    self.T = T
    self.W = W
    self.M = M
    self.A = A
  }

  public init(T: Float, W: Float, M: Float, A: Float) {
    self.init(T, W, M, A)
  }
}

public protocol Transform {
  var parameters: TransformParameters { get }
  var bounds: (Float, Float)? { get }
  var domain: (Float, Float) { get }

  init?(_ parameters: TransformParameters, bounds: (Float, Float)?)
  init?(T: Float, W: Float, M: Float, A: Float, bounds: (Float, Float)?)

  func scaling(_ value: Float) -> Float
  func unscaling(_ value: Float) -> Float
  func clipping(_ value: Float) -> Float

  func scaling(_ values: [Float]) -> [Float]
  func unscaling(_ values: [Float]) -> [Float]
  func clipping(_ values: [Float]) -> [Float]

  func scale(_ sample: Sample, dimensions: [String]?)
  func unscale(_ sample: Sample, dimensions: [String]?)
  func clip(_ sample: Sample, dimensions: [String]?)
}

extension Transform {
  public var domain: (Float, Float) {
    return (unscaling(0), unscaling(1))
  }

  public init?(
    T: Float = TransformParameters.default.T,
    W: Float = TransformParameters.default.W,
    M: Float = TransformParameters.default.M,
    A: Float = TransformParameters.default.A,
    bounds: (Float, Float)? = nil
  ) {
    let parameters = TransformParameters(T, W, M, A)
    self.init(parameters, bounds: bounds)
  }

  public func clipping(_ value: Float) -> Float {
    guard let (a, b) = bounds else { return value }
    let (min, max) = b < a ? (b, a) : (a, b)
    return (value < min) ? min : ((value > max) ? max : value)
  }

  public func scaling(_ values: [Float]) -> [Float] {
    var result = [Float]()
    result.reserveCapacity(values.count)
    for i in 0..<values.count {
      result[i] = scaling(values[i])
    }
    return result
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    var result = [Float]()
    result.reserveCapacity(values.count)
    for i in 0..<values.count {
      result[i] = unscaling(values[i])
    }
    return result
  }

  public func clipping(_ values: [Float]) -> [Float] {
    guard let (a, b) = bounds else { return values }
    var (min, max) = b < a ? (b, a) : (a, b)
    var result = [Float](repeating: 0, count: values.count)
    //FIXME: `vDSP_vclip()` handles NaN incorrectly, unlike `vDSP_vclipD()`
    values.withUnsafeBufferPointer {
      vDSP_vclip($0.baseAddress!, 1, &min, &max, &result, 1, UInt(values.count))
    }
    return result
  }

  internal func _mutate(
    _ sample: Sample, dimensions: [String]? = nil,
    executing: @noescape ([Float]) -> [Float]
  ) {
    let k = [String](sample.events.keys)
    let dimensions = dimensions?.filter { k.contains($0) } ?? k
    for d in dimensions {
      guard let values = sample.events[d] else { fatalError() }
      sample.events[d] = executing(values)
    }
  }

  public func scale(_ sample: Sample, dimensions: [String]? = nil) {
    _mutate(
      sample, dimensions: dimensions,
      executing: scaling as ([Float]) -> [Float]
    )
  }

  public func unscale(_ sample: Sample, dimensions: [String]? = nil) {
    _mutate(
      sample, dimensions: dimensions,
      executing: unscaling as ([Float]) -> [Float]
    )
  }

  public func clip(_ sample: Sample, dimensions: [String]? = nil) {
    _mutate(
      sample, dimensions: dimensions,
      executing: clipping as ([Float]) -> [Float]
    )
  }
}
