//
//  LogicleTransform.swift
//  FlowKit
//
//  Ported by Xiaodi Wu on 12/22/15.
//  Copyright © 2015–2016 Xiaodi Wu. All rights reserved.
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
  public static var defaultResolution = 4096
  public static let taylorPolynomialDegree = 16

  public let parameters: TransformParameters
  public let bounds: (Float, Float)?
  public var dynamicRange: Float {
    return Float(_slope(1) / _slope(_x1))
  }
  internal let _resolution: Int
  // Note that `_e` is not a parameter used in `LogicleTransform`
  // See comment in `AsinhTransform`
  internal let _a, _b, _c, _d, _e, _f, _w, _x0, _x1, _x2: Double
  internal let _taylorCoefficients: [Double]
  internal let _taylorCutoff: Double
  internal var _bins: [Double] = []
  /*
  internal var _binStrideInverses: [Double] = []
  internal var _binIndices: [Int] = []
  */
  internal var _asinhToLogicleBins: [Double] = []

  public init?(
    _ p: TransformParameters, bounds: (Float, Float)?, resolution: Int
  ) {
    // Internally, we use double precision and adjust `A`
    let T = Double(p.T), W = Double(p.W), M = Double(p.M)
    var A = Double(p.A)
    if resolution > 0 {
      var zero = (W + A) / (M + A)
      zero = floor(zero * Double(resolution) + 0.5) / Double(resolution)
      A = (M * zero - W) / (1 - zero)
    }
    // guard T > 0 && M > 0 && A >= 0 && A <= M else { return nil }
    self.parameters = p
    self.bounds = bounds
    _resolution = resolution

    // Initialize actual parameters (formulas from biexponential paper)
    _w = W / (M + A)
    _x2 = A / (M + A)
    _x1 = _x2 + _w
    _x0 = _x2 + 2 * _w
    _e = sinh(M * log(10)) / T
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
    t.reserveCapacity(LogicleTransform.taylorPolynomialDegree)
    for i in 0..<LogicleTransform.taylorPolynomialDegree {
      positive *= _b / (Double(i) + 1); negative *= -_d / (Double(i) + 1)
      t.append(positive + negative)
    }
    t[1] = 0 // Exact result
    _taylorCoefficients = t
    // Use Taylor series near `_x1` (i.e., data zero)
    _taylorCutoff = _x1 + _w / 4

    // Initialize internal properties for use in 'fast' approximation
    //
    // Note that we need to make use of internal methods, so all properties
    // below this point must be declared using `var` instead of `let` and must
    // be assigned a default value
    guard resolution > 0 else { return }

    // Compute bins
    var b = [Double](), bsi = [Double]()
    b.reserveCapacity(resolution + 1)
    bsi.reserveCapacity(resolution + 1)
    var previous: Double? = nil
    for i in 0..<(resolution + 1) {
      let current = _unscalingWithoutClipping(Double(i) / Double(resolution))
      b.append(current)
      if let previous = previous { bsi.append(1 / (current - previous)) }
      previous = current
    }
    // We'll need to append one final element to `bsi` because the array must
    // have count `resolution + 1`; this is necessary because it is possible to
    // have `_unbinning(...) == resolution`, necessitating interpolation using
    // values at index `resolution` and `resolution + 1`
    if let previous = previous {
      let current = _unscalingWithoutClipping(
        Double(resolution + 1) / Double(resolution)
      )
      bsi.append(1 / (current - previous))
    }
    _bins = b
    /*
    _binStrideInverses = bsi

    let lower = _unscalingWithoutClipping(0)
    let upper = _unscalingWithoutClipping(1)
    let difference = upper - lower
    var bi = [Int]()
    bi.reserveCapacity(resolution + 2)
    bi.append(_binning(lower) ?? 0)
    for i in 1..<(resolution + 2) {
      let v = _binning(lower + difference * Double(i) / Double(resolution))
      bi.append(v ?? resolution)
    }
    _binIndices = bi
    */

    var alb = [Double]()
    alb.reserveCapacity(resolution * 2 + 1)
    for i in -resolution...resolution {
      let v = Double(i) / Double(resolution)
      alb.append(_scalingWithoutClipping(sinh((v - _x2) * _b) / _e))
    }
    _asinhToLogicleBins = alb
  }

  public init?(
    T: Float = TransformParameters.default.T,
    W: Float = TransformParameters.default.W,
    M: Float = TransformParameters.default.M,
    A: Float = TransformParameters.default.A,
    bounds: (Float, Float)? = nil, resolution: Int
  ) {
    self.init(
      TransformParameters(T, W, M, A), bounds: bounds, resolution: resolution
    )
  }

  public init?(_ p: TransformParameters, bounds: (Float, Float)?) {
    self.init(p, bounds: bounds, resolution: LogicleTransform.defaultResolution)
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

/*
  internal func _binning(_ value: Double) -> Int? {
    guard _resolution > 0 else { return nil }
    // Binary search for appropriate bin
    var lo = 0, hi = _resolution
    while lo <= hi {
      let mid = (lo + hi) >> 1, key = _bins[mid]
      if value < key {
        hi = mid - 1
      } else if value > key {
        lo = mid + 1
      } else if mid < _resolution {
        return mid
      } else {
        return nil
      }
    }
    // Check range
    if hi < 0 || lo > _resolution { return nil }
    return lo - 1
  }

  internal func _unbinning(_ index: Int) -> Double? {
    // This `guard` condition also covers the case where `_resolution == 0`
    guard index >= 0 && index < _resolution else { return nil }
    return _bins[index]
  }
*/

  public func scaling(_ value: Float) -> Float {
    let value = Double(value)
    if _resolution > 0 {
      /*
      if let i = _binning(value) {
        let delta = (value - _bins[i]) / (_bins[i + 1] - _bins[i])
        return clipping(Float((Double(i) + delta) / Double(_resolution)))
      }
      */
      let a = (asinh(value * _e) / _b) + _x2
      if a >= -1 && a <= 1 {
        let p = a * Double(_resolution) + Double(_resolution), q = floor(p)
        let index = Int(q), delta = p - q
        let interpolation = (1 - delta) * _asinhToLogicleBins[index] +
          delta * _asinhToLogicleBins[index + 1]
        return clipping(Float(interpolation))
      }
    }
    return clipping(Float(_scalingWithoutClipping(value)))
  }

  public func unscaling(_ value: Float) -> Float {
    let value = Double(clipping(value))
    if _resolution > 0 {
      // Find the bin
      let x = value * Double(_resolution)
      let i = Int(floor(x))
      if i >= 0 && i < _resolution {
        // Interpolate linearly
        let delta = x - Double(i)
        return Float((1 - delta) * _bins[i] + delta * _bins[i + 1])
      }
    }
    return Float(_unscalingWithoutClipping(value))
  }

  public func scaling(_ values: [Float]) -> [Float] {
    precondition(_resolution > 0)
    //TODO: Handle input values not in domain
    /*
    var indices = [Double](repeating: 0, count: values.count)
    let lower = _unscalingWithoutClipping(0)
    let upper = _unscalingWithoutClipping(1)
    let difference = upper - lower
    let resolution = _resolution
    outer: for i in 0..<values.count {
      let value = Double(values[i])
      let j = Int((value - lower) / difference * Double(resolution))
      if j < 0 {
        //FIXME: Do the right thing if we aren't clipping
        indices[i] = 0
        continue outer
      }
      if j > resolution {
        //FIXME: Do the right thing if we aren't clipping
        indices[i] = Double(resolution)
        continue outer
      }
      var lo = _binIndices[j], hi = _binIndices[j + 1]
      if lo == hi {
        indices[i] = Double(lo)
        continue outer
      }
      // Binary search for appropriate bin
      while lo <= hi {
        let mid = (lo + hi) >> 1, key = _bins[mid]
        if value < key {
          hi = mid - 1
        } else if value > key {
          lo = mid + 1
        } else {
          indices[i] = Double(mid)
          continue outer
        }
      }
      indices[i] = Double(lo - 1)
    }

    var v0 = [Double](repeating: 0, count: values.count)
    var v1 = [Double](repeating: 0, count: values.count)
    var v2 = [Double](repeating: 0, count: values.count)
    var v3 = [Float](repeating: 0, count: values.count)
    // SP to DP
    vDSP_vspdp(values, 1, &v0, 1, UInt(values.count))
    // Gather values from `_binStrideInverses` based on `indices`
    vDSP_vindexD(_binStrideInverses, &indices, 1, &v1, 1, UInt(values.count))
    // Gather values from `_bins` based on `indices`
    vDSP_vindexD(_bins, &indices, 1, &v2, 1, UInt(values.count))
    // Compute `(values - v2) * v1`, storing in v1
    v0.withUnsafeBufferPointer{
      vDSP_vsbmD($0.baseAddress!, 1, &v2, 1, &v1, 1, &v1, 1, UInt(values.count))
    }
    // Compute `(indices + v1) / Double(resolution)`, storing in v2
    var ir = 1 / Double(resolution)
    vDSP_vasmD(&indices, 1, &v1, 1, &ir, &v2, 1, UInt(values.count))
    // DP to SP
    vDSP_vdpsp(&v2, 1, &v3, 1, UInt(values.count))
    return clipping(v3)
    */
    var v4 = [Double](repeating: 0, count: values.count)
    var v5 = [Double](repeating: 0, count: values.count)
    var v6 = [Double](repeating: 0, count: values.count)
    var v7 = [Float](repeating: 0, count: values.count)
    // SP to DP
    vDSP_vspdp(values, 1, &v4, 1, UInt(v4.count))
    // Compute asinh transform
    let c = Int32(v4.count), e = _e, ib = 1 / _b, x2 = _x2
    vDSP_vsmulD(v4, 1, [e], &v5, 1, UInt(v4.count))
    vvasinh(&v6, v5, [c]) // This cannot be done in-place
    vDSP_vsmsaD(v6, 1, [ib], [x2], &v6, 1, UInt(v4.count))
    // Interpolate
    let s = Double(_resolution), m = UInt(_asinhToLogicleBins.count)
    vDSP_vtabiD(v6, 1, [s], [s], _asinhToLogicleBins, m, &v6, 1, UInt(v4.count))
    // DP to SP
    vDSP_vdpsp(v6, 1, &v7, 1, UInt(v4.count))
    return clipping(v7)
  }

  public func unscaling(_ values: [Float]) -> [Float] {
    precondition(_resolution > 0)
    //TODO: Handle input values less than 0 or greater than 1
    var v0 = clipping(values)
    // SP to DP
    var v1 = [Double](repeating: 0, count: v0.count)
    vDSP_vspdp(v0, 1, &v1, 1, UInt(v0.count))
    // Find the bin and interpolate linearly
    let s = Double(_resolution)
    vDSP_vtabiD(
      v1, 1, [s], [0 as Double],
      _bins, UInt(_bins.count), &v1, 1, UInt(v0.count)
    )
    // DP to SP
    vDSP_vdpsp(v1, 1, &v0, 1, UInt(v0.count))
    return v0
  }
}
