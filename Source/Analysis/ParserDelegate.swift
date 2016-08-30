//
//  ParserDelegate.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 8/26/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

internal final class ParserDelegate : NSObject, XMLParserDelegate {
  public static let namespaceURIs = [
    "gating": [
      "http://www.isac-net.org/std/Gating-ML/v2.0/gating",
    ],
    "transforms": [
      "http://www.isac-net.org/std/Gating-ML/v2.0/transformations",
    ],
    "data-type": [
      "http://www.isac-net.org/std/Gating-ML/v2.0/datatypes",
    ]
  ]

  internal var namespacePrefixes: [String : [String]] = [:]
  // It's safe to keep a strong reference to the parser, because the parser
  // keeps an unowned reference to its delegate
  internal var currentParser: XMLParser? = nil
  internal var currentEntity: Entity? = nil
  internal var currentNumbers: [Double?] = []
  internal var currentStrings: [String?] = []
  internal var currentCharacters: String = ""

  public func parserDidStartDocument(_ parser: XMLParser) {
    currentParser = parser
  }

  public func parserDidEndDocument(_ parser: XMLParser) {
    guard currentParser == parser else { return }
    currentParser = nil
  }

  public func parser(
    _ parser: XMLParser,
    didStartMappingPrefix prefix: String,
    toURI namespaceURI: String
  ) {
    guard currentParser == parser else { return }
    for (key, uris) in ParserDelegate.namespaceURIs {
      if uris.contains(namespaceURI) {
        namespacePrefixes[key] = (namespacePrefixes[key] ?? []) + [prefix]
      }
    }
  }

  public func parser(
    _ parser: XMLParser,
    didStartElement name: String,
    namespaceURI: String?,
    qualifiedName: String?,
    attributes: [String : String] = [:]
  ) {
    guard currentParser == parser else { return }
    let prefixes = namespacePrefixes
    let attribute = { (_ namespace: String, _ name: String) -> String? in
      for prefix in prefixes[namespace] ?? [] {
        if let result = attributes[prefix + ":" + name] {
          return result
        }
      }
      return attributes[name]
    }

    switch name {
    // Data types
    case "fcs-dimension":
      let name = attribute("data-type", "name")
      currentStrings.append(name)
    case "new-dimension":
      let name = attribute("data-type", "transformation-ref")
      currentStrings.append(name)

    // Transforms
    case "spectrumMatrix":
      let name = attribute("transforms", "id")
      let entity = CompensationEntity(name: name)
      if
        let i = attribute("transforms", "matrix-inverted-already"),
        i.lowercased().trimmingCharacters(in: .whitespaces) == "true" {
        entity.isInverted = true
      }
      currentEntity = entity
    case "detectors", "fluorochromes", "spectrum": break
    case "coefficient":
      let value = Double(attribute("transforms", "value") ?? "")
      currentNumbers.append(value ?? .nan)
    case "transformation":
      // We don't yet know whether this is a Transform or a DerivedDimension
      let name = attribute("transforms", "id")
      currentStrings.append(name)
    case "flin", "flog", "fasinh", "logicle", "hyperlog":
      let entity = TransformEntity(name: currentStrings.first ?? nil)
      currentStrings = []
      entity.T = Double(attribute("transforms", "T") ?? "")
      entity.W = Double(attribute("transforms", "W") ?? "")
      entity.M = Double(attribute("transforms", "M") ?? "")
      entity.A = Double(attribute("transforms", "A") ?? "")
      // Perhaps inelegant:
      entity.function =
        (name == "flin")     ? .flin     :
        (name == "flog")     ? .flog     :
        (name == "fasinh")   ? .fasinh   :
        (name == "logicle")  ? .logicle  :
        (name == "hyperlog") ? .hyperlog : .other(name)
      // TODO: How are bounds described in Gating-ML?
      currentEntity = entity
    case "fratio":
      let entity = DerivedDimensionEntity(name: currentStrings.first ?? nil)
      currentStrings = []
      entity.A = Double(attribute("transforms", "A") ?? "")
      entity.B = Double(attribute("transforms", "B") ?? "")
      entity.C = Double(attribute("transforms", "C") ?? "")
      currentEntity = entity

    // Gating
    case "RectangleGate":
      let name = attribute("gating", "id")
      let entity = RectangleGateEntity(name: name)
      entity.parent = attribute("gating", "parent_id")
      currentEntity = entity
    case "PolygonGate":
      let name = attribute("gating", "id")
      let entity = PolygonGateEntity(name: name)
      entity.parent = attribute("gating", "parent_id")
      currentEntity = entity
    case "EllipsoidGate":
      let name = attribute("gating", "id")
      let entity = EllipsoidGateEntity(name: name)
      entity.parent = attribute("gating", "parent_id")
      currentEntity = entity
    case "QuadrantGate":
      let name = attribute("gating", "id")
      let entity = QuadrantGateEntity(name: name)
      entity.parent = attribute("gating", "parent_id")
      currentEntity = entity
    case "BooleanGate":
      let name = attribute("gating", "id")
      let entity = BooleanGateEntity(name: name)
      entity.parent = attribute("gating", "parent_id")
      currentEntity = entity
    case "dimension", "divider":
      if let entity = currentEntity as? GateEntity {
        let compensation = attribute("gating", "compensation-ref") ?? ""
        let transform = attribute("gating", "transformation-ref") ?? ""
        entity.compensations.append(compensation)
        entity.transforms.append(transform)
      }
      if let entity = currentEntity as? RectangleGateEntity {
        let min = Double(attribute("gating", "min") ?? "")
        let max = Double(attribute("gating", "max") ?? "")
        entity.ranges.append((min ?? -.infinity)..<(max ?? .infinity))
      }
      if let entity = currentEntity as? QuadrantGateEntity {
        let name = attribute("gating", "id")
        entity.dimensionReferenceNames.append(name ?? "")
      }
    case "vertex": break
    case "mean": break
    case "coordinate", "entry":
      let value = Double(attribute("data-type", "value") ?? "")
      currentNumbers.append(value ?? .nan)
    case "covarianceMatrix", "row": break
    case "distanceSquare":
      let value = Double(attribute("data-type", "value") ?? "")
      if let entity = currentEntity as? EllipsoidGateEntity {
        entity.distanceSquared = value
      }
    case "value":
      currentCharacters = "" // Clear previous characters found during parsing
      break
    case "Quadrant":
      let name = attribute("gating", "id")
      currentStrings.append(name)
    case "position":
      if
        let reference = attribute("gating", "divider_ref"),
        let entity = currentEntity as? QuadrantGateEntity,
        let index = entity.dimensionReferenceNames.index(of: reference) {
        // Make sure we have enough room in our array
        if index >= currentNumbers.count {
          let growth = index + 1 - currentNumbers.count
          currentNumbers += [Double?](repeating: nil, count: growth)
        }
        let location = Double(attribute("gating", "location") ?? "")
        currentNumbers[index] = location
      }
    case "not", "and", "or":
      if let entity = currentEntity as? BooleanGateEntity {
        entity.operation =
          (name == "not") ? .not :
          (name == "and") ? .and :
          .or
      }
    case "gateReference":
      if let entity = currentEntity as? BooleanGateEntity {
        let name = attribute("gating", "ref")
        let complement: Bool
        if
          let c = attribute("gating", "use-as-complement") ,
          c.lowercased().trimmingCharacters(in: .whitespaces) == "true" {
          complement = true
        } else {
          complement = false
        }
        entity.gates.append((name ?? "", complement))
      }
    default: break
    }
  }

  public func parser(
    _ parser: XMLParser,
    didEndElement name: String,
    namespaceURI: String?,
    qualifiedName: String?
  ) {
    guard currentParser == parser else { return }
    switch name {
    // Data types
    case "fcs-dimension", "new-dimension": break

    // Transforms
    case "spectrumMatrix":
      #if DEBUG
        debugPrint(currentEntity!)
      #endif
      // TODO: Add CompensationEntity to an array
      break
    case "detectors":
      if let entity = currentEntity as? CompensationEntity {
        entity.detectors = currentStrings.flatMap { $0 }
      }
      currentStrings = []
    case "fluorochromes":
      if let entity = currentEntity as? CompensationEntity {
        entity.fluorochromes = currentStrings.flatMap { $0 }
      }
      currentStrings = []
    case "spectrum":
      if let entity = currentEntity as? CompensationEntity {
        entity.matrix += currentNumbers.flatMap { $0 }
      }
      currentNumbers = []
    case "coefficient": break
    case "transformation":
      #if DEBUG
        debugPrint(currentEntity!)
      #endif
      // TODO: Add TransformEntity or DerivedDimensionEntity to an array
      break
    case "flin", "flog", "fasinh", "logicle", "hyperlog": break
    case "fratio":
      if let entity = currentEntity as? DerivedDimensionEntity {
        entity.function = .fratio
        entity.dimensions = currentStrings.flatMap { $0 }
      }
      currentStrings = []

    // Gating
    case "RectangleGate", "PolygonGate", "EllipsoidGate":
      fallthrough
    case "QuadrantGate", "BooleanGate":
      #if DEBUG
        debugPrint(currentEntity!)
      #endif
      // TODO: Add GateEntity to an array
      break
    case "divider":
      if let entity = currentEntity as? QuadrantGateEntity {
        entity.dividers.append(currentNumbers.flatMap { $0 })
      }
      currentNumbers = []
      fallthrough
    case "dimension":
      if let entity = currentEntity as? GateEntity {
        let strings = currentStrings.flatMap { $0 }
        // We expect that each gating:dimension contains either one
        // data-type:fcs-dimension or one data-type:new-dimension
        entity.dimensions.append(strings.first ?? "")
      }
      currentStrings = []
    case "vertex":
      if
        currentNumbers.count > 1,
        let entity = currentEntity as? PolygonGateEntity {
        let vertex = (currentNumbers[0] ?? .nan, currentNumbers[1] ?? .nan)
        entity.vertices.append(vertex)
      }
      currentNumbers = []
    case "mean":
      if let entity = currentEntity as? EllipsoidGateEntity {
        entity.means = currentNumbers.flatMap { $0 }
      }
      currentNumbers = []
    case "coordinate", "entry": break
    case "covarianceMatrix":
      if let entity = currentEntity as? EllipsoidGateEntity {
        entity.covariances = currentNumbers.flatMap { $0 }
      }
      currentNumbers = []
    case "row", "distanceSquare": break
    case "value":
      let characters = currentCharacters.trimmingCharacters(in: .whitespaces)
      currentCharacters = ""
      let value = Double(characters) ?? .nan
      currentNumbers.append(value)
    case "Quadrant":
      let name = (currentStrings.first ?? "") ?? ""
      currentStrings = []
      if let entity = currentEntity as? QuadrantGateEntity {
        entity.quadrants.append((name, currentNumbers))
      }
      currentNumbers = []
    case "position", "not", "and", "or", "gateReference": break

    // Other
    default: break
    }
  }

  public func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard currentParser == parser else { return }
    currentCharacters += string
  }
}
