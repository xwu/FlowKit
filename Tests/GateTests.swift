//
//  GateTests.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/9/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class GateTests: XCTestCase {
/*
  override func setUp() {
    super.setUp()
    // Put setup code here
    // This method is called before invocation of each test method in the class
  }

  override func tearDown() {
    // Put teardown code here
    // This method is called after invocation of each test method in the class
    super.tearDown()
  }
*/
  func testEllipsoidGate() {
    let g = EllipsoidGate(
      dimensions: ["FSC-A", "SSC-A"],
      means: [400, 200],
      covariances: [40000, 0, 0, 30625],
      distanceSquared: 1
    )
    XCTAssertEqual(g.rotation!, 0)
    XCTAssertEqualWithAccuracy(g.halfAxes!.0, 200, accuracy: 0.001)
    XCTAssertEqualWithAccuracy(g.halfAxes!.1, 175, accuracy: 0.001)

    let h = EllipsoidGate(
      dimensions: ["FSC-A", "SSC-A"],
      means: [40, 40],
      covariances: [1134.5, -234.5, -234.5, 1134.5],
      distanceSquared: 1
    )
    XCTAssertEqualWithAccuracy(h.rotation!, -Float.pi / 4, accuracy: 0.000001)
    XCTAssertEqual(h.halfAxes!.0, 37)
    XCTAssertEqual(h.halfAxes!.1, 30)

    let i = EllipsoidGate(
      dimensions: ["FSC-A", "SSC-A"],
      means: [-0.2, -0.2],
      covariances: [1, 0, 0, 1],
      distanceSquared: 0.2
    )
    XCTAssert(i.rotation!.isNaN)
    XCTAssertEqualWithAccuracy(i.halfAxes!.0, 0.4472135955, accuracy: 0.000001)
    XCTAssertEqualWithAccuracy(i.halfAxes!.0, i.halfAxes!.1, accuracy: 0.000001)
  }

  func testRectangularGatePerformance() {
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.url(forResource: "Example", withExtension: "fcs")!
    let data = try! Data(contentsOf: url)
    let sample = Sample(data)!
    let transform = LinearTransform()!
    transform.scale(sample, dimensions: ["FSC-A", "SSC-A"])
    let gate = RectangularGate(
      dimensions: ["FSC-A", "SSC-A"],
      ranges: [0..<0.5, 0.2..<0.4]
    )
    // Artificially increase event count
    let s = Sample(sample, _times: 64)
    // Test for correctness
    //FIXME: Determine the correct expected result
    /*
    let population = gate.masking(s)!
    XCTAssertEqual(
      String(population.mask![0..<16]),
      String([1 as Float, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    )
    */
    /*
    XCTAssertEqual("\(population.mask![0..<16])", "1011111000000000")
    */
    // Test performance
    self.measure {
      let population = gate.masking(s)!
      XCTAssertEqual(population.mask!.count, 6757 * 64)
    }
  }

  func testEllipsoidGatePerformance() {
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.url(forResource: "Example", withExtension: "fcs")!
    let data = try! Data(contentsOf: url)
    let sample = Sample(data)!
    let transform = LinearTransform()!
    transform.scale(sample, dimensions: ["FSC-A", "SSC-A"])
    let gate = EllipsoidGate(
      dimensions: ["FSC-A", "SSC-A"],
      means: [-0.2, -0.2],
      covariances: [1, 0, 0, 1],
      distanceSquared: 0.2
    )
    // Artificially increase event count
    let s = Sample(sample, _times: 64)
    // Test for correctness
    //FIXME: Determine the correct expected result
    /*
    let population = gate.masking(s)!
    XCTAssertEqual(
      String(population.mask![0..<16]),
      String([0 as Float, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1])
    )
    */
    /*
    XCTAssertEqual("\(population.mask![0..<16])", "0000000111111111")
    */
    // Test performance
    self.measure {
      let population = gate.masking(s)!
      XCTAssertEqual(population.mask!.count, 6757 * 64)
    }
  }

  func testPolygonGatePerformance() {
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.url(forResource: "Example", withExtension: "fcs")!
    let data = try! Data(contentsOf: url)
    let sample = Sample(data)!
    /*
    let transform = LinearTransform()!
    transform.scale(sample, dimensions: ["FSC-A", "SSC-A"])
    */
    let gate = PolygonGate(
      dimensions: ["FSC-A", "SSC-A"],
      vertices: [
        (163, 320), (203, 118), (301, 359), (103, 172),
        (388, 190), (187, 387), (292, 110)
      ]
    )
    // Artificially increase event count
    let s = Sample(sample, _times: 64)
    // Artificially replace events with the following data
    s.events["FSC-A"]!.replaceSubrange(
      0..<8,
      with: [153, 160, 206, 207, 182, 245, 297, 230]
    )
    s.events["SSC-A"]!.replaceSubrange(
      0..<8,
      with: [141, 205, 206, 167, 269, 199, 234, 324]
    )
    // Test for correctness
    let population = gate.masking(s)!
    XCTAssertEqual(
      String(population.mask![0..<8]),
      String([0 as Float, 1, 0, 1, 1, 0, 1, 1])
    )
    /*
    XCTAssertEqual("\(population.mask![0..<8])", "01011011")
    */
    // Test performance
    self.measure {
      let population = gate.masking(s)!
      XCTAssertEqual(population.mask!.count, 6757 * 64)
    }
  }
}
