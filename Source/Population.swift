//
//  Population.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A subset population of a `Sample`.
*/
public final class Population {
  /// The sample of which the population is a subset.
  public let root: Sample

  /**
    The mask that determines which of the sample's events are included (1) or
    excluded (0) from the subset population.

    If `mask == nil`, then all events are included in the population.
  */
  public let mask: [Float]?

  /// The number of events included in the population.
  public let count: Int

  /**
    Initialize a new `Population` with the given sample and mask.

    - Precondition: If `mask != nil`, then `root.count` must equal `mask.count`.
    - Parameter root: The sample of which the population is to be a subset.
    - Parameter mask: The mask that determines which of the sample's events are
      to be included (1) or excluded (0) from the population subset.
  */
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

  /**
    Initialize a new `Population` with the given parent population and mask.

   - Precondition: If `mask != nil`, then `parent.root.count` (the number of 
     events in the root sample) must equal `mask.count`.
   - Parameter parent: The parent population of which the population is to be a
     subset.
   - Parameter mask: The mask that is to be multiplied with the parent
     population mask to determine which of the sample's events are to be
     included (1) or excluded (0) from the population subset.
  */
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
