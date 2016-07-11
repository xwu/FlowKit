//
//  HistogramTests.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/10/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class HistogramTests: XCTestCase {
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
  func testHistogram() {
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.urlForResource("Example", withExtension: "fcs")!
    let data = try! Data(contentsOf: url)
    let sample = Sample(data)!
    let transform = LinearTransform()!
    transform.scale(sample, dimensions: ["FSC-A", "SSC-A"])

    let population0 = Population(sample)
    let histogram0 = Histogram(
      population0,
      dimensions: ["SSC-A", "FSC-A"],
      resolution: 32
    )!

    let gate = RectangularGate(
      dimensions: ["FSC-A"],
      ranges: [0..<0.5]
    )
    let population1 = gate.masking(population0)!
    let histogram1 = Histogram(
      population1,
      dimensions: ["SSC-A", "FSC-A"],
      resolution: 32
    )!
    // print(histogram0.data, histogram1.data)
    for i in 0..<32 * 15 {
      XCTAssertEqual(histogram0.values[i], histogram1.values[i])
    }
  }
}
