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

public enum Bit : UInt8 {
  case zero = 0, one
}

public struct BitArray {
  internal enum _Mutation {
    case set, clear, flip
  }
  public typealias Word = UInt32

  internal let _offset: Int
  public let count: Int
  // Note: various methods below assume that `words` has only the minimum number
  //       of elements necessary for storing `count` bits prefixed by `_offset`
  //       (zero) bits
  public internal(set) var words: [Word] = []

  internal init(_words: [Word], offset: Int, count: Int) {
    precondition(offset >= 0 && count >= 0)
    let bitOffset = offset % Word._bitWidth
    _offset = bitOffset
    self.count = count
    let wordOffset = offset / Word._bitWidth
    let i = _words.count - wordOffset
    // Note: if `offset >= _words.count * Word._bitWidth`, then `i <= 0`
    let f = (bitOffset + count + Word._bitWidth - 1) / Word._bitWidth
    if f < i {
      words = [Word](_words.dropFirst(wordOffset).prefix(f))
    } else if f == i {
      words = wordOffset == 0 ? _words : [Word](_words.dropFirst(wordOffset))
    } else {
      words = [Word](repeating: 0, count: f)
      if i > 0 {
        words.replaceSubrange(0..<i, with: _words[wordOffset..<_words.count])
      }
    }
    assert(words.count == f)
    _maskFirstWordFragment()
    _maskLastWordFragment()
  }

  public init(words: [Word], count: Int) {
    precondition(count >= 0)
    _offset = 0
    self.count = count
    let i = words.count
    let f = (count + Word._bitWidth - 1) / Word._bitWidth
    if f < i {
      self.words = [Word](words.prefix(f))
    } else if f == i {
      self.words = words
    } else {
      self.words = [Word](repeating: 0, count: f)
      self.words.replaceSubrange(0..<i, with: words)
    }
    assert(self.words.count == f)
    _maskLastWordFragment()
  }

  public init(repeating repeatedValue: Bit = .zero, count: Int) {
    precondition(count >= 0)
    _offset = 0
    self.count = count
    let wc = (count + Word._bitWidth - 1) / Word._bitWidth
    let rv = repeatedValue == .zero ? 0 : Word.max
    self.words = [Word](repeating: rv, count: wc)
    _maskLastWordFragment()
  }

  public subscript(_ position: Int) -> Bit {
    let bitOffset = (_offset + position) % Word._bitWidth
    let mask = 1 << Word(Word._bitWidth - bitOffset - 1)
    let wordOffset = (_offset + position) / Word._bitWidth
    let isZero = (words[wordOffset] & mask) == 0
    return isZero ? .zero : .one
  }

  public subscript(_ bounds: Range<Int>) -> BitArray {
    precondition(bounds.lowerBound >= 0 && bounds.upperBound <= count)
    return BitArray(
      _words: words, offset: _offset + bounds.lowerBound, count: bounds.count
    )
  }

  // Note: various methods below assume bits preceding `_offset` are zero; thus,
  //       it is critical to call this method after `words` is populated
  internal mutating func _maskFirstWordFragment() {
    guard _offset > 0 else { return }
    let mask = Word.max >> Word(_offset)
    if let first = words.first where first != (first & mask) {
      words[0] = (first & mask)
    }
  }

  // Note: various methods below assume bits past `_offset + count` are zero;
  //       thus, it is critical to call this method after `words` is populated
  internal mutating func _maskLastWordFragment() {
    let remainder = (_offset + count) % Word._bitWidth
    let shift = (Word._bitWidth - remainder) % Word._bitWidth
    let mask = Word.max << Word(shift)
    if let last = words.last where last != (last & mask) {
      words[words.endIndex - 1] = (last & mask)
    }
  }

  internal mutating func _execute(
    _ mutation: _Mutation, over range: Range<Int>? = nil
    ) {
    let range = range ?? 0..<count
    guard range.count > 0 else { return }

    let a = (_offset + range.lowerBound) / Word._bitWidth
    let b = (_offset + range.upperBound + Word._bitWidth - 1) / Word._bitWidth
    let firstMask =
      Word.max >> Word((_offset + range.lowerBound) % Word._bitWidth)
    let lastMask =
      Word.max << Word((
        Word._bitWidth - ((_offset + range.upperBound) % Word._bitWidth)
        ) % Word._bitWidth)

    if b - a == 1 {
      let mask = firstMask & lastMask
      switch mutation {
      case .set:
        words[a] |= mask
      case .clear:
        words[a] &= ~mask
      case .flip:
        words[a] = (words[a] & ~mask) | (~words[a] & mask)
      }
      return
    }

    let indices = (a + 1)..<(b - 1)
    switch mutation {
    case .set:
      words[a] |= firstMask
      for i in indices { words[i] = Word.max }
      words[b - 1] |= lastMask
    case .clear:
      words[a] &= ~firstMask
      for i in indices { words[i] = 0 }
      words[b - 1] &= ~lastMask
    case .flip:
      words[a] = (words[a] & ~firstMask) | (~words[a] & firstMask)
      for i in indices { words[i] = ~words[i] }
      words[b - 1] = (words[b - 1] & ~lastMask) | (~words[b - 1] & lastMask)
    }
  }

  internal mutating func _execute(_ mutation: _Mutation, at index: Int) {
    let bitOffset = (_offset + index) % Word._bitWidth
    let mask = 1 << Word(Word._bitWidth - bitOffset - 1)
    let wordOffset = (_offset + index) / Word._bitWidth
    switch mutation {
    case .set:
      words[wordOffset] |= mask
    case .clear:
      words[wordOffset] &= ~mask
    case .flip:
      words[wordOffset] =
        (words[wordOffset] & ~mask) | (~words[wordOffset] & mask)
    }
  }

  public func cardinality() -> Int {
    var v = 0
    for w in words {
      v += w._popcount
    }
    return v
  }

  public func contains(_ bit: Bit) -> Bool {
    return cardinality() != ((bit == .zero) ? count : 0)
  }

  public func index(of bit: Bit) -> Int? {
    var v = -_offset
    switch bit {
    case .zero:
      if let w = words.first {
        let clz = (~w & (Word.max >> Word(_offset)))._leadingZeros
        v += clz
        if clz < Word._bitWidth {
          return v < count ? v : nil
        }
      }
      for w in words.dropFirst() {
        let clz = (~w)._leadingZeros
        v += clz
        if clz < Word._bitWidth {
          return v < count ? v : nil
        }
      }
    case .one:
      for w in words {
        let clz = w._leadingZeros
        v += clz
        if clz < Word._bitWidth {
          return v
        }
      }
    }
    return nil
  }

  public func lastIndex(of bit: Bit) -> Int? {
    let remainder = (_offset + count) % Word._bitWidth
    let shift = (Word._bitWidth - remainder) % Word._bitWidth
    var v = count + shift - 1
    switch bit {
    case .zero:
      if let w = words.last {
        let ctz = (~w & (Word.max << Word(shift)))._trailingZeros
        v -= ctz
        if ctz < Word._bitWidth {
          return v >= 0 ? v : nil
        }
      }
      for w in words.dropLast().reversed() {
        let ctz = (~w)._trailingZeros
        v -= ctz
        if ctz < Word._bitWidth {
          return v >= 0 ? v : nil
        }
      }
    case .one:
      for w in words.reversed() {
        let ctz = w._trailingZeros
        v -= ctz
        if ctz < Word._bitWidth {
          return v
        }
      }
    }
    return nil
  }

  public mutating func set(_ range: Range<Int>? = nil) {
    _execute(.set, over: range)
  }

  public mutating func set(_ range: ClosedRange<Int>) {
    _execute(.set, over: range.lowerBound..<range.upperBound + 1)
  }

  public mutating func set(_ index: Int) {
    _execute(.set, at: index)
  }

  public mutating func clear(_ range: Range<Int>? = nil) {
    _execute(.clear, over: range)
  }

  public mutating func clear(_ range: ClosedRange<Int>) {
    _execute(.clear, over: range.lowerBound..<range.upperBound + 1)
  }

  public mutating func clear(_ index: Int) {
    _execute(.clear, at: index)
  }

  public mutating func flip(_ range: Range<Int>? = nil) {
    _execute(.flip, over: range)
  }

  public mutating func flip(_ range: ClosedRange<Int>) {
    _execute(.flip, over: range.lowerBound..<range.upperBound + 1)
  }

  public mutating func flip(_ index: Int) {
    _execute(.flip, at: index)
  }
}

extension BitArray : BidirectionalCollection {
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

  //TODO: Implement a more efficient `elementsEqual`
}

extension BitArray : CustomStringConvertible {
  public var description: String {
    return self.reduce("") { $0 + String($1.rawValue) }
  }
}


// MARK: Bitwise operations
public func & (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] &= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

public func &= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] &= rhs.words[i]
  }
}

public func | (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] |= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

public func |= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] |= rhs.words[i]
  }
}

public func ^ (lhs: BitArray, rhs: BitArray) -> BitArray {
  precondition(lhs.count == rhs.count)
  var l = lhs.words
  for i in 0..<l.count {
    l[i] ^= rhs.words[i]
  }
  return BitArray(words: l, count: lhs.count)
}

public func ^= (lhs: inout BitArray, rhs: BitArray) {
  precondition(lhs.count == rhs.count)
  for i in 0..<lhs.words.count {
    lhs.words[i] ^= rhs.words[i]
  }
}

public prefix func ~ (x: BitArray) -> BitArray {
  var x = x
  x.flip()
  return x
}
