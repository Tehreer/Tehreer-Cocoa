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

protocol SFNTTable {
    func readInt8(at offset: Int) -> Int8
    func readUInt8(at offset: Int) -> UInt8

    func readInt16(at offset: Int) -> Int16
    func readUInt16(at offset: Int) -> UInt16

    func readInt32(at offset: Int) -> Int32
    func readUInt32(at offset: Int) -> UInt32

    func readInt64(at offset: Int) -> Int64

    func readFixed(at offset: Int) -> Float32

    func readOffset32(at offset: Int) -> Int

    func subTable(at offset: Int) -> SFNTTable
}

extension SFNTTable {
    func readFixed(at offset: Int) -> Float32 {
        return Float32(readInt32(at: offset)) / 65536.0
    }

    func readOffset32(at offset: Int) -> Int {
        return Int(readUInt32(at: offset) & ~0x80000000)
    }

    func subTable(at offset: Int) -> SFNTTable {
        return SubTable(table: self, offset: offset)
    }
}
