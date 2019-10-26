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
import FreeType

/// Represents an OpenType `name` table.
public struct NameTable {
    private let typeface: Typeface

    /// Creates a `name` table representation from the specified typeface.
    ///
    /// - Parameter typeface: The typeface for accessing the data of the table.
    init?(typeface: Typeface) {
        self.typeface = typeface
    }

    /// The number of name records in this table.
    public var recordCount: Int {
        return Int(FT_Get_Sfnt_Name_Count(typeface.ftFace))
    }

    /// Retrieves a name record at a specified index.
    ///
    /// - Parameter index: The index of the name record.
    /// - Returns: A record of OpenType `name` table at a specified index.
    /// - Precondition: `index` must be greater than or equal to zero and less than `recordCount`.
    public func record(at index: Int) -> Record {
        precondition(index >= 0 || index < recordCount, "Index is out of bounds")

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

extension NameTable {
    enum NameID: UInt16 {
        case fontFamily = 1
        case fontSubfamily = 2
        case full = 3
        case typographicFamily = 16
        case typographicSubfamily = 17
        case wwsFamily = 21
        case wwsSubfamily = 22
    }

    enum PlatformID: UInt16 {
        case macintosh = 1
        case windows = 3
    }

    func englishName(for nameID: UInt16) -> String? {
        var candidate: Record? = nil

        for i in 0 ..< recordCount {
            let current = record(at: i)
            if current.nameID != nameID {
                continue
            }

            let locale = current.locale
            if locale?.languageCode == "en" {
                if current.platformID == PlatformID.windows.rawValue && locale?.regionCode == "US" {
                    return current.string
                }

                if candidate == nil || current.platformID == PlatformID.macintosh.rawValue {
                    candidate = current
                }
            }
        }

        if let candidate = candidate {
            return candidate.string
        }

        return nil
    }

    func suitableFamilyName(considering os2Table: OS2Table?) -> String? {
        var familyName: String? = nil

        if let os2Table = os2Table {
            if (os2Table.fsSelection & OS2Table.FSSelection.wws.rawValue) != 0 {
                familyName = englishName(for: NameID.wwsFamily.rawValue)
            }
        }
        if familyName == nil {
            familyName = englishName(for: NameID.typographicFamily.rawValue)
        }
        if familyName == nil {
            familyName = englishName(for: NameID.fontFamily.rawValue)
        }

        return familyName
    }

    func suitableStyleName(considering os2Table: OS2Table?) -> String? {
        var styleName: String? = nil

        if let os2Table = os2Table {
            if (os2Table.fsSelection & OS2Table.FSSelection.wws.rawValue) != 0 {
                styleName = englishName(for: NameID.wwsSubfamily.rawValue)
            }
        }
        if styleName == nil {
            styleName = englishName(for: NameID.typographicSubfamily.rawValue)
        }
        if styleName == nil {
            styleName = englishName(for: NameID.fontSubfamily.rawValue)
        }

        return styleName
    }
}
