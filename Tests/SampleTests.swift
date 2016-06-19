//
//  FlowKitTests.swift
//  FlowKitTests
//
//  Created by Xiaodi Wu on 6/18/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class SampleTests : XCTestCase {
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
  func testSample() {
    let testBundle = Bundle(for: SampleTests.self)
    let url = testBundle.urlForResource("Example", withExtension: "fcs")
    let data = try! Data(contentsOf: url!)
    guard let sample = Sample(data) else { return }
    XCTAssertEqual(sample.parameters.count, 16)
    XCTAssertEqual(sample.parameters[0], "FSC-A")
    XCTAssertEqual(sample.count, 6757)
    XCTAssertEqual(sample._rawEvents.count, 108112)
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
