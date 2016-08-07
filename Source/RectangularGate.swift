//
//  RectangularGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A rectangular gate in _n_ dimensions.

  When _n_ = 1, the gate is a range gate.
  When _n_ = 2, the gate is a rectangle gate.
  When _n_ = 3, the gate is a box region.
  When _n_ > 3, the gate is a hyper-rectangular region.

  An event is in the gate if, for each dimension among the gate's dimensions,
  the value of the event in that dimension is greater than or equal to the
  gate's lower bound for that dimension and less than the gate's upper bound for
  that dimension.
*/
public struct RectangularGate : Gate {
  public let dimensions: [String]
  /// The lower bound and upper bound for each dimension.
  public let ranges: [Range<Float>]

  /**
    Create a rectangular gate with the given dimensions and ranges.

    - Parameter dimensions: The dimensions to be gated. These names can be
      parameter short names (FCS terminology) or, equivalently, detector names
      (Gating-ML terminology), and they can be fluorochrome names (Gating-ML
      terminology) after compensation using a non-acquisition-defined matrix.
    - Parameter ranges: The lower bound and upper bound for each dimension.
  */
  public init(dimensions: [String], ranges: [Range<Float>]) {
    precondition(dimensions.count == ranges.count)
    self.dimensions = dimensions
    self.ranges = ranges
  }

  internal func _masking(_ values: [Float], _ range: Range<Float>) -> [Float] {
    var v0 = [Float](repeating: 0, count: values.count)
    var v1 = [Float](repeating: 0, count: values.count)
    let (l, u) = (range.lowerBound, range.upperBound)
    vDSP_vlim(values, 1, [l], [1 as Float], &v0, 1, UInt(values.count))
    vDSP_vlim(values, 1, [u], [-1 as Float], &v1, 1, UInt(values.count))
    vDSP_vasm(v0, 1, v1, 1, [0.5 as Float], &v0, 1, UInt(values.count))
    vDSP_vthres(v0, 1, [0 as Float], &v0, 1, UInt(values.count))
    return v0
  }

  public func masking(_ population: Population) -> Population? {
    guard
      let d0 = dimensions.first, let v0 = population.root.events[d0]
      else { return nil }
    var result = _masking(v0, ranges[0])
    for (i, d) in dimensions.enumerated().dropFirst() {
      guard let v = population.root.events[d] else { return nil }
      let m = _masking(v, ranges[i])
      // Compute `result & m`
      vDSP_vmul(result, 1, m, 1, &result, 1, UInt(result.count))
    }
    return Population(population, mask: result)
  }
}
