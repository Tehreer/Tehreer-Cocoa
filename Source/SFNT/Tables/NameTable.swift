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

/// Represents an OpenType `name` table. The records are read from the data of the table when they
/// are asked for.
public struct NameTable: Sendable {
    /// A record of the name table.
    public struct Record: Equatable, Sendable {
        public var nameID: Int
        public var platformID: Int
        public var languageID: Int
        public var encodingID: Int
        public var bytes: [UInt8]

        /// The locale of the record, which is known only for the Windows platform.
        public var locale: Locale? {
            guard platformID == 3 else {
                return nil
            }

            let identifier = CFLocaleCreateLocaleIdentifierFromWindowsLocaleCode(
                nil,
                UInt32(languageID)
            )

            return identifier.map { Locale(identifier: $0.rawValue as String) }
        }

        /// The string encoding of the record, which is known for the Unicode, Macintosh Roman and
        /// Windows platforms.
        public var encoding: String.Encoding? {
            switch (platformID, encodingID) {
            case (0, _), (3, 0), (3, 1), (3, 10):
                return .utf16BigEndian
            case (1, 0):
                return .macOSRoman
            default:
                return nil
            }
        }

        /// The string of the record, or `nil` if its encoding is not known.
        public var string: String? {
            return encoding.flatMap { String(bytes: bytes, encoding: $0) }
        }
    }

    private static let headerLength = 6
    private static let recordLength = 12
    private static let languageTagRecordLength = 4

    private let data: Data

    /// Creates the table from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the table is read.
    /// - Returns: `nil` if the typeface does not contain the table.
    public init?(typeface: Typeface) {
        guard let data = typeface.dataOfTable("name") else {
            return nil
        }

        self.data = data
    }

    private var reader: SFNTTableReader {
        return SFNTTableReader(data: data, minLength: NameTable.headerLength)
    }

    // The offset of the strings, or nil if the table is malformed.
    private var storageStart: Int? {
        let reader = self.reader
        let count = reader.readUInt16(at: 2)
        var start = NameTable.headerLength + NameTable.recordLength * count

        // The language tag records of the format 1 come before the strings.
        if reader.readUInt16(at: 0) == 1 {
            guard start + 2 <= data.count else {
                return nil
            }

            start += 2 + NameTable.languageTagRecordLength * SFNTTableReader(
                data: data,
                minLength: start + 2
            ).readUInt16(at: start)
        }

        return start <= data.count ? start : nil
    }

    /// The number of records in this table that have a string.
    public var recordCount: Int {
        return records.count
    }

    /// The records of this table that have a string.
    public var records: [Record] {
        guard data.count >= NameTable.headerLength, let storageStart = storageStart else {
            return []
        }

        let reader = self.reader
        let count = reader.readUInt16(at: 2)
        let storageOffset = reader.readUInt16(at: 4)
        let all = SFNTTableReader(data: data, minLength: data.count)
        var result: [Record] = []

        for index in 0 ..< count {
            let offset = NameTable.headerLength + index * NameTable.recordLength
            guard offset + NameTable.recordLength <= data.count else {
                break
            }

            let length = all.readUInt16(at: offset + 8)
            let stringStart = storageOffset + all.readUInt16(at: offset + 10)

            if length > 0 && stringStart >= storageStart && stringStart + length <= data.count {
                result.append(Record(
                    nameID: all.readUInt16(at: offset + 6),
                    platformID: all.readUInt16(at: offset),
                    languageID: all.readUInt16(at: offset + 4),
                    encodingID: all.readUInt16(at: offset + 2),
                    bytes: all.readBytes(at: stringStart, count: length)
                ))
            }
        }

        return result
    }
}
