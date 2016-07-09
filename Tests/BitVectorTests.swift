//
//  BitVectorTests.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/3/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class BitVectorTests: XCTestCase {
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
  func testBitVector() {
    let b = BitVector(repeating: .one, count: 12)
    XCTAssertEqual("\(b)", "111111111111")
    XCTAssertEqual(b.count, 12)
    XCTAssertEqual(b.cardinality(), 12)
    let c = ~b
    XCTAssertEqual(c.cardinality(), 0)
    var d = BitVector(count: 12)
    XCTAssertEqual(d.cardinality(), 0)
    d.set(0...2)
    XCTAssertEqual(d.cardinality(), 3)
    d.flip(2...4)
    XCTAssertEqual(d.cardinality(), 4)
    d.flip()
    XCTAssertEqual(d.cardinality(), 8)
    d.clear(10..<12)
    XCTAssertEqual("\(d)", "001001111100")
    XCTAssertEqual(d.contains(.zero), true)
    XCTAssertEqual(d.contains(.one), true)
    XCTAssertEqual(d.index(of: .one), 2)
    XCTAssertEqual(d.lastIndex(of: .one), 9)
    XCTAssertEqual("\(b & d)", "\(d)")
    XCTAssertEqual("\(c | d)", "\(d)")
    XCTAssertEqual("\(b ^ d)", "\(~d)")
    XCTAssertEqual("\(c ^ d)", "\(d)")
    d.set(0..<2)
    d.set(11)
    XCTAssertEqual(d.index(of: .zero), 3)
    XCTAssertEqual(d.lastIndex(of: .zero), 10)
    d.clear()
    XCTAssertEqual(d.cardinality(), 0)
  }

  func testBitVectorPerformance() {
    var x = BitVector(repeating: .zero, count: 1_000_000)
    var y = BitVector(repeating: .zero, count: 1_000_000)
    for _ in 0..<4000 {
      x.set(Int(floor(drand48() * 1_000_000)))
      y.set(Int(floor(drand48() * 1_000_000)))
    }
    self.measure {
      let z = x & y
      print(z[42])
    }
  }
}