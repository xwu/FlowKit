//
//  Sample.swift
//  FlowKit
//
//  Created by Xiaodi Wu on 6/11/16.
//  Copyright © 2016 Xiaodi Wu. All rights reserved.
//

import Foundation
import Accelerate

// MARK: Convenience functions
internal extension Data {
  func unsafeValue<T: UnsignedInteger>(at position: Int) -> T {
    return withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
      return UnsafeRawPointer(ptr).load(fromByteOffset: position, as: T.self)
    }
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

// MARK: -

/**
  A flow cytometry data set in an FCS data file.

  You can initialize a `Sample` object with an existing instance or FCS data.
  Note that event data cannot be accessed unless compensation has been applied.
  By default, each sample is compensated using its acquisition matrix upon
  initialization with FCS data. You can disable this behavior by specifying
  custom reading options.

  ```
  let control = Sample(x) // Assuming `x` is an instance of `Data`.
  let transform = LinearTransform()!
  transform.scale(control, dimensions: ["FSC-A"])
  let values = control.events["FSC-A"]!
  ```

  - Note: Only list mode data sets not stored as ASCII text are supported. See
    documentation for the `Sample.keyword` property for information on other
    keyword requirements for correct parsing.
*/
public final class Sample {
  /// Options for creating a `Sample` object from FCS data.
  public struct ReadingOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    /**
      Causes integer data to be scaled using an anti-logarithmic transform based
      on values given in $P\[_n_\]E keywords.
    */
    public static let transform = ReadingOptions(rawValue: 1)

    /**
      Causes integer, non-logarithmic data to be scaled to account for the gain
      used to amplify the signal, based on values given in $P\[_n_\]G keywords.
    */
    public static let scaleUsingGain = ReadingOptions(rawValue: 2)

    // public static let scaleToUnitRange = ReadingOptions(rawValue: 4)

    /**
      Causes keyword values to be parsed strictly in accordance with the FCS3.1
      standard, which stipulates that keyword values cannot be empty (i.e., "")
      and that two consecutive delimiter characters (e.g., "//" if the delimiter
      character is "/") are an escape sequence.
    */
    public static let forbidEmptyKeywordValues = ReadingOptions(rawValue: 8)

    /**
      Causes parsed event data to be compensated using the sample's acquisition
      matrix, if one can be found.
    */
    public static let compensateUsingAcquisitionMatrix =
      ReadingOptions(rawValue: 16)
  }

  /**
    The HEADER segment of the data set, comprising: (1) a version identifier
    string (e.g., "FCS3.1"); and (2) three pairs of strings indicating byte
    offsets for the first and last (not one-past-the-end) byte of the primary
    TEXT segment, DATA segment, and ANALYSIS segment of the data set.

    - Note: Offsets for any user-defined OTHER segments are not parsed.
  */
  public let header: [String]

  /**
    The keywords (key-value pairs) stored in the primary and supplemental TEXT
    segments of the data set. Keys beginning with "$" are defined in the FCS
    standard, while others are user-defined.

    For correct parsing of event data, at minimum, the following keywords must
    be defined in the data set:

    * $MODE---Data mode. Only list mode ("L") is supported.
    * $DATATYPE---Type of data stored in the DATA segment. Only integer ("I")
      and floating point ("D" and "F") types are supported.
    * $BYTEORD---Byte order for data. Only little endian ("1,2,3,4" or "1,2")
      and big endian ("4,3,2,1" or "2,1") byte orders are supported (and not,
      for example, "1,3,2,4").
    * $PAR---Number of parameters in an event.
    * $TOT---Total number of events in the data set.
    * $P\[_n_\]N---Short name for parameter _n_.

    - Note: For integer data, keywords $P\[_n_\]B (number of bits reserved for
      parameter _n_) must also be defined and must be 8, 16, 32, or 64.
  */
  public let keywords: [String : String]

  /**
    Parameter short names, given by keywords $P\[_n_\]N, in ascending order of
    their parameter number _n_.

    Since Swift arrays are zero-based, `parameters[0] == keywords["$P1N"]!`. The
    corresponding (optional) long name would be expressed as `keywords["$P1S"]`.
  */
  public let parameters: [String]
  internal let _rawEvents: [Float]

  /**
    The total number of parsed events in the data set. If
    `count != Int(keywords["$TOT"]!)!`, then the data may have been prematurely
    truncated in a corrupted file.
  */
  public let count: Int

  /**
    The parsed and compensated event data, before or after transforms have been
    applied. Data are separated by parameter and keyed to parameter short names
    or, after compensation using a Gating-ML–defined matrix, fluorochrome names.
  */
  public internal(set) var events: [String : [Float]] = [:]

  /// Initialize a new `Sample` from the given `Sample`.
  public init(_ sample: Sample) {
    header = sample.header
    keywords = sample.keywords
    parameters = sample.parameters
    _rawEvents = sample._rawEvents
    count = sample.count
    events = sample.events
  }

  // For testing purposes only
  internal init(_ sample: Sample, _times n: Int) {
    header = sample.header
    keywords = sample.keywords
    parameters = sample.parameters

    var r = sample._rawEvents
    var e = sample.events
    r.reserveCapacity(sample._rawEvents.count * n)
    for k in e.keys {
      e[k]!.reserveCapacity(sample.count * n)
    }
    for _ in 1..<n {
      r.append(contentsOf: sample._rawEvents)
      for k in e.keys {
        e[k]!.append(contentsOf: sample.events[k]!)
      }
    }

    _rawEvents = r
    count = sample.count * n
    events = e
  }

  /**
    Initialize a new `Sample` by parsing the given data.

    - Parameter data: The data to be parsed.
    - Parameter offset: The byte offset from which to begin parsing the given
      data. This parameter would need to be non-zero when parsing a data set
      other than the first in a file containing more than one data set.
    - Parameter options: Options for parsing the given data.
  */
  public init?(
    _ data: Data, offset: Int = 0,
    options: ReadingOptions = [.transform, .compensateUsingAcquisitionMatrix]
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
        let begin = Int(header[1]), let end = Int(header[2]), end > begin
        else { return nil }
      // Note bounds checking
      let subdata = data.subdata(
        in: (offset + begin)..<min(offset + end + 1, data.count)
      )
      guard let str = String(data: subdata, encoding: .utf8) else { return nil }
#if swift(>=4.1)
      guard let char = str.first else { return nil }
      let dict = _parse(
        keywords: String(str.dropFirst()), delimitedBy: char,
        forbiddingEmptyValues: areEmptyValuesForbidden
      )
#else
      guard let char = str.characters.first as Character? else { return nil }
      let dict = _parse(
        keywords: String(str.characters.dropFirst()), delimitedBy: char,
        forbiddingEmptyValues: areEmptyValuesForbidden
      )
#endif
      // Check for supplemental text
      if let b1 = dict["BEGINSTEXT"], let begin1 = Int(b1),
        begin1 != begin && begin1 != 0,
        let e1 = dict["ENDSTEXT"], let end1 = Int(e1),
        end1 != end && end1 > begin1 {
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
      let p = keywords["$PAR"], let par = Int(p), par > 0
      else { return nil }
    let parameters = (1...par).map { i -> String in
      guard let parameter = keywords["$P\(i)N"] else { return "" }
      return parameter
    }

    // Determine event count
    guard
      let t = keywords["$TOT"], let tot = Int(t), tot > 0
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
        let mode = keywords["$MODE"]?.uppercased(), mode == "L"
        else { return nil }
      let begin: Int
      if let begin1 = Int(header[3]), begin1 > 0 {
        begin = begin1
      } else {
        guard
          let bd = keywords["$BEGINDATA"], let begin2 = Int(bd), begin2 > 0
          else { return nil }
        begin = begin2
      }
      let end: Int
      if let end1 = Int(header[4]), end1 >= begin {
        end = end1
      } else {
        guard
          let ed = keywords["$ENDDATA"], let end2 = Int(ed), end2 >= begin
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
        let size = MemoryLayout<Double>.stride
        rawEvents = [Float](repeating: Float.nan, count: subdata.count / size)
        //FIXME: We assume that endianness for floating point and integer types
        //       are the same, which is a safe assumption for most modern
        //       systems but is not guaranteed for all systems
        if !isSwapped {
          subdata.withUnsafeBytes { (ptr: UnsafePointer<Double>) in
            vDSP_vdpsp(ptr, 1, &rawEvents, 1, UInt(rawEvents.count))
          }
        } else if byteOrder == CFByteOrder(CFByteOrderBigEndian.rawValue) {
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
        let size = MemoryLayout<Float>.stride
        rawEvents = [Float](repeating: Float.nan, count: subdata.count / size)
        //FIXME: We assume that endianness for floating point and integer types
        //       are the same, which is a safe assumption for most modern
        //       systems but is not guaranteed for all systems
        if !isSwapped {
          subdata.withUnsafeBytes { (ptr: UnsafePointer<Float>) in
            cblas_scopy(Int32(rawEvents.count), ptr, 1, &rawEvents, 1)
          }
        } else if byteOrder == CFByteOrder(CFByteOrderBigEndian.rawValue) {
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
        let adjustBitWidth: Bool
        if let sys = keywords["$SYS"]?.uppercased(),
          sys == "CXP" || sys == "CPX" {
          adjustBitWidth = true
        } else {
          adjustBitWidth = false
        }
        let bitWidths: [Int] = (1...par).map {
          guard
            let bw = keywords["$P\($0)B"], let bitWidth = Int(bw)
            else { return 0 }
          if [64, 32, 16, 8].contains(bitWidth) { return bitWidth }
          return (bitWidth == 10 && adjustBitWidth) ? 16 : 0
        }
        if bitWidths.contains(0) { return nil }
        let bytelengths = bitWidths.map { $0 / 8 }

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
            let ra = keywords["$P\($0)R"], let range = Int(ra)
            else { return 1 << bitWidths[$0 - 1] }
          return range
        }
        let bitmasks = ranges.map {
          (1 as UInt64) << UInt64(ceil(log2(Double($0))))
        }

        let isTransformEnabled = options.contains(.transform)
        let transforms = (1...par).map { i -> (Float, Float) in
          // Assume linear if required value is missing
          guard let e = keywords["$P\(i)E"] else { return (0, 0) }
          let arr = e.components(separatedBy: ",").map {
            Float($0.trimmingCharacters(in: .whitespaces))
          }
          guard
            arr.count >= 2,
            let f1 = arr[0], let f2 = arr[1], !f1.isNaN && !f2.isNaN
            else { return (0, 0) }
          // Special handling for common error (explained in FCS specification)
          if f1 > 0 && f2 == 0 { return (f1, 1) }
          return (f1, f2)
        }

        let isScaleUsingGainEnabled = options.contains(.scaleUsingGain)
        let scales: [Float] = (1...par).map {
          // Assume no scaling if optional value is missing
          guard
            let g = keywords["$P\($0)G"], let gain = Float(g), !gain.isNaN
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
    _rawEvents = rawEvents
    self.count = count

    if options.contains(.compensateUsingAcquisitionMatrix),
      let compensation = Compensation(self) {
      compensation.unmix(self)
    }
  }
}
