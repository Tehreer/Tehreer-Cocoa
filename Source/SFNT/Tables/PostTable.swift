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

/// Represents an OpenType `post` table. It reads its fields from the data of the table when they are
/// asked for.
public struct PostTable: Sendable {
    private let table: SFNTTableReader
    private let typeface: Typeface

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("post") else {
            return nil
        }

        self.typeface = typeface
        table = SFNTTableReader(data: data, minLength: 32)
    }

    public var version: Int32 { table.readInt32(at: 0) }
    public var italicAngle: Int32 { table.readInt32(at: 4) }
    public var underlinePosition: Int16 { table.readInt16(at: 8) }
    public var underlineThickness: Int16 { table.readInt16(at: 10) }
    public var isFixedPitch: UInt32 { table.readUInt32(at: 12) }
    public var minMemType42: UInt32 { table.readUInt32(at: 16) }
    public var maxMemType42: UInt32 { table.readUInt32(at: 20) }
    public var minMemType1: UInt32 { table.readUInt32(at: 24) }
    public var maxMemType1: UInt32 { table.readUInt32(at: 28) }

    /// The number of glyphs of the typeface.
    public var numberOfGlyphs: Int { typeface.glyphCount }

    /// Returns the name of a glyph, which the font gives in its post table, or in its charset if
    /// it is a CFF font.
    ///
    /// - Parameter index: The ID of the glyph.
    /// - Returns: The name of the glyph, or `nil` if the font has none for it.
    public func glyphName(at index: Int) -> String? {
        precondition(index >= 0 && index < numberOfGlyphs, .indexOutOfRange)

        return typeface.glyphName(forGlyph: GlyphID(index))
    }
}
