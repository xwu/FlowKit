//
//  BitVector.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/3/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

internal struct _LeadingZerosLookupTable {
  static let nibble = [4 as UInt8, 3, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  private init() { }
}

internal extension UInt32 {
  /// The bit width of the underlying binary representation of values of `self`.
  static var _bitWidth: Int { return 32 }

  /// The number of ones in the binary representation of the current value.
  var _popcount: Int {
    // Based on the algorithm presented at:
    // https://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel
    var v = self &- ((self >> 1) & UInt32(0x55555555))
    v = (v & UInt32(0x33333333)) &+ ((v >> 2) & UInt32(0x33333333))
    return Int((((v &+ (v >> 4)) & UInt32(0x0F0F0F0F)) &* 0x01010101) >> 24)
  }

  /// The number of zeros preceding the most significant one bit in the binary
  /// representation of the current value.
  var _leadingZeros: Int {
    // Based on the algorithm presented at:
    // https://en.wikipedia.org/wiki/Find_first_set#CLZ
    var v = self, c: Int
    if (v & UInt32(0xFFFF0000)) == 0 { c = 16; v <<= 16 } else { c = 0 }
    if (v & UInt32(0xFF000000)) == 0 { c += 8; v <<= 8 }
    if (v & UInt32(0xF0000000)) == 0 { c += 4; v <<= 4 }
    c += Int(_LeadingZerosLookupTable.nibble[Int(v >> 28)])
    return c
  }

  /// The number of zeros following the least significant one bit in the binary
  /// representation of the current value.
  var _trailingZeros: Int {
    // Based on the mathematical relation outlined at:
    // https://en.wikipedia.org/wiki/Find_first_set#Properties_and_relations
    let leastSignificantBit =
      (Int32(bitPattern: self) & -Int32(bitPattern: self))
    return UInt32(bitPattern: leastSignificantBit - 1)._popcount
  }
}

internal func << <
  T : BidirectionalCollection
  where T.Iterator.Element == UInt32, T.IndexDistance == Int
>(lhs: T, rhs: Int) -> [UInt32] {
  precondition(rhs >= 0 && rhs < 32)
  if rhs == 0 { return [UInt32](lhs) }

  let shift0 = UInt32(rhs)
  let mask = ~(UInt32.max >> shift0)
  let shift1 = 32 - shift0

  var result = [UInt32](repeating: 0, count: lhs.count)
  var index = lhs.count - 1
  var previous = 0 as UInt32
  for element in lhs.reversed() {
    result[index] = (element << shift0) | previous
    index -= 1
    previous = (element & mask) >> shift1
  }
  return result
}

public enum Bit : UInt8 {
  case zero = 0, one
}

public struct BitVector {
  public typealias Bucket = UInt32

  internal static func _offset(for index: Int) -> Int {
    return index / Bucket._bitWidth
  }

  internal static func _offsets(for range: Range<Int>) -> (Int, Int) {
    let a = range.lowerBound / Bucket._bitWidth
    let b = (range.upperBound + Bucket._bitWidth - 1) / Bucket._bitWidth
    return (a, b)
  }

  internal static func _mask(for index: Int) -> Bucket {
    return 1 << Bucket(Bucket._bitWidth - (index % Bucket._bitWidth) - 1)
  }

  internal static func _masks(for range: Range<Int>) -> (Bucket, Bucket) {
    let first = Bucket.max >> Bucket(range.lowerBound % Bucket._bitWidth)
    let x = Bucket._bitWidth - (range.upperBound % Bucket._bitWidth)
    let last = Bucket.max << Bucket(x % Bucket._bitWidth)
    return (first, last)
  }

  public internal(set) var buckets: [Bucket] = []
  public let count: Int

  public init<S : Sequence where S.Iterator.Element == Bit>(_ s: S) {
    let raw = s.map { $0.rawValue }
    self.init(raw)
  }

  public init(_ a: [UInt8]) {
    self.count = a.count
    
    let bw = Bucket._bitWidth, capacity = (a.count + bw - 1) / bw
    var buckets = [Bucket]()
    buckets.reserveCapacity(capacity)
    var bucket = 0 as Bucket

    var i = 0 as Bucket
    for element in a {
      bucket <<= 1
      bucket += Bucket(element % 2)
      i += 1
      if i == Bucket(bw) {
        buckets.append(bucket)
        bucket = 0
        i = 0
      }
    }
    if i > 0 {
      bucket <<= Bucket((bw - (a.count % bw)) % bw)
      buckets.append(bucket)
    }
    self.buckets = buckets
  }

  public init(buckets: [Bucket], count: Int) {
    precondition(count >= 0)
    self.count = count

    let i = buckets.count
    let f = (count + Bucket._bitWidth - 1) / Bucket._bitWidth
    if f < i {
      self.buckets = [Bucket](buckets.prefix(f))
    } else if f == i {
      self.buckets = buckets
    } else {
      self.buckets = [Bucket](repeating: 0, count: f)
      self.buckets.replaceSubrange(0..<i, with: buckets)
    }
    assert(self.buckets.count == f)

    // Various methods assume bits past `count` are zero
    let (_, mask) = BitVector._masks(for: 0..<count)
    if let last = self.buckets.last where last != (last & mask) {
      self.buckets[self.buckets.endIndex - 1] = (last & mask)
    }
  }

  public init(repeating repeatedValue: Bit = .zero, count: Int) {
    precondition(count >= 0)
    self.count = count

    let bc = (count + Bucket._bitWidth - 1) / Bucket._bitWidth
    let rv = repeatedValue == .zero ? 0 : Bucket.max
    buckets = [Bucket](repeating: rv, count: bc)

    // Various methods assume bits past `count` are zero
    let (_, mask) = BitVector._masks(for: 0..<count)
    if let last = buckets.last where last != (last & mask) {
      buckets[buckets.endIndex - 1] = (last & mask)
    }
  }

  public subscript(_ position: Int) -> Bit {
    precondition(position >= 0 && position < count)
    let offset = BitVector._offset(for: position)
    let mask = BitVector._mask(for: position)
    return ((buckets[offset] & mask) == 0) ? .zero : .one
  }

  public subscript(_ bounds: Range<Int>) -> BitVector {
    precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
    let (a, b) = BitVector._offsets(for: bounds)
    let shift = bounds.lowerBound % Bucket._bitWidth
    return BitVector(buckets: buckets[a..<b] << shift, count: bounds.count)
  }

  public func cardinality() -> Int {
    var v = 0
    for b in buckets { v += b._popcount }
    return v
  }

  public func contains(_ bit: Bit) -> Bool {
    return (index(of: bit) != nil)
  }

  public func index(of bit: Bit) -> Int? {
    var v = 0
    switch bit {
    case .zero:
      for b in buckets {
        let clz = (~b)._leadingZeros
        v += clz
        if clz < Bucket._bitWidth { return v < count ? v : nil }
      }
    case .one:
      for b in buckets {
        let clz = b._leadingZeros
        v += clz
        if clz < Bucket._bitWidth { return v }
      }
    }
    return nil
  }

  public func lastIndex(of bit: Bit) -> Int? {
    let shift =
      (Bucket._bitWidth - (count % Bucket._bitWidth)) % Bucket._bitWidth
    var v = count + shift - 1
    switch bit {
    case .zero:
      if let b = buckets.last {
        let ctz = (~b & (Bucket.max << Bucket(shift)))._trailingZeros
        v -= ctz
        if ctz < Bucket._bitWidth { return v }
      }
      for b in buckets.dropLast().reversed() {
        let ctz = (~b)._trailingZeros
        v -= ctz
        if ctz < Bucket._bitWidth { return v }
      }
    case .one:
      for b in buckets.reversed() {
        let ctz = b._trailingZeros
        v -= ctz
        if ctz < Bucket._bitWidth { return v }
      }
    }
    return nil
  }

  internal func _bounds(sanitizing bounds: Range<Int>?) -> Range<Int> {
    guard let bounds = bounds else { return 0..<count }
    precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
    return bounds
  }

  public mutating func set(_ bounds: Range<Int>? = nil) {
    let bounds = _bounds(sanitizing: bounds)
    guard bounds.count > 0 else { return }
    let (a, b) = BitVector._offsets(for: bounds)
    let (m0, m1) = BitVector._masks(for: bounds)

    if a == b - 1 {
      buckets[a] |= (m0 & m1)
    } else {
      buckets[a] |= m0
      for i in (a + 1)..<(b - 1) { buckets[i] = Bucket.max }
      buckets[b - 1] |= m1
    }
  }

  public mutating func set(_ bounds: ClosedRange<Int>) {
    set(bounds.lowerBound..<bounds.upperBound + 1)
  }

  public mutating func set(_ position: Int) {
    precondition(position >= 0 && position < count)
    let offset = BitVector._offset(for: position)
    let mask = BitVector._mask(for: position)
    buckets[offset] |= mask
  }

  public mutating func clear(_ bounds: Range<Int>? = nil) {
    let bounds = _bounds(sanitizing: bounds)
    guard bounds.count > 0 else { return }
    let (a, b) = BitVector._offsets(for: bounds)
    let (m0, m1) = BitVector._masks(for: bounds)

    if a == b - 1 {
      buckets[a] &= ~(m0 & m1)
    } else {
      buckets[a] &= ~m0
      for i in (a + 1)..<(b - 1) { buckets[i] = 0 }
      buckets[b - 1] &= ~m1
    }
  }

  public mutating func clear(_ bounds: ClosedRange<Int>) {
    clear(bounds.lowerBound..<bounds.upperBound + 1)
  }

  public mutating func clear(_ position: Int) {
    precondition(position >= 0 && position < count)
    let offset = BitVector._offset(for: position)
    let mask = BitVector._mask(for: position)
    buckets[offset] &= ~mask
  }

  public mutating func flip(_ bounds: Range<Int>? = nil) {
    let bounds = _bounds(sanitizing: bounds)
    guard bounds.count > 0 else { return }
    let (a, b) = BitVector._offsets(for: bounds)
    let (m0, m1) = BitVector._masks(for: bounds)

    if a == b - 1 {
      let mask = m0 & m1
      buckets[a] = (buckets[a] & ~mask) | (~buckets[a] & mask)
    } else {
      buckets[a] = (buckets[a] & ~m0) | (~buckets[a] & m0)
      for i in (a + 1)..<(b - 1) { buckets[i] = ~buckets[i] }
      buckets[b - 1] = (buckets[b - 1] & ~m1) | (~buckets[b - 1] & m1)
    }
  }

  public mutating func flip(_ bounds: ClosedRange<Int>) {
    flip(bounds.lowerBound..<bounds.upperBound + 1)
  }

  public mutating func flip(_ position: Int) {
    precondition(position >= 0 && position < count)
    let offset = BitVector._offset(for: position)
    let mask = BitVector._mask(for: position)
    buckets[offset] = (buckets[offset] & ~mask) | (~buckets[offset] & mask)
  }
}

extension BitVector : BidirectionalCollection {
  public var startIndex: Int { return 0 }
  public var endIndex: Int { return count }

  public func index(after i: Int) -> Int {
    return i + 1
  }
  public func formIndex(after i: inout Int) {
    i += 1
  }
  public func index(before i: Int) -> Int {
    return i - 1
  }
  public func formIndex(before i: inout Int) {
    i -= 1
  }
}

extension BitVector : CustomStringConvertible {
  public var description: String {
    return self.reduce("") { $0 + String($1.rawValue) }
  }
}

// MARK: Bitwise operations
public func & (lhs: BitVector, rhs: BitVector) -> BitVector {
  precondition(lhs.count == rhs.count)
  var l = lhs.buckets
  for i in 0..<l.count {
    l[i] &= rhs.buckets[i]
  }
  return BitVector(buckets: l, count: lhs.count)
}

public func &= (lhs: inout BitVector, rhs: BitVector) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.buckets.count {
    lhs.buckets[i] &= rhs.buckets[i]
  }
}

public func | (lhs: BitVector, rhs: BitVector) -> BitVector {
  precondition(lhs.count == rhs.count)
  var l = lhs.buckets
  for i in 0..<l.count {
    l[i] |= rhs.buckets[i]
  }
  return BitVector(buckets: l, count: lhs.count)
}

public func |= (lhs: inout BitVector, rhs: BitVector) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.buckets.count {
    lhs.buckets[i] |= rhs.buckets[i]
  }
}

public func ^ (lhs: BitVector, rhs: BitVector) -> BitVector {
  precondition(lhs.count == rhs.count)
  var l = lhs.buckets
  for i in 0..<l.count {
    l[i] ^= rhs.buckets[i]
  }
  return BitVector(buckets: l, count: lhs.count)
}

public func ^= (lhs: inout BitVector, rhs: BitVector) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.buckets.count {
    lhs.buckets[i] ^= rhs.buckets[i]
  }
}

public prefix func ~ (x: BitVector) -> BitVector {
  var x = x
  x.flip()
  return x
}
