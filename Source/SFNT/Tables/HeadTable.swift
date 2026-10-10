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

/// Represents an OpenType `head` table. It reads its fields from the data of the table when they are
/// asked for.
public struct HeadTable: Sendable {
    private let table: SFNTTableReader

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("head") else {
            return nil
        }

        table = SFNTTableReader(data: data, minLength: 54)
    }

    public var version: Int32 { table.readInt32(at: 0) }
    public var fontRevision: Int32 { table.readInt32(at: 4) }
    public var checkSumAdjustment: UInt32 { table.readUInt32(at: 8) }
    public var magicNumber: UInt32 { table.readUInt32(at: 12) }
    public var flags: Int { table.readUInt16(at: 16) }
    public var unitsPerEm: Int { table.readUInt16(at: 18) }
    public var created: Int64 { table.readInt64(at: 20) }
    public var modified: Int64 { table.readInt64(at: 28) }
    public var xMin: Int16 { table.readInt16(at: 36) }
    public var yMin: Int16 { table.readInt16(at: 38) }
    public var xMax: Int16 { table.readInt16(at: 40) }
    public var yMax: Int16 { table.readInt16(at: 42) }
    public var macStyle: Int { table.readUInt16(at: 44) }
    public var lowestRecPPEM: Int { table.readUInt16(at: 46) }
    public var fontDirectionHint: Int16 { table.readInt16(at: 48) }
    public var indexToLocFormat: Int16 { table.readInt16(at: 50) }
    public var glyphDataFormat: Int16 { table.readInt16(at: 52) }
}
