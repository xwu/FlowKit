//
//  CompensationTests.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class CompensationTests : XCTestCase {
  var sample: Sample? = nil

  override func setUp() {
    super.setUp()
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.url(forResource: "Example", withExtension: "fcs")
    let data = try! Data(contentsOf: url!)
    guard let sample = Sample(data) else { return }
    self.sample = sample
  }
/*
  override func tearDown() {
    // Put teardown code here
    // This method is called after invocation of each test method in the class
    super.tearDown()
  }
*/
  func testAcquisitionCompensation() {
    guard let sample = sample else { return }
    let compensation = Compensation(sample)
    XCTAssertEqual(compensation!.detectors.count, 8)
    XCTAssertEqual(compensation!.detectors.first!, "FITC-A")
  }

  func testInvertedCompensation() {
    guard let sample = sample else { return }
    let compensation = Compensation(
      detectors: ["FSC-A", "SSC-A"],
      matrix: [2.0, -3.0, 4.0, -7.0]
    )
    let inverted = Compensation(
      detectors: ["FSC-A", "SSC-A"],
      fluorochromes: ["FSC-A", "SSC-A"],
      matrix: [3.5, -1.5, 2.0, -1.0],
      isInverted: true
    )
    XCTAssertEqual(compensation.detectors, inverted.detectors)
    XCTAssertEqual(
      compensation._unscramble(for: sample.parameters)!.0,
      inverted._unscramble(for: sample.parameters)!.0
    )
    // Make two copies so that each can be manipulated independently
    let copy1 = Sample(sample), copy2 = Sample(sample)
    compensation.unmix(copy1)
    inverted.unmix(copy2)
    for (k, v1) in copy1.events {
      let v2 = copy2.events[k]!
      XCTAssertEqual(v1.count, v2.count)
      for i in 0..<v1.count {
        XCTAssertLessThanOrEqual(abs(v1[i] - v2[i]), abs(v1[i] / 100000))
      }
    }
  }

  func testCompensationEquatability() {
    guard let sample = sample else { return }
    let compensation = Compensation(sample)!
    let (parameters, matrix) =
      compensation._unscramble(for: compensation.detectors.reversed())!
    let scrambled = Compensation(
      detectors: parameters, matrix: matrix, isInverted: compensation.isInverted
    )
    XCTAssertTrue(compensation == scrambled)
  }
/*
  func testPerformanceExample() {
    // This is an example of a performance test case
    self.measure {
      // Put code here
    }
  }
*/
}
