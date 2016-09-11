//
//  Descriptor.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 8/28/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

/* open */ internal class Descriptor : CustomDebugStringConvertible {
  public var uuid: UUID
  public var name: String?

  public init(uuid: UUID? = nil, name: String? = nil, value: Any? = nil) {
    self.uuid = uuid ?? UUID()
    self.name = name
  }

  open var debugDescription : String {
    let empty = ""
    return "Descriptor(name: \(name ?? empty))"
  }
}

/* open */ internal class DerivedDimensionDescriptor : Descriptor {
  public enum Function {
    case fratio, other(String)
  }
  public var function: DerivedDimensionDescriptor.Function? = .fratio
  public var dimensions: [String] = []
  public var A: Double? = nil
  public var B: Double? = nil
  public var C: Double? = nil

  open override var debugDescription: String {
    let empty = ""
    let f = (function == nil) ? empty : String(describing: function!)
    let p = "{ A: \(A ?? .nan), B: \(B ?? .nan), C: \(C ?? .nan) }"
    let lines = [
      "DerivedDimensionDescriptor(",
      "  name: \(name ?? empty)",
      "  function: \(f)",
      "  dimensions: \(dimensions)",
      "  parameters: \(p)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class CompensationDescriptor : Descriptor {
  public var detectors: [String] = []
  public var fluorochromes: [String] = []
  public var matrix: [Double] = []
  public var isInverted: Bool = false

  open override var debugDescription: String {
    let empty = ""
    let lines = [
      "CompensationDescriptor(",
      "  name: \(name ?? empty)",
      "  detectors: \(detectors)",
      "  fluorochromes: \(fluorochromes)",
      "  matrix: \(matrix)",
      "  isInverted: \(isInverted)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class TransformDescriptor : Descriptor {
  public enum Function {
    case flin, flog, fasinh, logicle, hyperlog, other(String)
  }
  public var function: TransformDescriptor.Function? = nil
  public var T: Double? = nil
  public var W: Double? = nil
  public var M: Double? = nil
  public var A: Double? = nil
  public var bounds: (Double, Double)? = nil

  open override var debugDescription: String {
    let empty = ""
    let f = (function == nil) ? empty : String(describing: function!)
    let p = "{ T: \(T ?? .nan), W: \(W ?? .nan), M: \(M ?? .nan), A: \(A ?? .nan) }"
    let b = (bounds == nil) ? empty : String(describing: bounds!)
    let lines = [
      "TransformDescriptor(",
      "  name: \(name ?? empty)",
      "  function: \(f)",
      "  parameters: \(p)",
      "  bounds: \(b)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class GateDescriptor : Descriptor {
  public var parent: String? = nil
  public var dimensions: [String] = []
  public var compensations: [String] = []
  public var transforms: [String] = []

  open override var debugDescription: String {
    let empty = ""
    let lines = [
      "GateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  dimensions: \(dimensions)",
      "  compensations: \(compensations)",
      "  transforms: \(transforms)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class RectangleGateDescriptor : GateDescriptor {
  public var ranges: [Range<Double>] = []

  open override var debugDescription: String {
    let empty = ""
    let r = ranges.map { ($0.lowerBound, $0.upperBound) }
    let lines = [
      "RectangleGateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  dimensions: \(dimensions)",
      "  compensations: \(compensations)",
      "  transforms: \(transforms)",
      "  ranges: \(r)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class PolygonGateDescriptor : GateDescriptor {
  public var vertices: [(x: Double, y: Double)] = []

  open override var debugDescription: String {
    let empty = ""
    let lines = [
      "PolygonGateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  dimensions: \(dimensions)",
      "  compensations: \(compensations)",
      "  transforms: \(transforms)",
      "  vertices: \(vertices)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class EllipsoidGateDescriptor : GateDescriptor {
  public var means: [Double] = []
  public var covariances: [Double] = []
  public var distanceSquared: Double? = nil

  open override var debugDescription: String {
    let empty = ""
    let lines = [
      "EllipsoidGateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  dimensions: \(dimensions)",
      "  compensations: \(compensations)",
      "  transforms: \(transforms)",
      "  means: \(means)",
      "  covariances: \(covariances)",
      "  distanceSquared: \(distanceSquared ?? .nan)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class QuadrantGateDescriptor : GateDescriptor {
  public var dimensionReferenceNames: [String] = []
  public var dividers: [[Double]] = []
  // Uniquely, a quadrant can be defined without specifying all coordinates; in
  // that case, the specification declares that "merging" of quadrants should
  // take place
  public var quadrants: [(name: String, position: [Double?])] = []

  open override var debugDescription: String {
    let empty = ""
    let q =
      "{ " + quadrants.map { quadrant -> String in
        "\(quadrant.name): [" + quadrant.position.map {
          String($0 ?? .nan)
        }.joined(separator: ", ") + "]"
      }.joined(separator: ", ") + " }"
    let lines = [
      "QuadrantGateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  dimensions: \(dimensions)",
      "  compensations: \(compensations)",
      "  transforms: \(transforms)",
      "  dividers: \(dividers)",
      "  quadrants: \(q)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}

/* open */ internal class BooleanGateDescriptor : GateDescriptor {
  public var operation: BooleanGate.Operation? = nil
  public var gates: [(name: String, complement: Bool)] = []

  open override var debugDescription: String {
    let empty = ""
    let o = (operation == nil) ? empty : String(describing: operation!)
    let g = gates.map { $0.complement ? ("!" + $0.name) : $0.name }
    let lines = [
      "BooleanGateDescriptor(",
      "  name: \(name ?? empty)",
      "  parent: \(parent ?? empty)",
      "  operation: \(o)",
      "  gates: \(g)",
      ")"
    ]
    return lines.joined(separator: "\n")
  }
}
