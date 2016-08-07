//
//  BooleanGate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

/**
  A Boolean gate.

  NOT gates subset a population based on a single other gate. AND, OR, and XOR
  (exclusive or) gates subset a population based on two or more other gates.
*/
public struct BooleanGate : Gate {
  /// A Boolean gate operation.
  public enum Operation {
    case not, and, or, xor
    // XOR is not supported in Gating-ML, but we'll support it
  }

  public var dimensions: [String] {
    var s = Set<String>()
    for g in gates { s.formUnion(g.dimensions) }
    return [String](s)
  }

  /// The operation for the Boolean gate.
  public let operation: Operation

  /// The other gate(s) on which the Boolean gate is based.
  public let gates: [Gate]

  /**
    Create a Boolean gate that uses the given operation, based on the given
    gates.

    - Parameter operation: The Boolean gate operation to be used.
    - Parameter gates: The other gate(s) on which to base the Boolean gate.
  */
  public init(operation: Operation, gates: [Gate]) {
    precondition(operation == .not ? gates.count == 1 : gates.count > 1)
    self.operation = operation
    self.gates = gates
  }

  public func masking(_ population: Population) -> Population? {
    guard var mask = gates.first?.masking(population)?.mask else { return nil }
    switch operation {
    case .not:
      // Each NOT gate can only reference one other gate
      // Note that we must mask the parent population and not the root sample
      vDSP_vsmsa(
        mask, 1, [-1 as Float], [1 as Float], &mask, 1, UInt(mask.count)
      )
      return Population(population, mask: mask)
    case .and:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        vDSP_vmul(mask, 1, m, 1, &mask, 1, UInt(mask.count))
      }
      return Population(population.root, mask: mask)
    case .or:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        vDSP_vadd(mask, 1, m, 1, &mask, 1, UInt(mask.count))
        vDSP_vclip(
          mask, 1, [0 as Float], [1 as Float], &mask, 1, UInt(mask.count)
        )
      }
      return Population(population.root, mask: mask)
    case .xor:
      for gate in gates.dropFirst() {
        guard let m = gate.masking(population)?.mask else { return nil }
        vDSP_vsub(m, 1, mask, 1, &mask, 1, UInt(mask.count))
        vDSP_vabs(mask, 1, &mask, 1, UInt(mask.count))
      }
      return Population(population.root, mask: mask)
    }
  }
}
