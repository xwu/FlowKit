//
//  Population.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

public final class Population {
  public let root: Sample
  public let mask: BitVector?
  public let count: Int
  /*
  public var events: [String : [Float]] {
    return [String : [Float]]()
  }
  */

  public init(_ root: Sample, mask: BitVector? = nil) {
    self.root = root
    self.mask = mask
    count = mask?.cardinality() ?? root.count
  }

  public init(_ parent: Population, mask: BitVector? = nil) {
    self.root = parent.root
    let m: BitVector?
    switch (parent.mask, mask) {
    case let (x?, y?):
      m = x & y
    case let (x?, nil):
      m = x
    case let (nil, y?):
      m = y
    case (nil, nil):
      m = nil
    }
    self.mask = m
    count = m?.cardinality() ?? parent.root.count
  }
}
