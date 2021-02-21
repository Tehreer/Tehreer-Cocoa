//
// Copyright (C) 2021 Muhammad Tayyab Akram
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

struct DataTable: SFNTTable {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func readInt8(at offset: Int) -> Int8 {
        return Int8(bitPattern: data[offset])
    }

    func readUInt8(at offset: Int) -> UInt8 {
        return data[offset]
    }

    func readInt16(at offset: Int) -> Int16 {
        return Int16(bitPattern: (UInt16(data[offset + 0]) << 8)
                               | (UInt16(data[offset + 1]) << 0))
    }

    func readUInt16(at offset: Int) -> UInt16 {
        return (UInt16(data[offset + 0]) << 8)
             | (UInt16(data[offset + 1]))
    }

    func readInt32(at offset: Int) -> Int32 {
        return Int32(bitPattern: (UInt32(data[offset + 0]) << 24)
                               | (UInt32(data[offset + 1]) << 16)
                               | (UInt32(data[offset + 2]) << 8)
                               | (UInt32(data[offset + 3]) << 0))
    }

    func readUInt32(at offset: Int) -> UInt32 {
        return (UInt32(data[offset + 0]) << 24)
             | (UInt32(data[offset + 1]) << 16)
             | (UInt32(data[offset + 2]) << 8)
             | (UInt32(data[offset + 3]) << 0)
    }

    func readInt64(at offset: Int) -> Int64 {
        return Int64(bitPattern: UInt64(readUInt32(at: offset + 0) << 32)
                               | UInt64(readUInt32(at: offset + 4) << 0))
    }
}
