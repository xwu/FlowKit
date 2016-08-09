//
//  Transform.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/// Parameters for parametrized scaling transforms.
public struct TransformParameters {

  /// Default parameters for parameterized scaling transforms.
  public static var `default` = TransformParameters(
    T: 262144, W: 0.5, M: 4.5, A: 0
  )

  // ---------------------------------------------------------------------------
  // These labels deliberately break with naming conventions because certain
  // lowercase letters are used in the specification to denote other parameters
  // ---------------------------------------------------------------------------

  /// The value at the top of scale (i.e., the value that is mapped to 1).
  public let T: Float

  /**
    For "log-like" transforms, the width basis, or number of decades in the
    quasi-linear region.
  */
  public let W: Float

  /// For non-linear transforms, the desired number of decades.
  public let M: Float

  /**
    For linear transforms, a constant such that `-A` is the value at the bottom
    of scale; for asinh and Logicle transforms, the number of additional
    negative decades to be "brought to scale."
  */
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

/**
  A parameterized scaling transform.

  When you scale a dimension of a `Sample` (i.e., a parameter (FCS terminology),
  fluorochrome, or detector (Gating-ML terminology)), unscaled values are
  replaced by their scaled counterparts. Likewise, when you unscale a dimension,
  scaled values are replaced by their unscaled counterparts.

  Conforming to the Transform Protocol
  ====================================

  To add `Transform` conformance to your custom type, you must declare at least
  the following requirements:

  * The `parameters` and `bounds` properties
  * The `init?(_:bounds:)` initializer
  * The `scaling(_: Float) -> Float` and `unscaling(_: Float) -> Float` methods

  Note that both `scaling(_:)` and `unscaling(_:)` do not return optional values
  and do not throw. Therefore, it is critical that you ensure at the time your
  transform is _created_ that the transform parameters supplied are valid for
  mapping any values in the interval given by `domain` to the range [0, 1].

  Note also that it is the responsibility of `scaling(_:)` and `unscaling(_:)`
  implementations to invoke `clipping(_:)` after scaling and before unscaling.

  To accelerate performance, you may also wish to provide your own
  implementation for the `scaling(_: [Float]) -> [Float]` and/or
  `unscaling(_: [Float]) -> [Float]` methods. Again, do not neglect to invoke
  `clipping(_:)` in these implementations.

  - SeeAlso: `TransformParameters`
*/
public protocol Transform {
  /// The parameters for the scaling transform function.
  var parameters: TransformParameters { get }

  /// Bounds for restricting the results of the scaling transform (optional).
  var bounds: (Float, Float)? { get }

  /// The domain of values mapped by the scaling transform to the range [0, 1].
  var domain: (Float, Float) { get }

  /**
    Create a transform with the given parameters that restricts (clips) results
    to the given bounds. If `bounds == nil`, then no clipping is applied.
  */
  init?(_ parameters: TransformParameters, bounds: (Float, Float)?)

  /**
    Create a transform with the given parameters that restricts (clips) results
    to the given bounds. If `bounds == nil`, then no clipping is applied.

    - Parameters:
      - T: The value at the top of scale (i.e., the value that is mapped to 1).
        `T` must be positive.
      - W: For "log-like" transforms, the width basis, or number of decades in
        the quasi-linear region. `W` must be non-negative.
      - M: For non-linear transforms, the desired number of decades. `M` must be
        positive.
      - A: For linear transforms, a constant such that `-A` is the value at the
        bottom of scale; for asinh and Logicle transforms, the number of
        additional negative decades to be "brought to scale." For most
        transforms, `A` must be non-negative.
  */
  init?(T: Float, W: Float, M: Float, A: Float, bounds: (Float, Float)?)

  /**
    Returns a scaled value by applying the receiver's scaling transform function
    to the given value.

    - Parameter value: The unscaled value.
    - Returns: A scaled value. If `bounds != nil`, this value is restricted
      (clipped) to the interval given by `bounds`.
  */
  func scaling(_ value: Float) -> Float

  /**
    Returns an unscaled value by applying the inverse of the receiver's scaling
    transform function to the given value.

   - Parameter value: The scale value.
   - Returns: An unscaled value. If `bounds != nil`, the scaled value is
     restricted (clipped) to the interval given by `bounds` prior to unscaling.
  */
  func unscaling(_ value: Float) -> Float

  /**
    Returns the value that is obtained after restricting (clipping) the given
    value to the receiver's `bounds`.

    - Parameter value: The unclipped value.
    - Returns: A clipped value. If `bounds == nil`, the "clipped" value is equal
      to the given unclipped value.
  */
  func clipping(_ value: Float) -> Float

  /**
    Returns an array of scaled values by applying the receiver's scaling
    transform function to the given array of values.

    - Parameter values: The unscaled values.
    - Returns: Scaled values. If `bounds != nil`, these values are restricted
      (clipped) to the interval given by `bounds`.
    - SeeAlso: `scaling(_ value: Float) -> Float`
  */
  func scaling(_ values: [Float]) -> [Float]

  /**
    Returns an array of unscaled value by applying the inverse of the receiver's
    scaling transform function to the given array of values.

   - Parameter values: The scale values.
   - Returns: Unscaled values. If `bounds != nil`, the scaled values are
     restricted (clipped) to the interval given by `bounds` prior to unscaling.
   - SeeAlso: `unscaling(_ value: Float) -> Float`
  */
  func unscaling(_ values: [Float]) -> [Float]

  /**
    Returns the array of values obtained after restricting (clipping) the given
    array of values to the receiver's `bounds`.

    - Parameter values: The unclipped values.
    - Returns: Clipped values. If `bounds == nil`, the "clipped" values are
      equal to the given unclipped values.
  */
  func clipping(_ values: [Float]) -> [Float]

  /**
    Scales the given dimensions of a sample by applying the receiver's scaling
    transform function. If `bounds != nil`, results are also restricted
    (clipped) to the receiver's `bounds`.
    
    Data in `sample.events` are replaced with their scaled counterparts.

    - Precondition: The given dimensions must be present in the sample.
    - Parameter sample: The given sample.
    - Parameter dimensions: The names of dimensions to be scaled; they can be
      parameter short names (FCS terminology) or, equivalently, detector names
      (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
      terminology) after compensation using a non-acquisition-defined matrix.
  */
  func scale(_ sample: Sample, dimensions: [String]?)

  /**
    Unscales the given dimensions of a sample by applying the inverse of the
    receiver's scaling transform function. If `bounds != nil`, the given
    dimensions are first restricted (clipped) to the receiver's `bounds` before
    unscaling.

    Data in `sample.events` are replaced with their unscaled counterparts.

    - Precondition: The given dimensions must be present in the sample.
    - Parameter sample: The given sample.
    - Parameter dimensions: The names of dimensions to be unscaled; they can be
    parameter short names (FCS terminology) or, equivalently, detector names
    (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
    terminology) after compensation using a non-acquisition-defined matrix.
  */
  func unscale(_ sample: Sample, dimensions: [String]?)

  /**
    If `bounds != nil`, restricts (clips) the given dimensions of a sample to
    the receiver's `bounds`.

    Data in `sample.events` are replaced with their clipped counterparts.

    - Precondition: The given dimensions must be present in the sample.
    - Parameter sample: The given sample.
    - Parameter dimensions: The names of dimensions to be clipped; they can be
    parameter short names (FCS terminology) or, equivalently, detector names
    (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
    terminology) after compensation using a non-acquisition-defined matrix.
  */
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
    executing: ([Float]) -> [Float]
  ) {
    let k = [String](sample.events.keys)
    let dimensions = dimensions?.filter { k.contains($0) } ?? k
    for d in dimensions {
      guard let values = sample.events[d] else { preconditionFailure() }
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
