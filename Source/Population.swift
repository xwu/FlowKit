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
  public typealias _Events =
    LazyMapSequence<LazyFilterSequence<EnumeratedSequence<[Float]>>, Float>
  public var events: [String : _Events]? {
    guard let mask = mask else { return nil }
    var e = [String : _Events]()
    root.events.forEach { k, v in
      e[k] = v.enumerated().lazy.filter { i, _ in mask[i] == .one }.map { $1 }
    }
    return e
  }
  */

  public init(_ root: Sample, mask: BitVector? = nil) {
    if let mask = mask {
      precondition(root.count == mask.count)
    }
    self.root = root
    self.mask = mask
    count = mask?.cardinality() ?? root.count
  }

  public init(_ parent: Population, mask: BitVector? = nil) {
    if let mask = mask {
      precondition(parent.root.count == mask.count)
    }
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
