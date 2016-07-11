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
  public let data: [Float]

  public init?(
    _ population: Population, dimensions: [String],
    ranges: [Range<Float>], resolution: Int = Histogram.defaultResolution
  ) {
    precondition(1...2 ~= dimensions.count && dimensions.count == ranges.count)
    self.dimensions = dimensions
    self.ranges = ranges
    self.resolution = resolution

    func _binned(_ values: [Float], _ range: Range<Float>) -> [Float] {
      var v0 = values
      let (l, u) = (range.lowerBound, range.upperBound)
      var v1 = [Float](repeating: -l, count: v0.count)
      if l != 0 {
        cblas_saxpy(Int32(v0.count), 1, v1, 1, &v0, 1)
      }
      cblas_sscal(Int32(v0.count), Float(resolution) / (u - l), &v0, 1)
      vvfloorf(&v1, v0, [Int32(v0.count)]) // This cannot be done in-place

      // Make room for one bin at either end for events outside the stated range
      let ones = [Float](repeating: 1, count: v0.count)
      cblas_saxpy(Int32(v0.count), 1, ones, 1, &v1, 1)
      let b = 0 as Float, c = Float(resolution + 1)
      vDSP_vclip(v1, 1, [b], [c], &v0, 1, UInt(v0.count))
      return v0
    }

    guard let v0 = population.root.events[dimensions[0]] else { return nil }
    var xs = _binned(v0, ranges[0])
    // Use `unpacked` to compress events if the population has a mask
    if let mask = population.mask {
      vDSP_vcmprs(xs, 1, mask, 1, &xs, 1, UInt(mask.count))
      xs.removeLast(mask.count - population.count)
    }

    var data: [Float]
    switch dimensions.count {
    case 1:
      vDSP_vsort(&xs, UInt(xs.count), 1)
      //TODO: Verify correctness of this algorithm
      data = [Float](repeating: 0, count: resolution + 2)
      var pi = 0, px = 0 as Float
      for (i, x) in xs.enumerated() {
        if x > px {
          data[Int(px)] = Float(i - pi)
          pi = i
          px = x
        }
      }
      data[Int(px)] = Float(xs.count - pi)
      // Drop outlier bins
      data.removeFirst()
      data.removeLast()
    case 2:
      guard let v1 = population.root.events[dimensions[1]] else { return nil }
      var ys = _binned(v1, ranges[1])
      // Use `unpacked` to compress events if the population has a mask
      if let mask = population.mask {
        vDSP_vcmprs(ys, 1, mask, 1, &ys, 1, UInt(mask.count))
        ys.removeLast(mask.count - population.count)
      }
      //TODO: Verify that the order of axes implied below is conducive for use
      //      with bitmap graphics
      cblas_saxpy(Int32(xs.count), Float(resolution), xs, 1, &ys, 1)
      vDSP_vsort(&ys, UInt(ys.count), 1)
      //TODO: Verify correctness of this algorithm
      data = [Float](repeating: 0, count: (resolution + 2) * (resolution + 2))
      var pi = 0, py = 0 as Float
      for (i, y) in ys.enumerated() {
        if y > py {
          data[Int(py)] = Float(i - pi)
          pi = i
          py = y
        }
      }
      data[Int(py)] = Float(ys.count - pi)
      // Drop outlier bins
      let a = [Float](repeating: 0, count: resolution + 2)
      var b = [Float](repeating: 1, count: resolution + 2)
      b[0] = 0; b[resolution + 1] = 0
      var c = a
      c.reserveCapacity((resolution + 2) * (resolution + 2))
      for _ in 0..<resolution {
        c.append(contentsOf: b)
      }
      c.append(contentsOf: a)
      vDSP_vcmprs(data, 1, c, 1, &data, 1, UInt(data.count))
      data.removeLast(4 * (resolution + 1))
    default:
      return nil
    }
    self.data = data
  }

  public init?(
    _ population: Population, dimensions: [String],
    resolution: Int = Histogram.defaultResolution
  ) {
    let ranges = [Range<Float>](repeating: 0..<1, count: dimensions.count)
    self.init(
      population, dimensions: dimensions,
      ranges: ranges, resolution: resolution
    )
  }
}
