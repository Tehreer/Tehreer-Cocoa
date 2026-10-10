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

/// Represents an OpenType `hhea` table. It reads its fields from the data of the table when they are
/// asked for.
public struct HheaTable: Sendable {
    private let table: SFNTTableReader

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("hhea") else {
            return nil
        }

        table = SFNTTableReader(data: data, minLength: 36)
    }

    public var version: Int32 { table.readInt32(at: 0) }
    public var ascender: Int16 { table.readInt16(at: 4) }
    public var descender: Int16 { table.readInt16(at: 6) }
    public var lineGap: Int16 { table.readInt16(at: 8) }
    public var advanceWidthMax: Int { table.readUInt16(at: 10) }
    public var minLeftSideBearing: Int16 { table.readInt16(at: 12) }
    public var minRightSideBearing: Int16 { table.readInt16(at: 14) }
    public var xMaxExtent: Int16 { table.readInt16(at: 16) }
    public var caretSlopeRise: Int16 { table.readInt16(at: 18) }
    public var caretSlopeRun: Int16 { table.readInt16(at: 20) }
    public var caretOffset: Int16 { table.readInt16(at: 22) }
    public var metricDataFormat: Int16 { table.readInt16(at: 32) }
    public var numberOfHMetrics: Int { table.readUInt16(at: 34) }
}
