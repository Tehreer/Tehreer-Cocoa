//
// Copyright (C) 2026 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/// Represents an OpenType `OS/2` table. It reads its fields from the data of the table when they are
/// asked for.
public struct OS2Table: Sendable {
    private let table: SFNTTableReader

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("OS/2") else {
            return nil
        }

        table = SFNTTableReader(data: data, minLength: 100)
    }

    public var version: Int { table.readUInt16(at: 0) }
    public var xAvgCharWidth: Int16 { table.readInt16(at: 2) }
    public var usWeightClass: Int { table.readUInt16(at: 4) }
    public var usWidthClass: Int { table.readUInt16(at: 6) }
    public var fsType: Int { table.readUInt16(at: 8) }
    public var ySubscriptXSize: Int16 { table.readInt16(at: 10) }
    public var ySubscriptYSize: Int16 { table.readInt16(at: 12) }
    public var ySubscriptXOffset: Int16 { table.readInt16(at: 14) }
    public var ySubscriptYOffset: Int16 { table.readInt16(at: 16) }
    public var ySuperscriptXSize: Int16 { table.readInt16(at: 18) }
    public var ySuperscriptYSize: Int16 { table.readInt16(at: 20) }
    public var ySuperscriptXOffset: Int16 { table.readInt16(at: 22) }
    public var ySuperscriptYOffset: Int16 { table.readInt16(at: 24) }
    public var yStrikeoutSize: Int16 { table.readInt16(at: 26) }
    public var yStrikeoutPosition: Int16 { table.readInt16(at: 28) }
    public var sFamilyClass: Int16 { table.readInt16(at: 30) }
    public var ulUnicodeRange1: UInt32 { table.readUInt32(at: 42) }
    public var ulUnicodeRange2: UInt32 { table.readUInt32(at: 46) }
    public var ulUnicodeRange3: UInt32 { table.readUInt32(at: 50) }
    public var ulUnicodeRange4: UInt32 { table.readUInt32(at: 54) }
    public var achVendID: Int32 { table.readInt32(at: 58) }
    public var fsSelection: Int { table.readUInt16(at: 62) }
    public var usFirstCharIndex: Int { table.readUInt16(at: 64) }
    public var usLastCharIndex: Int { table.readUInt16(at: 66) }
    public var sTypoAscender: Int16 { table.readInt16(at: 68) }
    public var sTypoDescender: Int16 { table.readInt16(at: 70) }
    public var sTypoLineGap: Int16 { table.readInt16(at: 72) }
    public var usWinAscent: Int { table.readUInt16(at: 74) }
    public var usWinDescent: Int { table.readUInt16(at: 76) }
    public var ulCodePageRange1: UInt32 { table.readUInt32(at: 78) }
    public var ulCodePageRange2: UInt32 { table.readUInt32(at: 82) }
    public var sxHeight: Int16 { table.readInt16(at: 86) }
    public var sCapHeight: Int16 { table.readInt16(at: 88) }
    public var usDefaultChar: Int { table.readUInt16(at: 90) }
    public var usBreakChar: Int { table.readUInt16(at: 92) }
    public var usMaxContext: Int { table.readUInt16(at: 94) }
    public var usLowerOpticalPointSize: Int { table.readUInt16(at: 96) }
    public var usUpperOpticalPointSize: Int { table.readUInt16(at: 98) }
    public var panose: [UInt8] { table.readBytes(at: 32, count: 10) }
}
