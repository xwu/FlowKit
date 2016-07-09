//
//  Gate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

public protocol Gate {
  var dimensions: [String] { get }
  func masking(_ population: Population) -> Population?
  func masking(_ sample: Sample) -> Population?
}

public extension Gate {
  func masking(_ sample: Sample) -> Population? {
    return masking(Population(sample))
  }
}
