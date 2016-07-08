//
//  BitArray.swift
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
}

internal struct _PopcountLookupTable {
  static let nibble = [0 as UInt8, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4]
  private init() { }
}

internal extension UInt8 {
  static var _bitWidth: Int { return 32 }

  var _popcount: Int {
    return Int(_PopcountLookupTable.nibble[Int(self >> 4)] +
      _PopcountLookupTable.nibble[Int(self & UInt8(0x0F))])
  }
  var _leadingZeros: Int {
    var v = self, c: Int
    if (v & UInt8(0xF0)) == 0 { c = 4; v <<= 4 } else { c = 0 }
    c += Int(_LeadingZerosLookupTable.nibble[Int(v >> 4)])
    return c
  }
}

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
  public typealias Word = UInt8

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

  internal var _offset: Int = 0

/*
  internal var _firstWordMask: Word? {
    guard _offset > 0 || count > 0 else { return nil }
    return (Word.max >> Word(_offset % BitArray.Word._bitWidth))
  }

  internal var _lastWordMask: Word? {
    guard _offset > 0 || count > 0 else { return nil }
    let remainder =
      (_offset + count + BitArray.Word._bitWidth - 1) % BitArray.Word._bitWidth
    return (Word.max << Word(BitArray.Word._bitWidth - remainder))
  }
*/

  public var count: Int {
    get { return CFBitVectorGetCount(_bitVector) }
    set { CFBitVectorSetCount(_bitVectorCoW, newValue) }
  }

  public var words: [Word] = []

  private var __words: [Word] {
    var v = [Word](
      repeating: 0,
      count: (/* _offset + */ count + BitArray.Word._bitWidth - 1) /
        BitArray.Word._bitWidth
    )
    CFBitVectorGetBits(_bitVector, CFRange(0..<count), &v)
    return v
  }

  public init(words: [Word], count: Int) {
    let bv = CFBitVectorCreate(kCFAllocatorDefault, words, count)
    _bitVector = CFBitVectorCreateMutableCopy(kCFAllocatorDefault, 0, bv)
    self.words = __words
  }

  public init() { }

  public init(repeating repeatedValue: Bit, count: Int) {
    CFBitVectorSetCount(_bitVectorCoW, count)
    CFBitVectorSetAllBits(_bitVectorCoW, repeatedValue.rawValue)
    words = __words
  }

  public subscript(_ position: Int) -> Bit {
    precondition(position >= 0 && position < count)
    return Bit(rawValue: CFBitVectorGetBitAtIndex(_bitVector, position))!
  }

  public subscript(_ bounds: Range<Int>) -> BitArray {
    precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
    var v = [Word](
      repeating: 0,
      count: (bounds.count + BitArray.Word._bitWidth - 1) /
        BitArray.Word._bitWidth
    )
    CFBitVectorGetBits(_bitVector, CFRange(bounds), &v)
    return BitArray(words: v, count: bounds.count)
  }

  public func cardinality(in range: Range<Int>? = nil) -> Int {
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
    words = __words
  }

  public mutating func clear(_ range: ClosedRange<Int>) {
    clear(range.lowerBound..<range.upperBound + 1)
  }

  public mutating func clear(_ index: Int) {
    precondition(index >= 0 && index < count)
    CFBitVectorSetBitAtIndex(_bitVectorCoW, index, 0)
    words = __words
  }

  public mutating func flip(_ range: Range<Int>? = nil) {
    if let range = range {
      precondition(range.lowerBound >= 0 && range.upperBound <= count)
    }
    CFBitVectorFlipBits(_bitVectorCoW, CFRange(range ?? 0..<count))
    words = __words
  }

  public mutating func flip(_ range: ClosedRange<Int>) {
    flip(range.lowerBound..<range.upperBound + 1)
  }

  public mutating func flip(_ index: Int) {
    precondition(index >= 0 && index < count)
    CFBitVectorFlipBitAtIndex(_bitVectorCoW, index)
    words = __words
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
    words = __words
  }

  public mutating func set(_ range: ClosedRange<Int>) {
    set(range.lowerBound..<range.upperBound + 1)
  }

  public mutating func set(_ index: Int) {
    precondition(index >= 0 && index < count)
    CFBitVectorSetBitAtIndex(_bitVectorCoW, index, 1)
    words = __words
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
    return self.reduce("") { $0 + String($1.rawValue) }
  }
}

/*
// MARK: Bitwise operations
public func & (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] &= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

/*
public func &= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] &= rhs.words[i]
  }
}
*/

public func | (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] |= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

/*
public func |= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] |= rhs.words[i]
  }
}
*/

public func ^ (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] ^= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

/*
public func ^= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] ^= rhs.words[i]
  }
}
*/
*/

public prefix func ~ (x: BitArray) -> BitArray {
  var x = x
  x.flip()
  return x
}
