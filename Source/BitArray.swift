//
//  BitArray.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 7/3/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

internal extension CFRange {
  init(_ range: Range<Int>) {
    location = range.lowerBound
    length = range.count
  }
}

public enum Bit : CFBit {
  case zero = 0, one
}

internal final class _BitVectorBox {
  internal var value: CFMutableBitVector
  internal init(_ value: CFMutableBitVector) {
    self.value = value
  }
}

public struct BitArray {
  internal var _bits: [UInt8] {
    var v = [UInt8](repeating: 0, count: (count + 7) / 8)
    CFBitVectorGetBits(_bitVector, CFRange(0..<count), &v)
    return v
  }

  // Copy-on-write
  internal var _bitVectorBox: _BitVectorBox = {
    return _BitVectorBox(CFBitVectorCreateMutable(kCFAllocatorDefault, 0))
  }()

  internal var _bitVector: CFMutableBitVector {
    get { return _bitVectorBox.value }
    set { _bitVectorBox = _BitVectorBox(newValue) }
  }

  internal var _bitVectorCoW: CFMutableBitVector {
    mutating get {
      if !isUniquelyReferencedNonObjC(&_bitVectorBox) {
        _bitVector = CFBitVectorCreateMutableCopy(
          kCFAllocatorDefault, 0, _bitVector
        )
      }
      return _bitVector
    }
  }

  public var count: Int {
    get { return CFBitVectorGetCount(_bitVector) }
    set { CFBitVectorSetCount(_bitVectorCoW, newValue) }
  }

  internal init(_bits: [UInt8], count: Int) {
    let bv = CFBitVectorCreate(kCFAllocatorDefault, _bits, count)
    _bitVector = CFBitVectorCreateMutableCopy(kCFAllocatorDefault, 0, bv)
  }

  public init() { }

  public init(repeating repeatedValue: Bit, count: Int) {
    CFBitVectorSetCount(_bitVectorCoW, count)
    CFBitVectorSetAllBits(_bitVectorCoW, repeatedValue.rawValue)
  }

  public subscript(_ position: Int) -> Bit {
    get {
      precondition(position >= 0 && position < count)
      return Bit(rawValue: CFBitVectorGetBitAtIndex(_bitVector, position))!
    }
    set {
      precondition(position >= 0 && position < count)
      CFBitVectorSetBitAtIndex(_bitVectorCoW, position, newValue.rawValue)
    }
  }

  public subscript(_ bounds: Range<Int>) -> BitArray {
    precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
    var v = [UInt8](repeating: 0, count: (bounds.count + 7) / 8)
    CFBitVectorGetBits(_bitVector, CFRange(bounds), &v)
    return BitArray(_bits: v, count: bounds.count)
  }

  public func cardinality(in range: Range<Int>?) -> Int {
    return CFBitVectorGetCountOfBit(_bitVector, CFRange(range ?? 0..<count), 1)
  }

  public func contains(_ bit: Bit, in range: Range<Int>) -> Bool {
    return CFBitVectorContainsBit(_bitVector, CFRange(range), bit.rawValue)
  }

  public func index(of bit: Bit, in range: Range<Int>) -> Int? {
    let v = CFBitVectorGetFirstIndexOfBit(
      _bitVector, CFRange(range), bit.rawValue
    )
    return v == kCFNotFound ? nil : v
  }

  public func lastIndex(of bit: Bit, in range: Range<Int>) -> Int? {
    let v = CFBitVectorGetLastIndexOfBit(
      _bitVector, CFRange(range), bit.rawValue
    )
    return v == kCFNotFound ? nil : v
  }

  public mutating func clear(_ range: Range<Int>? = nil) {
    if let range = range {
      precondition(range.lowerBound >= 0 && range.upperBound <= count)
      CFBitVectorSetBits(
        _bitVectorCoW, CFRange(
          location: range.lowerBound, length: range.count
        ), 0
      )
    } else {
      CFBitVectorSetAllBits(_bitVectorCoW, 0)
    }
  }

  public mutating func clear(_ index: Int) {
    self[index] = .zero
  }

  public mutating func flip(_ range: Range<Int>? = nil) {
    if let range = range {
      precondition(range.lowerBound >= 0 && range.upperBound <= count)
    }
    CFBitVectorFlipBits(_bitVectorCoW, CFRange(range ?? 0..<count))
  }

  public mutating func flip(_ index: Int) {
    precondition(index >= 0 && index < count)
    CFBitVectorFlipBitAtIndex(_bitVectorCoW, index)
  }

  public mutating func set(_ range: Range<Int>? = nil) {
    if let range = range {
      precondition(range.lowerBound >= 0 && range.upperBound <= count)
      CFBitVectorSetBits(
        _bitVectorCoW, CFRange(
          location: range.lowerBound, length: range.count
        ), 1
      )
    } else {
      CFBitVectorSetAllBits(_bitVectorCoW, 1)
    }
  }

  public mutating func set(_ index: Int) {
    self[index] = .one
  }
}

extension BitArray : Collection {
  public var endIndex: Int { return count }
  public var startIndex: Int { return 0 }

  public func index(after i: Int) -> Int {
    return i + 1
  }

  public func formIndex(after i: inout Int) {
    i += 1
  }

  public func contains(_ bit: Bit) -> Bool {
    return contains(bit, in: 0..<count)
  }

  //TODO: Implement a more efficient `elementsEqual`

  public func index(of bit: Bit) -> Int? {
    return index(of: bit, in: 0..<count)
  }

  public func lastIndex(of bit: Bit) -> Int? {
    return lastIndex(of: bit, in: 0..<count)
  }
}

extension BitArray : CustomStringConvertible {
  public var description: String {
    return self.reduce("") { $0 + "\($1.rawValue)" }
  }
}

// MARK: Bitwise operations
public func & (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs._bits
  let r = rhs._bits
  for i in 0..<l.count {
    l[i] &= r[i]
  }
  return BitArray(_bits: l, count: lhs.count)
}

public func | (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs._bits
  let r = rhs._bits
  for i in 0..<l.count {
    l[i] |= r[i]
  }
  return BitArray(_bits: l, count: lhs.count)
}

public func ^ (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs._bits
  let r = rhs._bits
  for i in 0..<l.count {
    l[i] ^= r[i]
  }
  return BitArray(_bits: l, count: lhs.count)
}

public prefix func ~ (x: BitArray) -> BitArray {
  var x = x
  x.flip()
  return x
}
