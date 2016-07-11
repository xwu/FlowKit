//
//  Histogram.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/10/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct Histogram {
  public static var defaultResolution = 256
  public let dimensions: [String]
  public let ranges: [Range<Float>]
  public let resolution: Int
  public let values: [Float]

  public init?(
    _ population: Population,
    dimensions: [String], ranges: [Range<Float>],
    resolution: Int = Histogram.defaultResolution
  ) {
    precondition(1...2 ~= dimensions.count && dimensions.count == ranges.count)
    self.dimensions = dimensions
    self.ranges = ranges
    self.resolution = resolution

    func _binning(_ i: Int) -> [Float]? {
      let (l, u) = (ranges[i].lowerBound, ranges[i].upperBound)
      guard var v0 = population.root.events[dimensions[i]] else { return nil }
      var v1 = [Float](repeating: -l, count: v0.count)
      // Compute bin for each value: scale to 0..<resolution, then take floor
      if l != 0 {
        cblas_saxpy(Int32(v0.count), 1, v1, 1, &v0, 1)
      }
      cblas_sscal(Int32(v0.count), Float(resolution) / (u - l), &v0, 1)
      vvfloorf(&v1, v0, [Int32(v0.count)]) // This cannot be done in-place
      // Use one bin at either end to hold outlier values
      let ones = [Float](repeating: 1, count: v0.count)
      cblas_saxpy(Int32(v0.count), 1, ones, 1, &v1, 1)
      let b = 0 as Float, c = Float(resolution + 1)
      vDSP_vclip(v1, 1, [b], [c], &v1, 1, UInt(v0.count))
      // Mask if necessary
      if let mask = population.mask {
        vDSP_vcmprs(v1, 1, mask, 1, &v1, 1, UInt(v0.count))
        v1.removeLast(mask.count - population.count)
      }
      return v1
    }

    guard var xs = _binning(0) else { return nil }
    var values: [Float]
    switch dimensions.count {
    case 1:
      vDSP_vsort(&xs, UInt(xs.count), 1)
      values = [Float](repeating: 0, count: resolution + 2)
    case 2:
      guard let ys = _binning(1) else { return nil }
      cblas_saxpy(Int32(ys.count), Float(resolution), ys, 1, &xs, 1)
      vDSP_vsort(&xs, UInt(xs.count), 1)
      values = [Float](repeating: 0, count: (resolution + 2) * (resolution + 2))
    default:
      return nil
    }
    //TODO: Verify correctness of this algorithm
    var pi = 0, px = 0 as Float
    for (i, x) in xs.enumerated() {
      if x > px {
        values[Int(px)] = Float(i - pi)
        pi = i
        px = x
      }
    }
    values[Int(px)] = Float(xs.count - pi)

    // Remove outlier bins
    switch dimensions.count {
    case 1:
      values.removeFirst()
      values.removeLast()
    case 2:
      // Make ad-hoc mask
      let a = [Float](repeating: 0, count: resolution + 2)
      var b = [Float](repeating: 1, count: resolution + 2)
      b[0] = 0
      b[resolution + 1] = 0
      var c = a
      c.reserveCapacity((resolution + 2) * (resolution + 2))
      for _ in 0..<resolution {
        c.append(contentsOf: b)
      }
      c.append(contentsOf: a)
      // Use ad-hoc mask to compress results
      vDSP_vcmprs(values, 1, c, 1, &values, 1, UInt(values.count))
      values.removeLast(4 * (resolution + 1))
    default:
      return nil
    }
    self.values = values
  }

  public init?(
    _ population: Population,
    dimensions: [String],
    resolution: Int = Histogram.defaultResolution
  ) {
    let ranges = [Range<Float>](repeating: 0..<1, count: dimensions.count)
    self.init(
      population, dimensions: dimensions,
      ranges: ranges, resolution: resolution
    )
  }
}
