//
//  Sample.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/11/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation

// MARK: Convenience functions
internal extension Data {
  func unsafeValue<T: UnsignedInteger>(at position: Int) -> T {
    return withUnsafeBytes { (ptr: UnsafePointer<Void>) in
      unsafeBitCast(
        ptr.advanced(by: position), to: UnsafePointer<T>.self
      ).pointee
    }
    /*
    return unsafeBitCast(
      bytes.advanced(by: position), to: UnsafePointer<T>.self
    ).pointee
    */
  }
}

internal func _parse(
  keywords str: String, delimitedBy char: Character,
  mergingWith dict: [String : String] = [:],
  forbiddingEmptyValues areEmptyValuesForbidden: Bool = false
) -> [String : String] {
  var elements: [String]
  if areEmptyValuesForbidden {
    let replacement = "\u{fffd}\u{fffd}"
    elements = str
      .replacingOccurrences(of: "\(char)\(char)", with: replacement)
      .components(separatedBy: "\(char)")
      .map { $0.replacingOccurrences(of: replacement, with: "\(char)") }
  } else {
    elements = str.components(separatedBy: "\(char)")
  }
  var dict = dict
  for i in stride(from: 1, to: elements.count, by: 2) {
    let k = elements[i - 1]
      .trimmingCharacters(in: .whitespaces).uppercased()
    let v = elements[i]
      .trimmingCharacters(in: .whitespaces)
    dict[k] = v
  }
  return dict
}

//MARK:
public final class Sample {
  public struct ReadingOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    public static let transform = ReadingOptions(rawValue: 1)
    public static let scaleUsingGain = ReadingOptions(rawValue: 2)
    // public static let scaleToUnitRange = ReadOptions(rawValue: 4)
    public static let forbidEmptyKeywordValues = ReadingOptions(rawValue: 8)
  }

  public let header: [String]
  public let keywords: [String : String]
  public let parameters: [String]
  internal let _rawEvents: [Float]
  public let count: Int
  public internal(set) var events: [String : [Float]] = [:]

  public init(_ sample: Sample) {
    header = sample.header
    keywords = sample.keywords
    parameters = sample.parameters
    _rawEvents = sample._rawEvents
    count = sample.count
    events = sample.events
  }

  public init?(
    _ data: Data, offset: Int = 0, options: ReadingOptions = .transform
  ) {
    // Parse header
    let header = [0, 10, 18, 26, 34, 42, 50].map { i -> String in
      let count = i == 0 ? 6 : 8
      // Note bounds checking
      let subdata = data.subdata(
        in: (offset + i)..<min(offset + i + count, data.count)
      )
      guard let str = String(data: subdata, encoding: .ascii) else { return "" }
      return str.trimmingCharacters(in: .whitespaces)
    }

    // Parse keywords
    let keywords: [String : String]
    do {
      let areEmptyValuesForbidden = options.contains(.forbidEmptyKeywordValues)
      guard
        let begin = Int(header[1]), end = Int(header[2]) where end > begin
        else { return nil }
      // Note bounds checking
      let subdata = data.subdata(
        in: (offset + begin)..<min(offset + end + 1, data.count)
      )
      guard let str = String(data: subdata, encoding: .utf8) else { return nil }
      guard let char = str.characters.first as Character? else { return nil }
      let dict = _parse(
        keywords: String(str.characters.dropFirst()), delimitedBy: char,
        forbiddingEmptyValues: areEmptyValuesForbidden
      )
      // Check for supplemental text
      if let b1 = dict["BEGINSTEXT"], begin1 = Int(b1)
        where begin1 != begin && begin1 != 0,
        let e1 = dict["ENDSTEXT"], end1 = Int(e1)
        where end1 != end && end1 > begin1 {
        // Note bounds checking
        let subdata1 = data.subdata(
          in: (offset + begin1)..<min(offset + end1 + 1, data.count)
        )
        guard let str1 = String(
          data: subdata1, encoding: .utf8
        ) else { return nil }
        keywords = _parse(
          keywords: str1, delimitedBy: char, mergingWith: dict,
          forbiddingEmptyValues: areEmptyValuesForbidden
        )
      } else {
        keywords = dict
      }
    }

    // Determine number and names of parameters
    guard
      let p = keywords["$PAR"], par = Int(p) where par > 0
      else { return nil }
    let parameters = (1...par).map { i -> String in
      guard let parameter = keywords["$P\(i)N"] else { return "" }
      return parameter
    }

    // Determine event count
    guard
      let t = keywords["$TOT"], tot = Int(t) where tot > 0
      else { return nil }

    // Determine byte order
    guard let bo = keywords["$BYTEORD"] else { return nil }
    var byteOrder: CFByteOrder
    switch bo {
    case "4,3,2,1", "2,1":
      byteOrder = CFByteOrder(CFByteOrderBigEndian.rawValue)
    case "1,2,3,4", "1,2":
      byteOrder = CFByteOrder(CFByteOrderLittleEndian.rawValue)
    default:
      return nil
    }
    let hostByteOrder = CFByteOrderGetCurrent()
    guard
      hostByteOrder != CFByteOrder(CFByteOrderUnknown.rawValue)
      else { return nil }
    let isSwapped = byteOrder != hostByteOrder

    // Parse events; for consistency, store processed event data as [Float]
    // regardless of input data type
    var rawEvents: [Float]
    do {
      guard
        let mode = keywords["$MODE"]?.uppercased() where mode == "L"
        else { return nil }
      let begin: Int
      if let begin1 = Int(header[3]) where begin1 > 0 {
        begin = begin1
      } else {
        guard
          let bd = keywords["$BEGINDATA"], begin2 = Int(bd) where begin2 > 0
          else { return nil }
        begin = begin2
      }
      let end: Int
      if let end1 = Int(header[4]) where end1 >= begin {
        end = end1
      } else {
        guard
          let ed = keywords["$ENDDATA"], end2 = Int(ed) where end2 >= begin
          else { return nil }
        end = end2
      }
      // Note bounds checking
      let subdata = data.subdata(
        in: (offset + begin)..<min(offset + end + 1, data.count)
      )
      guard
        let dataType = keywords["$DATATYPE"]?.uppercased()
        else { return nil }
      switch dataType {
      case "D":
        let size = strideof(Double)
        rawEvents = [Float](repeating: Float.nan, count: subdata.count / size)
        if byteOrder == CFByteOrder(CFByteOrderBigEndian.rawValue) {
          for i in stride(from: 0, to: subdata.count - size + 1, by: size) {
            rawEvents[i / size] = Float(NSSwapBigDoubleToHost(
              NSSwappedDouble(v: subdata.unsafeValue(at: i))
            ))
          }
        } else {
          for i in stride(from: 0, to: subdata.count - size + 1, by: size) {
            rawEvents[i / size] = Float(NSSwapLittleDoubleToHost(
              NSSwappedDouble(v: subdata.unsafeValue(at: i))
            ))
          }
        }
      case "F":
        let size = strideof(Float)
        rawEvents = [Float](repeating: Float.nan, count: subdata.count / size)
        if byteOrder == CFByteOrder(CFByteOrderBigEndian.rawValue) {
          for i in stride(from: 0, to: subdata.count - size + 1, by: size) {
            rawEvents[i / size] = NSSwapBigFloatToHost(
              NSSwappedFloat(v: subdata.unsafeValue(at: i))
            )
          }
        } else {
          for i in stride(from: 0, to: subdata.count - size + 1, by: size) {
            rawEvents[i / size] = NSSwapLittleFloatToHost(
              NSSwappedFloat(v: subdata.unsafeValue(at: i))
            )
          }
        }
      case "I":
        let adjustBitwidth: Bool
        if let sys = keywords["$SYS"]?.uppercased()
          where sys == "CXP" || sys == "CPX" {
          adjustBitwidth = true
        } else {
          adjustBitwidth = false
        }
        let bitwidths: [Int] = (1...par).map {
          guard
            let bw = keywords["$P\($0)B"], bitwidth = Int(bw)
            else { return 0 }
          if [64, 32, 16, 8].contains(bitwidth) { return bitwidth }
          return (bitwidth == 10 && adjustBitwidth) ? 16 : 0
        }
        if bitwidths.contains(0) { return nil }
        let bytelengths = bitwidths.map { $0 / 8 }

        // Populate an array that gives the position of the nth parameter
        // relative to the position of the first parameter for that event
        let positions = (0...par - 1).map {
          bytelengths[0..<$0].reduce(0) { $0 + $1 }
          // Note that we are deliberating using a subarray with count ($0 - 1)
          // so that (outside this closure) positions[0] = 0
        }
        let ranges: [Int] = (1...par).map {
          // Don't mask anything if required value is missing
          guard
            let ra = keywords["$P\($0)R"], range = Int(ra)
            else { return 1 << bitwidths[$0 - 1] }
          return range
        }
        let bitmasks = ranges.map { 1 << UInt64(ceil(log2(Double($0)))) }

        let isTransformEnabled = options.contains(.transform)
        let transforms = (1...par).map { i -> (Float, Float) in
          // Assume linear if required value is missing
          guard let e = keywords["$P\(i)E"] else { return (0, 0) }
          let arr = e.components(separatedBy: ",").map {
            Float($0.trimmingCharacters(in: .whitespaces))
          }
          guard
            arr.count >= 2,
            let f1 = arr[0], f2 = arr[1] where !f1.isNaN && !f2.isNaN
            else { return (0, 0) }
          // Special handling for common error (explained in FCS specification)
          if f1 > 0 && f2 == 0 { return (f1, 1) }
          return (f1, f2)
        }

        let isScaleUsingGainEnabled = options.contains(.scaleUsingGain)
        let scales: [Float] = (1...par).map {
          // Assume no scaling if optional value is missing
          guard
            let g = keywords["$P\($0)G"], gain = Float(g) where !gain.isNaN
            else { return 1 }
          return gain
        }

        // `positions.last` and `bytelengths.last` should never be nil
        let bytesPerEvent = positions.last! + bytelengths.last!
        rawEvents = [Float](
          repeating: Float.nan, count: subdata.count / bytesPerEvent * par
        )
        for i in stride(
          from: 0, to: subdata.count - bytesPerEvent + 1, by: bytesPerEvent
        ) {
          inner: for j in 0..<par {
            let position = i + positions[j]
            let v: UInt64
            switch bytelengths[j] {
            case 64:
              v = UInt64(isSwapped ?
                (subdata.unsafeValue(at: position) as UInt64).byteSwapped :
                (subdata.unsafeValue(at: position) as UInt64))
            case 32:
              v = UInt64(isSwapped ?
                (subdata.unsafeValue(at: position) as UInt32).byteSwapped :
                (subdata.unsafeValue(at: position) as UInt32))
            case 16:
              v = UInt64(isSwapped ?
                (subdata.unsafeValue(at: position) as UInt16).byteSwapped :
                (subdata.unsafeValue(at: position) as UInt16))
            case 8:
              v = UInt64(subdata.unsafeValue(at: position) as UInt8)
            default:
              continue inner
            }
            var floatValue = Float(v > bitmasks[j] ? v % bitmasks[j] : v)
            let t = transforms[j]
            if isTransformEnabled && t.0 != 0 {
              let range = ranges[j]
              floatValue = __exp10f(t.0 * floatValue / Float(range)) * t.1
            } else if isScaleUsingGainEnabled && t.0 == 0 {
              floatValue /= scales[j]
            }
            let index = i / bytesPerEvent * par + j
            rawEvents[index] = floatValue
          }
        }
      case "A":
        //TODO: Implement support for ASCII data type
        return nil
      default:
        return nil
      }
    }

    let count = rawEvents.count / parameters.count
    //TODO: Log warning if `count != tot`

    self.header = header
    self.keywords = keywords
    self.parameters = parameters
    self._rawEvents = rawEvents
    self.count = count

    //TODO: Parse acquisition compensation matrix
    //      and compensate before populating `events`
  }
}
