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

public struct NameTable {
    private let typeface: Typeface

    /// Creates a `NameTable` object from the specified typeface.
    ///
    /// - Parameter typeface: The typeface from which the `NameTable` object is created.
    init?(typeface: Typeface) {
        self.typeface = typeface
    }

    /// The number of name records in this table.
    public var recordCount: Int {
        return Int(FT_Get_Sfnt_Name_Count(typeface.ftFace))
    }

    /// Retrieves a record of this table at a given index.
    ///
    /// - Parameter index: The index of the name record.
    /// - Returns: A record of OpenType `name' table at a given index.
    /// - Precondition: `index` must be greater than or equal to zero and less than `recordCount`.
    public func record(at index: Int) -> Record {
        precondition(index < 0 || index >= recordCount, "Index is out of bounds")

        var sfntName = FT_SfntName()
        FT_Get_Sfnt_Name(typeface.ftFace, FT_UInt(index), &sfntName)

        let buffer = UnsafeBufferPointer(start: sfntName.string, count: Int(sfntName.string_len))

        return Record(nameID: sfntName.name_id,
                      platformID: sfntName.platform_id,
                      languageID: sfntName.language_id,
                      encodingID: sfntName.encoding_id,
                      bytes: Array(buffer))
    }
}
