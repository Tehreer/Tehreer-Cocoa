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

/// Represents an OpenType `maxp` table. It reads its fields from the data of the table when they are
/// asked for.
public struct MaxpTable: Sendable {
    private let table: SFNTTableReader

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("maxp") else {
            return nil
        }

        table = SFNTTableReader(data: data, minLength: 32)
    }

    public var version: Int32 { table.readInt32(at: 0) }
    public var numGlyphs: Int { table.readUInt16(at: 4) }
    public var maxPoints: Int { table.readUInt16(at: 6) }
    public var maxContours: Int { table.readUInt16(at: 8) }
    public var maxCompositePoints: Int { table.readUInt16(at: 10) }
    public var maxCompositeContours: Int { table.readUInt16(at: 12) }
    public var maxZones: Int { table.readUInt16(at: 14) }
    public var maxTwilightPoints: Int { table.readUInt16(at: 16) }
    public var maxStorage: Int { table.readUInt16(at: 18) }
    public var maxFunctionDefs: Int { table.readUInt16(at: 20) }
    public var maxInstructionDefs: Int { table.readUInt16(at: 22) }
    public var maxStackElements: Int { table.readUInt16(at: 24) }
    public var maxSizeOfInstructions: Int { table.readUInt16(at: 26) }
    public var maxComponentElements: Int { table.readUInt16(at: 28) }
    public var maxComponentDepth: Int { table.readUInt16(at: 30) }
}
