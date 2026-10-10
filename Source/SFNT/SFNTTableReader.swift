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

/// Reads the big-endian fields of the data of a table of a font. The fields that an older version
/// of the table does not have read as zero, so the data is padded up to the length of the newest
/// version.
struct SFNTTableReader: Sendable {
    private let data: Data

    init(data: Data, minLength: Int) {
        if data.count < minLength {
            self.data = data + Data(count: minLength - data.count)
        } else {
            self.data = data
        }
    }

    func readBytes(at offset: Int, count: Int) -> [UInt8] {
        let start = data.startIndex + offset

        return Array(data[start ..< start + count])
    }

    func readUInt16(at offset: Int) -> Int {
        let start = data.startIndex + offset

        return Int(data[start]) << 8 | Int(data[start + 1])
    }

    func readInt16(at offset: Int) -> Int16 {
        return Int16(truncatingIfNeeded: readUInt16(at: offset))
    }

    func readUInt32(at offset: Int) -> UInt32 {
        return UInt32(readUInt16(at: offset)) << 16 | UInt32(readUInt16(at: offset + 2))
    }

    func readInt32(at offset: Int) -> Int32 {
        return Int32(bitPattern: readUInt32(at: offset))
    }

    func readInt64(at offset: Int) -> Int64 {
        return Int64(bitPattern: UInt64(readUInt32(at: offset)) << 32 | UInt64(readUInt32(at: offset + 4)))
    }
}
