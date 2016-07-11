//
//  Population.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public final class Population {
  public let root: Sample
  public let mask: [Float]?
  public let count: Int

  public init(_ root: Sample, mask: [Float]? = nil) {
    if let mask = mask {
      precondition(root.count == mask.count)
    }
    self.root = root
    self.mask = mask
    if let mask = mask {
      count = Int(cblas_sasum(Int32(mask.count), mask, 1))
    } else {
      count = root.count
    }
  }

  public init(_ parent: Population, mask: [Float]? = nil) {
    if let mask = mask {
      precondition(parent.root.count == mask.count)
    }
    self.root = parent.root
    if var mask = mask {
      if let pm = parent.mask {
        // Compute `mask & pm`
        vDSP_vmul(mask, 1, pm, 1, &mask, 1, UInt(mask.count))
      }
      self.mask = mask
      count = Int(cblas_sasum(Int32(mask.count), mask, 1))
    } else {
      self.mask = parent.mask ?? nil
      count = parent.count
    }
  }
}
