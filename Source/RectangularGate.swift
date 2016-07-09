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
  internal let _lowerBounds: [Float]
  internal let _upperBounds: [Float]

  public init(dimensions: [String], ranges: [Range<Float>]) {
    precondition(dimensions.count == ranges.count)
    self.dimensions = dimensions
    self.ranges = ranges
    _lowerBounds = ranges.map { $0.lowerBound }
    _upperBounds = ranges.map { $0.upperBound }
  }

  public func masking(_ population: Population) -> Population? {
    var mask = BitVector(repeating: .one, count: population.root.count)
    for (i, d) in dimensions.enumerated() {
      guard let values = population.root.events[d] else { return nil }
      let l = _lowerBounds[i]
      let u = _upperBounds[i]
      mask &= BitVector(values.lazy.map { $0 >= l && $0 < u ? 1 as UInt8 : 0 })
    }
    return Population(population, mask: mask)
  }
}
