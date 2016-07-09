//
//  BooleanGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

public struct BooleanGate: Gate {
  public enum Operation {
    case not, and, or, xor
    // Xor is not supported in Gating-ML, but we'll support it
  }

  public var dimensions: [String] {
    var s = Set<String>()
    for g in gates { s.formUnion(g.dimensions) }
    return [String](s)
  }
  public let operation: Operation
  public let gates: [Gate]

  public init(operation: Operation, gates: [Gate]) {
    precondition(operation == .not ? gates.count == 1 : gates.count > 1)
    self.operation = operation
    self.gates = gates
  }

  public func masking(_ population: Population) -> Population? {
    guard var mask = gates.first?.masking(population)?.mask else { return nil }
    switch operation {
    case .not:
      // Each not gate can only reference one other gate
      // Note that we must mask the parent population and not the root sample
      return Population(population, mask: ~mask)
    case .and:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        mask &= m
      }
      return Population(population.root, mask: mask)
    case .or:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        mask |= m
      }
      return Population(population.root, mask: mask)
    case .xor:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        mask ^= m
      }
      return Population(population.root, mask: mask)
    }
  }
}
