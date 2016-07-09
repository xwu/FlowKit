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
    let f: @noescape (Int, String?) -> BitVector? = { i, d in
      guard let d = d, values = population.root.events[d] else { return nil }
      let (l, u) = (self.ranges[i].lowerBound, self.ranges[i].upperBound)
      return BitVector(values.lazy.map { $0 >= l && $0 < u ? 1 as UInt8 : 0 })
    }

    guard var mask = f(0, dimensions.first) else { return nil }
    for (i, d) in dimensions.enumerated().dropFirst() {
      guard let m = f(i, d) else { return nil }
      mask &= m
    }
    return Population(population, mask: mask)
  }
}
