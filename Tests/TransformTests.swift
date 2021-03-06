//
//  TransformTests.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/19/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import XCTest
@testable import FlowKit

class TransformTests : XCTestCase {
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
  func testTransform() {
    struct CustomTransform : Transform {
      var parameters: TransformParameters
      var bounds: (Float, Float)?
      
      init?(_ parameters: TransformParameters, bounds: (Float, Float)?) {
        self.parameters = parameters
        self.bounds = bounds
      }

      func scaling(_ value: Float) -> Float {
        return value
      }

      func unscaling(_ value: Float) -> Float {
        return value
      }
    }
    let ct = CustomTransform()!
    XCTAssertEqual(ct.parameters.T, TransformParameters.default.T)
  }

  func testLinearTransform() {
    let t0 = LinearTransform(T: 1000, A: 0)!
    XCTAssertEqual(t0.scaling(-100), -0.1, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(-10), -0.01, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(0), 0, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(10), 0.01, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(100), 0.1, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(120), 0.12, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(890), 0.89, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(1000), 1, accuracy: 0.000001)

    XCTAssertEqual(t0.unscaling(1), 1000, accuracy: 0.000001)
    XCTAssertEqual(t0.unscaling(0.12), 120, accuracy: 0.000001)
    XCTAssertEqual(t0.unscaling(0.01), 10, accuracy: 0.000001)

    let t1 = LinearTransform(T: 1000, A: 100)!
    XCTAssertEqual(t1.scaling(-100), 0, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(-10), 0.081818, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(0), 0.090909, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(10), 0.1, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(100), 0.181818, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(120), 0.2, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(890), 0.9, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(1000), 1, accuracy: 0.000001)

    let t2 = LinearTransform(T: 1024, A: 256)!
    XCTAssertEqual(t2.scaling(-100), 0.121875, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(-10), 0.1921875, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(0), 0.2, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(10), 0.2078125, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(100), 0.278125, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(120), 0.29375, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(890), 0.8953125, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(1000), 0.98125, accuracy: 0.000001)

    for _ in 0..<1000 {
      let v = Float(drand48() * 1024)
      XCTAssertEqual(t2.scaling(v), t2.scaling([v])[0], accuracy: 0.000001)
      let w = Float(drand48())
      XCTAssertEqual(t2.unscaling(w), t2.unscaling([w])[0], accuracy: 0.000001)
    }

    let t3 = LinearTransform(T: 1000, A: 0, bounds: (0, 0.8))!
    XCTAssertEqual(t3.scaling(-100), 0, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(-10), 0, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(0), 0, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(10), 0.01, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(100), 0.1, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(120), 0.12, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(890), 0.8, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(1000), 0.8, accuracy: 0.000001)

    XCTAssertEqual(t3.unscaling(1), 800, accuracy: 0.000001)
    XCTAssertEqual(t3.unscaling(0.12), 120, accuracy: 0.000001)
    XCTAssertEqual(t3.unscaling(0.01), 10, accuracy: 0.000001)
  }

  func testLogTransform() {
    let t0 = LogTransform(T: 10000, M: 5)!
    XCTAssertTrue(t0.scaling(-1).isNaN)
    XCTAssertTrue(t0.scaling(0).isInfinite)
    XCTAssertTrue(t0.scaling(0).sign == .minus)
    XCTAssertEqual(t0.scaling(1), 0.2, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(10), 0.4, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(100), 0.6, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(1000), 0.8, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(1023), 0.801975, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(10000), 1, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(100000), 1.2, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(262144), 1.283708, accuracy: 0.000001)

    XCTAssertEqual(t0.unscaling(1), 10000, accuracy: 0.01)
    XCTAssertEqual(t0.unscaling(0.8), 1000, accuracy: 0.001)
    XCTAssertEqual(t0.unscaling(0.2), 1, accuracy: 0.000001)

    let t1 = LogTransform(T: 1023, M: 4.5)!
    XCTAssertTrue(t1.scaling(-1).isNaN)
    XCTAssertTrue(t1.scaling(0).isInfinite)
    XCTAssertTrue(t1.scaling(0).sign == .minus)
    XCTAssertEqual(t1.scaling(1), 0.331139, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(10), 0.553361, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(100), 0.775583, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(1000), 0.997805, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(1023), 1, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(10000), 1.220028, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(100000), 1.442250, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(262144), 1.535259, accuracy: 0.000001)

    let t2 = LogTransform()!
    XCTAssertTrue(t2.scaling(-1).isNaN)
    XCTAssertTrue(t2.scaling(0).isInfinite)
    XCTAssertTrue(t2.scaling(0).sign == .minus)
    XCTAssertEqual(t2.scaling(1), -0.204120, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(10), 0.018102, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(100), 0.240324, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(1000), 0.462547, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(1023), 0.464741, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(10000), 0.684768, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(100000), 0.906991, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(262144), 1, accuracy: 0.000001)

    for _ in 0..<1000 {
      let v = Float(drand48() * 262144)
      XCTAssertEqual(t2.scaling(v), t2.scaling([v])[0], accuracy: 0.000001)
      let w = Float(drand48())
      let a = t2.unscaling(w), b = t2.unscaling([w])[0]
      XCTAssertLessThanOrEqual(abs(a - b), abs(a / 100000))
    }

    let t3 = LogTransform(T: 10000, M: 5, bounds: (0, .infinity))!
    XCTAssertTrue(t3.scaling(-1).isNaN)

    XCTAssertEqual(t3.scaling(0), 0, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(1), 0.2, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(10), 0.4, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(100), 0.6, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(1000), 0.8, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(1023), 0.801975, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(10000), 1, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(100000), 1.2, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling(262144), 1.283708, accuracy: 0.000001)

    XCTAssertEqual(t3.unscaling(1), 10000, accuracy: 0.01)
    XCTAssertEqual(t3.unscaling(0.8), 1000, accuracy: 0.001)
    XCTAssertEqual(t3.unscaling(0.2), 1, accuracy: 0.000001)
    //FIXME: This failure is due to a bug in `vDSP_vclip()`
    XCTAssertFalse(t3.scaling([-1])[0].isNaN)
    XCTAssertEqual(t3.scaling([0])[0], 0, accuracy: 0.000001)
    XCTAssertEqual(t3.scaling([262144])[0], 1.283708, accuracy: 0.000001)
  }

  func testAsinhTransform() {
    let t0 = AsinhTransform(T: 1000, M: 4, A: 1)!
    XCTAssertEqual(t0.scaling(-10), -0.200009, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(-5), -0.139829, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(-1), -0.000856, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(0), 0.2, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(0.3), 0.303776, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(1), 0.400856, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(3), 0.495521, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(10), 0.600009, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(100), 0.8, accuracy: 0.000001)
    XCTAssertEqual(t0.scaling(1000), 1, accuracy: 0.000001)

    XCTAssertEqual(t0.unscaling(1), 1000, accuracy: 0.001)
    XCTAssertEqual(t0.unscaling(0.8), 100, accuracy: 0.0001)
    XCTAssertEqual(t0.unscaling(0.2), 0, accuracy: 0.000001)

    let t1 = AsinhTransform(T: 1000, M: 5, A: 0)!
    XCTAssertEqual(t1.scaling(-10), -0.6, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(-5), -0.539794, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(-1), -0.400009, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(0), 0, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(0.3), 0.295521, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(1), 0.400009, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(3), 0.495425, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(10), 0.6, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(100), 0.8, accuracy: 0.000001)
    XCTAssertEqual(t1.scaling(1000), 1, accuracy: 0.000001)

    let t2 = AsinhTransform(T: 1000, M: 3, A: 2)!
    XCTAssertEqual(t2.scaling(-10), 0.199144, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(-5), 0.256923, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(-1), 0.358203, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(0), 0.4, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(0.3), 0.412980, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(1), 0.441797, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(3), 0.503776, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(10), 0.600856, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(100), 0.800009, accuracy: 0.000001)
    XCTAssertEqual(t2.scaling(1000), 1, accuracy: 0.000001)

    for _ in 0..<1000 {
      let v = Float(drand48() * 1000)
      XCTAssertEqual(t2.scaling(v), t2.scaling([v])[0], accuracy: 0.000001)
      let w = Float(drand48())
      let a = t2.unscaling(w), b = t2.unscaling([w])[0]
      XCTAssertLessThanOrEqual(abs(a - b), abs(a / 100000))
    }
  }

  func testLogicleTransform() {
    let l = LogicleTransform(
      T: 10000, W: 0.5, M: 4.5, A: 0, resolution: 1 << 12
    )!
    /*
    XCTAssertEqual(l._binning(0.9)!, 562)
    */
    XCTAssertEqual(l.scaling(0), 0.111084, accuracy: 0.000001)
    XCTAssertEqual(l.scaling(10), 0.310475, accuracy: 0.000001)
    XCTAssertEqual(l.scaling(100), 0.552123, accuracy: 0.000001)
    XCTAssertEqual(l.scaling(1000), 0.777427, accuracy: 0.000001)
    XCTAssertEqual(l.scaling(9999), 0.999999, accuracy: 0.00001)
    XCTAssertEqual(l.unscaling(0.6), 162.103, accuracy: 0.001)
    XCTAssertEqual(l.unscaling(0.5), 59.5513, accuracy: 0.0001)
    /*
    XCTAssertEqualWithAccuracy(
      l._unbinning(l._binning(59.5513)!)!, 59.5513, accuracy: 0.6
    )
    XCTAssertEqualWithAccuracy(
      l._unbinning(l._binning(1000.0)!)!, 1000.0, accuracy: 10
    )
    */
    let inputs = [0 as Float, 10, 100, 1000, 9999]
    let actual = l.scaling(inputs)
    let expected = [0.111084 as Float, 0.310475, 0.552123, 0.777427, 0.999999]
    let accuracies = [0.000001 as Float, 0.000001, 0.000001, 0.000001, 0.00001]
    for i in 0..<5 {
      XCTAssertEqual(actual[i], expected[i], accuracy: accuracies[i])
    }

    let l2 = LogicleTransform(T: 10000, W: 0.5, M: 4.5, A: 0, resolution: 0)!
    XCTAssertEqual(l2.dynamicRange, 3042.12, accuracy: 0.01)
    XCTAssertEqual(l2.scaling(0.0), 0.111111, accuracy: 0.000001)
    XCTAssertEqual(l2.scaling(10.0), 0.310496, accuracy: 0.000001)
    XCTAssertEqual(l2.scaling(100.0), 0.552137, accuracy: 0.000001)
    XCTAssertEqual(l2.scaling(1000.0), 0.777433, accuracy: 0.000001)
    XCTAssertEqual(l2.scaling(9999.9), 0.999999, accuracy: 0.00001)
    XCTAssertEqual(l2.unscaling(0.6), 162.082, accuracy: 0.001)
    XCTAssertEqual(l2.unscaling(0.5), 59.5424, accuracy: 0.0001)
  }

  func testAsinhTransformPerformance() {
    let a = AsinhTransform(T: 10000, W: 0.5, M: 4.5, A: 0)!
    var input = [Float]()
    for _ in 0..<1000000 {
      input.append(Float(drand48() * 10000))
    }
    self.measure {
      let result = a.scaling(input)
      print(result[42])
    }
  }

  func testLogicleTransformPerformance() {
    let l = LogicleTransform(T: 10000, W: 0.5, M: 4.5, A: 0)!
    var input = [Float]()
    for _ in 0..<1000000 {
      input.append(Float(drand48() * 10000))
    }
    self.measure {
      let result = l.scaling(input)
      print(result[42])
    }
  }

  func testTransformEquatability() {
    let lin0 = LinearTransform(T: 10, W: 12, M: 14, A: 5)!
    let lin1 = LinearTransform(T: 10, W: 4, M: 6, A: 5)!
    let lin2 = LinearTransform(T: 10, A: 5)!
    let lin3 = LinearTransform(T: 10, A: 0)!
    XCTAssertTrue(lin0 == lin1)
    XCTAssertTrue(lin0 == lin2)
    XCTAssertFalse(lin0 == lin3)

    let log0 = LogTransform(T: 10, W: -2, M: 12, A: 2)!
    let log1 = LogTransform(T: 10, W: -4, M: 12, A: 4)!
    let log2 = LogTransform(T: 10, M: 12)!
    let log3 = LogTransform(T: 10, M: 2)!
    XCTAssertTrue(log0 == log1)
    XCTAssertTrue(log0 == log2)
    XCTAssertFalse(log0 == log3)

    let asinh0 = AsinhTransform(T: 10, W: -2, M: 12, A: 2)!
    let asinh1 = AsinhTransform(T: 10, W: -4, M: 12, A: 2)!
    let asinh2 = AsinhTransform(T: 10, M: 12, A: 2)!
    let asinh3 = AsinhTransform(T: 10, M: 12, A: 4)!
    XCTAssertTrue(asinh0 == asinh1)
    XCTAssertTrue(asinh0 == asinh2)
    XCTAssertFalse(asinh0 == asinh3)

    let lgcl0 = LogicleTransform(T: 10, W: 2, M: 6, A: 0)!
    let lgcl1 = LogicleTransform(T: 10, W: 2, M: 6, A: 0.5)!
    let lgcl2 = LogicleTransform(T: 10, W: 1, M: 6, A: 0)!
    XCTAssertFalse(lgcl0 == lgcl1)
    XCTAssertFalse(lgcl0 == lgcl2)

    let lgcl3 = LogicleTransform(
      T: 10, W: 2, M: 6, A: 0, bounds: (-Float.infinity, Float.infinity)
    )!
    let lgcl4 = LogicleTransform(
      T: 10, W: 2, M: 6, A: 0, bounds: (0, Float.infinity)
    )!
    XCTAssertTrue(lgcl0 == lgcl3)
    XCTAssertFalse(lgcl0 == lgcl4)

    let lgcl5 = LogicleTransform(
      T: 10, W: 2, M: 6, A: 0, resolution: LogicleTransform.defaultResolution
    )!
    let lgcl6 = LogicleTransform(
      T: 10, W: 2, M: 6, A: 0, resolution: 0
    )!
    XCTAssertTrue(lgcl0 == lgcl5)
    XCTAssertFalse(lgcl0 == lgcl6)
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
