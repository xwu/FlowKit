//
//  Compensation.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/18/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

public struct Compensation {
  public let detectors: [String]
  public let fluorochromes: [String]?
  public let matrix: [Float] /* row-major */
  public let isInverted: Bool

  public init(detectors: [String], matrix: [Float], isInverted: Bool = false) {
    self.detectors = detectors
    self.fluorochromes = fluorochromes
    self.matrix = matrix
    self.isInverted = isInverted
  }

  public init(
    detectors: [String], fluorochromes: [String],
    matrix: [Float], isInverted: Bool = false
  ) {
    self.detectors = detectors
    self.fluorochromes = fluorochromes
    self.matrix = matrix
    self.isInverted = isInverted
  }
}
