//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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
import FreeType

/// Represents an OpenType `OS/2` table.
public struct OS2Table {
    private var typeface: Typeface?
    private var table: UnsafeMutablePointer<TT_OS2>!

    /// Creates a `OS/2` table representation from the specified typeface.
    ///
    /// - Parameter typeface: The typeface for accessing the data of the table.
    public init?(typeface: Typeface) {
        guard let raw = FT_Get_Sfnt_Table(typeface.ftFace, FT_SFNT_OS2) else {
            return nil
        }

        self.typeface = typeface
        self.table = raw.assumingMemoryBound(to: TT_OS2.self)
    }

    init?(ftFace: FT_Face) {
        guard let raw = FT_Get_Sfnt_Table(ftFace, FT_SFNT_OS2) else {
            return nil
        }

        self.typeface = nil
        self.table = raw.assumingMemoryBound(to: TT_OS2.self)
    }

    public var version: UInt16 {
        return table.pointee.version
    }

    public var xAvgCharWidth: Int16 {
        return table.pointee.xAvgCharWidth
    }

    public var usWeightClass: UInt16 {
        return table.pointee.usWeightClass
    }

    public var usWidthClass: UInt16 {
        return table.pointee.usWidthClass
    }

    public var fsType: UInt16 {
        return table.pointee.fsType
    }

    public var ySubscriptXSize: Int16 {
        return table.pointee.ySubscriptXSize
    }

    public var ySubscriptYSize: Int16 {
        return table.pointee.ySubscriptYSize
    }

    public var ySubscriptXOffset: Int16 {
        return table.pointee.ySubscriptXOffset
    }

    public var ySubscriptYOffset: Int16 {
        return table.pointee.ySubscriptYOffset
    }

    public var ySuperscriptXSize: Int16 {
        return table.pointee.ySuperscriptXSize
    }

    public var ySuperscriptYSize: Int16 {
        return table.pointee.ySuperscriptYSize
    }

    public var ySuperscriptXOffset: Int16 {
        return table.pointee.ySuperscriptXOffset
    }

    public var ySuperscriptYOffset: Int16 {
        return table.pointee.ySuperscriptYOffset
    }

    public var yStrikeoutSize: Int16 {
        return table.pointee.yStrikeoutSize
    }

    public var yStrikeoutPosition: Int16 {
        return table.pointee.yStrikeoutPosition
    }

    public var sFamilyClass: Int16 {
        return table.pointee.sFamilyClass
    }

    public var panose: [UInt8] {
        return withUnsafeBytes(of: &table.pointee.panose) { (pointer) -> [UInt8] in
            return Array(pointer)
        }
    }

    public var ulUnicodeRange1: UInt32 {
        return UInt32(table.pointee.ulUnicodeRange1)
    }

    public var ulUnicodeRange2: UInt32 {
        return UInt32(table.pointee.ulUnicodeRange2)
    }

    public var ulUnicodeRange3: UInt32 {
        return UInt32(table.pointee.ulUnicodeRange3)
    }

    public var ulUnicodeRange4: UInt32 {
        return UInt32(table.pointee.ulUnicodeRange4)
    }

    public var achVendID: Int32 {
        return (
            Int32(table.pointee.achVendID.0 << 24) |
            Int32(table.pointee.achVendID.1 << 16) |
            Int32(table.pointee.achVendID.2 << 8) |
            Int32(table.pointee.achVendID.3)
        )
    }

    public var fsSelection: UInt16 {
        return table.pointee.fsSelection
    }

    public var usFirstCharIndex: UInt16 {
        return table.pointee.usFirstCharIndex
    }

    public var usLastCharIndex: UInt16 {
        return table.pointee.usLastCharIndex
    }

    public var sTypoAscender: Int16 {
        return table.pointee.sTypoAscender
    }

    public var sTypoDescender: Int16 {
        return table.pointee.sTypoDescender
    }

    public var sTypoLineGap: Int16 {
        return table.pointee.sTypoLineGap
    }

    public var usWinAscent: UInt16 {
        return table.pointee.usWinAscent
    }

    public var usWinDescent: UInt16 {
        return table.pointee.usWinDescent
    }

    public var ulCodePageRange1: UInt32 {
        return UInt32(table.pointee.ulCodePageRange1)
    }

    public var ulCodePageRange2: UInt32 {
        return UInt32(table.pointee.ulUnicodeRange2)
    }

    public var sxHeight: Int16 {
        return table.pointee.sxHeight
    }

    public var sCapHeight: Int16 {
        return table.pointee.sCapHeight
    }

    public var usDefaultChar: UInt16 {
        return table.pointee.usDefaultChar
    }

    public var usBreakChar: UInt16 {
        return table.pointee.usBreakChar
    }

    public var usMaxContext: UInt16 {
        return table.pointee.usMaxContext
    }

    public var usLowerOpticalPointSize: UInt16 {
        return table.pointee.usLowerOpticalPointSize
    }

    public var usUpperOpticalPointSize: UInt16 {
        return table.pointee.usUpperOpticalPointSize
    }
}

extension OS2Table {
    enum MacStyle {
        static let bold: UInt16 = 0x01
        static let italic: UInt16 = 0x02
        static let condensed: UInt16 = 0x20
        static let extended: UInt16 = 0x40
    }

    enum FSSelection {
        static let italic: UInt16 = 0x001
        static let wws: UInt16 = 0x100
        static let oblique: UInt16 = 0x200
    }
}
