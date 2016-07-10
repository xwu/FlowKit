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

  internal func _masking(_ values: [Float], _ bounds: Range<Float>) -> [Float] {
    var v0 = [Float](repeating: 0, count: values.count)
    var v1 = [Float](repeating: 0, count: values.count)
    vDSP_vlim(
      values, 1, [bounds.lowerBound],
      [1 as Float], &v0, 1, UInt(values.count)
    )
    vDSP_vlim(
      values, 1, [bounds.upperBound],
      [-1 as Float], &v1, 1, UInt(values.count)
    )
    vDSP_vasm(v0, 1, v1, 1, [0.5 as Float], &v0, 1, UInt(values.count))
    /*
    vDSP_vthres(v0, 1, [0 as Float], &v0, 1, UInt(values.count))
    */
    return v0
  }

  public func masking(_ population: Population) -> Population? {
    guard
      let d0 = dimensions.first, v0 = population.root.events[d0]
      else { return nil }
    var m0 = _masking(v0, ranges[0])

    for (i, d) in dimensions.enumerated().dropFirst() {
      guard let v = population.root.events[d] else { return nil }
      let m = _masking(v, ranges[i])
      cblas_saxpy(Int32(m0.count), 1, m, 1, &m0, 1)
    }

    var result = [UInt8](repeating: 0, count: m0.count)
    let threshold = Float(dimensions.count)
    vDSP_vlim(m0, 1, [threshold], [1 as Float], &m0, 1, UInt(m0.count))
    vDSP_vthres(m0, 1, [0 as Float], &m0, 1, UInt(m0.count))
    vDSP_vfixu8(m0, 1, &result, 1, UInt(m0.count))
    return Population(population, mask: BitVector(result))
  }
}
