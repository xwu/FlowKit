//
//  RectangularGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct RectangularGate : Gate {
  public let dimensions: [String]
  public let ranges: [Range<Float>]

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
      let d0 = dimensions.first, v0 = population.root.events[d0]
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
