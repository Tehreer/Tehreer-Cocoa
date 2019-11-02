//
// Copyright (C) 2019 Muhammad Tayyab Akram
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

/// Represents an OpenType `head` table.
public struct HeadTable {
    private let typeface: Typeface
    private let table: UnsafeMutablePointer<TT_Header>

    /// Creates a `head` table representation from the specified typeface.
    ///
    /// - Parameter typeface: The typeface for accessing the data of the table.
    public init?(typeface: Typeface) {
        let pointer = FT_Get_Sfnt_Table(typeface.ftFace, FT_SFNT_HEAD)
        guard let raw = pointer else {
            return nil
        }

        self.typeface = typeface
        self.table = raw.assumingMemoryBound(to: TT_Header.self)
    }

    public var version: Int32 {
        return Int32(table.pointee.Table_Version)
    }

    public var fontRevision: Int32 {
        return Int32(table.pointee.Font_Revision)
    }

    public var checkSumAdjustment: UInt32 {
        return UInt32(table.pointee.CheckSum_Adjust)
    }

    public var magicNumber: UInt32 {
        return UInt32(table.pointee.Magic_Number)
    }

    public var flags: UInt16 {
        return table.pointee.Flags
    }

    public var unitsPerEm: UInt16 {
        return table.pointee.Units_Per_EM
    }

    public var created: Int64 {
        return (Int64(table.pointee.Created.0) << 32) | Int64(table.pointee.Created.1)
    }

    public var modified: Int64 {
        return (Int64(table.pointee.Modified.0) << 32) | Int64(table.pointee.Modified.1)
    }

    public var xMin: Int16 {
        return table.pointee.xMin
    }

    public var yMin: Int16 {
        return table.pointee.yMin
    }

    public var xMax: Int16 {
        return table.pointee.xMax
    }

    public var yMax: Int16 {
        return table.pointee.yMax
    }

    public var macStyle: UInt16 {
        return table.pointee.Mac_Style
    }

    public var lowestRecPPEM: UInt16 {
        return table.pointee.Lowest_Rec_PPEM
    }

    public var fontDirectionHint: Int16 {
        return table.pointee.Font_Direction
    }

    public var indexToLocFormat: Int16 {
        return table.pointee.Index_To_Loc_Format
    }

    public var glyphDataFormat: Int16 {
        return table.pointee.Glyph_Data_Format
    }
}
