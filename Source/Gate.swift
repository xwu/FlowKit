//
//  Gate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

/**
  A gate for subsetting flow cytometry data.

  If you use a gate to subset (mask) a population that does not contain the
  gate's dimensions, the result of that gating operation is `nil`.

  Conforming to the Gate Protocol
  ===============================

  To add `Gate` conformance to your type, you must declare the following
  requirements: 

  * The `dimensions` property
  * The `masking(_: Population) -> Population?` method

  - SeeAlso: `Population`
*/
public protocol Gate {
  /**
    The names of dimensions to be gated.

    These names can be parameter short names (FCS terminology) or, equivalently,
    detector names (Gating-ML terminology), and they can be fluorochrome names
    (Gating-ML terminology) after compensation using a non-acquisition-defined
    matrix.
  */
  var dimensions: [String] { get }

  /**
    Returns a subset population obtained by gating the given population using
    the receiver.
    
    - Parameter population: The population to be gated.
    - Returns: The subset population after gating. If the gate's dimensions are
      not found in the given population, the result is `nil`.
  */
  func masking(_ population: Population) -> Population?

  /**
    Returns a subset population obtained by gating the given sample using the
    receiver.

    - Parameter sample: The sample to be gated.
    - Returns: The subset population after gating. If the gate's dimensions are
      not found in the given sample, the result is `nil`.
  */
  func masking(_ sample: Sample) -> Population?
}

extension Gate {
  public func masking(_ sample: Sample) -> Population? {
    return masking(Population(sample))
  }
}
