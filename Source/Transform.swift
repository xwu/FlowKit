//
//  Transform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

// These labels deliberately break with naming conventions because certain
// lowercase letters are used in the specification to denote other parameters
public typealias _Parameters = (T: Float, W: Float, M: Float, A: Float)

public protocol Transform {
  var parameters: _Parameters { get }
  var bounds: (Float, Float)? { get }
  var domain: (Float, Float) { get }

  init?(parameters: _Parameters, bounds: (Float, Float)?)
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

public extension Transform {
  public var domain: (Float, Float) {
    return (unscaling(0), unscaling(1))
  }

  public init?(
    T: Float = 262144, W: Float = 0.5, M: Float = 4.5, A: Float = 0,
    bounds: (Float, Float)? = nil
  ) {
    self.init(parameters: (T, W, M, A), bounds: bounds)
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
