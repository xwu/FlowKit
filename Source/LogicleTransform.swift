//
//  LogicleTransform.swift
//  FlowKit
//
//  Ported by Xiaodi Wu on 12/22/15.
//  Copyright © 2015-2016 Xiaodi Wu. All rights reserved.
//  Copyright © 2009, 2011, 2012 The Board of Trustees of The Leland Stanford
//  Junior University. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  - Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  - Neither the name of The Leland Stanford Junior University nor the names of
//    its contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  The Logicle method is patented under United States Patent 6,954,722.
//  Stanford University does not enforce the patent for non-profit academic
//  purposes or for commercial use in the field of flow cytometry.
//

import Foundation
import Accelerate

public struct LogicleTransform : Transform {
  public static let defaultResolution = 4096
  public static let taylorPolynomialDegree = 16

  public let parameters: _Parameters
  public let bounds: (Float, Float)?
  public var dynamicRange: Float {
    return Float(_slope(1) / _slope(_x1))
  }
  internal let _resolution: Int
  internal let _a, _b, _c, _d, _f, _w, _x0, _x1, _x2: Double
  internal let _taylorCoefficients: [Double]
  internal let _taylorCutoff: Double

  public init?(
    parameters p: _Parameters, bounds: (Float, Float)?, resolution: Int
  ) {
    self.parameters = p
    self.bounds = bounds
    _resolution = resolution

    // Internally, we use double precision and adjust `A`
    let T = Double(p.T), W = Double(p.W), M = Double(p.M)
    var A = Double(p.A)
    if resolution > 0 {
      var zero = (W + A) / (M + A)
      zero = floor(zero * Double(resolution) + 0.5) / Double(resolution)
      A = (M * zero - W) / (1 - zero)
    }

    // Initialize actual parameters (formulas from biexponential paper)
    _w = W / (M + A)
    _x2 = A / (M + A)
    _x1 = _x2 + _w
    _x0 = _x2 + 2 * _w
    _b = (M + A) * log(10)

    func solve(_ b: Double, _ w: Double) -> Double? {
      // If `w == 0`, then it's really asinh
      if w == 0 { return b }
      // Precision is the same as that of `b`
      let tolerance = 2 * b * (1 as Double).ulp

      // Based on `rtsafe()` from _Numerical Recipes_, 1st Ed.
      // Bracket the root
      var d_lo = 0 as Double, d_hi = b
      // First bisection
      var d = (d_lo + d_hi) / 2, last_delta = d_hi - d_lo, delta: Double
      // Evaluate f(w, b) = 2 * (ln(d) - ln(b)) + w * (b + d) and its derivative
      let f_b = -2 * log(b) + w * b
      var f = 2 * log(d) + w * d + f_b, last_f = Double.nan, df, t: Double

      for _ in 1..<20 {
        // Compute derivative
        df = 2 / d + w

        let temporary = ((d - d_hi) * df - f) * ((d - d_lo) * df - f)
        // If Newton's method would step outside the bracket
        // or if it's not converging quickly enough...
        if temporary >= 0 || fabs(1.9 * f) > fabs(last_delta * df) {
          // ...take a bisection step
          delta = (d_hi - d_lo) / 2; d = d_lo + delta
          // (We're done if nothing changed)
          if d == d_lo { return d }
        } else {
          // ...else take a Newton's method step
          delta = f / df; t = d; d -= delta
          // (We're done if nothing changed)
          if d == t { return d }
        }

        // We're done if we've reached the desired precision
        if fabs(delta) < tolerance { return d }
        last_delta = delta
        // Recompute function
        f = 2 * log(d) + w * d + f_b
        // We're done if we've found the root or aren't getting closer
        if f == 0 || f == last_f { return d }
        last_f = f
        // Update bracketing interval
        if f < 0 { d_lo = d } else { d_hi = d }
      }
      return nil
    }

    guard let d = solve(_b, _w) else { return nil }
    _d = d
    let c_a = exp(_x0 * (_b + _d))
    let mf_a = exp(_b * _x1) - c_a / exp(_d * _x1)
    _a = T / ((exp(_b) - mf_a) - c_a / exp(_d))
    _c = c_a * _a
    _f = -mf_a * _a

    // Compute Taylor series coefficients
    var positive = _a * exp(_b * _x1), negative = -_c / exp(_d * _x1)
    var t = [Double]()
    for i in 0..<LogicleTransform.taylorPolynomialDegree {
      positive *= _b / (Double(i) + 1); negative *= -_d / (Double(i) + 1)
      t.append(positive + negative)
    }
    t[1] = 0 // Exact result
    _taylorCoefficients = t
    // Use Taylor series near `_x1` (i.e., data zero)
    _taylorCutoff = _x1 + _w / 4
  }

  public init?(
    T: Float = LogicleTransform.defaultParameters.T,
    W: Float = LogicleTransform.defaultParameters.W,
    M: Float = LogicleTransform.defaultParameters.M,
    A: Float = LogicleTransform.defaultParameters.A,
    bounds: (Float, Float)? = nil, resolution: Int
  ) {
    self.init(
      parameters: (T, W, M, A), bounds: bounds, resolution: resolution
    )
  }

  public init?(parameters p: _Parameters, bounds: (Float, Float)?) {
    self.init(
      parameters: p, bounds: bounds,
      resolution: LogicleTransform.defaultResolution
    )
  }

  internal func _seriesBiexponential(_ scaledValue: Double) -> Double {
    // Taylor series is around `_x1`
    let x = scaledValue - _x1
    return _taylorCoefficients.reversed().reduce(0) { ($0 + $1) * x }
  }

  internal func _slope(_ scaledValue: Double) -> Double {
    // Reflect negative scale regions
    let v = (scaledValue < _x1) ? (2 * _x1 - scaledValue) : scaledValue
    return _a * _b * exp(_b * v) + _c * _d / exp(_d * v)
  }

  internal func _scalingWithoutClipping(_ value: Double) -> Double {
    // Handle true zero separately
    if value == 0 { return _x1 }

    // Reflect negative values
    let isNegative = value < 0
    let value = isNegative ? -value : value

    // Initial guess at solution
    var x = value < _f ?                     // If in quasi-linear region...
      _x1 + value / _taylorCoefficients[0] : // ...use a linear approximation
      log(value / _a) / _b                   // ...else, use a logarithm

    // Try for double precision unless in extended range
    let tolerance = x > 1 ?
      3 * x * (1 as Double).ulp :
      3 * (1 as Double).ulp

    for _ in 0..<10 {
      let ae2bx = _a * exp(_b * x), ce2mdx = _c / exp(_d * x)
      // Use Taylor series near zero
      let y = x < self._taylorCutoff ?
        _seriesBiexponential(x) - value :
        (ae2bx + _f) - (ce2mdx + value)
      let abe2bx = _b * ae2bx, cde2mdx = _d * ce2mdx
      let dy = abe2bx + cde2mdx, ddy = _b * abe2bx - _d * cde2mdx
      // Use Halley's method with cubic convergence
      let delta = y / (dy * (1 - y * ddy / (2 * dy * dy)))
      x -= delta
      // We're done if we've reached the desired precision
      if fabs(delta) < tolerance { return isNegative ? (2 * _x1 - x) : x }
    }
    return .nan
  }

  internal func _unscalingWithoutClipping(_ value: Double) -> Double {
    // Reflect negative scale regions
    let isNegative = value < _x1
    let value = isNegative ? (2 * _x1 - value) : value
    // Use Taylor series near `_x1` (i.e., data zero)
    let unscaledValue = value < self._taylorCutoff ?
      _seriesBiexponential(value) :
      (_a * exp(_b * value) + _f) - _c / exp(_d * value)
    return isNegative ? -unscaledValue : unscaledValue
  }

  public func scaling(_ value: Float) -> Float {
    return clipping(Float(_scalingWithoutClipping(Double(value))))
  }

  public func unscaling(_ value: Float) -> Float {
    return Float(_unscalingWithoutClipping(Double(clipping(value))))
  }
}
