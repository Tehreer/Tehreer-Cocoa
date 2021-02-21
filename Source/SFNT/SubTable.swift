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

struct SubTable: SFNTTable {
    private let table: SFNTTable
    private let globalOffset: Int

    init(table: SFNTTable, offset: Int) {
        self.table = table
        self.globalOffset = offset
    }

    func readInt8(at offset: Int) -> Int8 {
        return table.readInt8(at: globalOffset + offset)
    }

    func readUInt8(at offset: Int) -> UInt8 {
        return table.readUInt8(at: globalOffset + offset)
    }

    func readInt16(at offset: Int) -> Int16 {
        return table.readInt16(at: globalOffset + offset)
    }

    func readUInt16(at offset: Int) -> UInt16 {
        return table.readUInt16(at: globalOffset + offset)
    }

    func readInt32(at offset: Int) -> Int32 {
        return table.readInt32(at: globalOffset + offset)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        return table.readUInt32(at: globalOffset + offset)
    }

    func readInt64(at offset: Int) -> Int64 {
        return table.readInt64(at: globalOffset + offset)
    }

    func subTable(at offset: Int) -> SFNTTable {
        return SubTable(table: table, offset: globalOffset + offset)
    }
}
