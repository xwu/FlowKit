//
//  RectangularGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

public struct RectangularGate : Gate {
  public let dimensions: [String]
  public let ranges: [Range<Float>]

  public init(dimensions: [String], ranges: [Range<Float>]) {
    precondition(dimensions.count == ranges.count)
    self.dimensions = dimensions
    self.ranges = ranges
  }

  public func masking(_ population: Population) -> Population? {
    guard
      let d0 = dimensions.first, values = population.root.events[d0],
      l = ranges.first?.lowerBound, u = ranges.first?.upperBound
      else { return nil }
    var mask = BitVector(values.lazy.map { $0 >= l && $0 < u ? 1 as UInt8 : 0 })
    for (i, d) in dimensions.enumerated().dropFirst() {
      guard let values = population.root.events[d] else { return nil }
      let l = ranges[i].lowerBound, u = ranges[i].upperBound
      mask &= BitVector(values.lazy.map { $0 >= l && $0 < u ? 1 as UInt8 : 0 })
    }
    return Population(population, mask: mask)
  }
}
