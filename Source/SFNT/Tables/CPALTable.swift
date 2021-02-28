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

enum CPAL { }

extension CPAL {
    struct Table {
        private static let version = 0
        private static let numPaletteEntries = 2
        private static let numPalettes = 4
        private static let numColorRecords = 6
        private static let colorRecordsArrayOffset = 8
        private static let colorRecordIndices = 12

        private static let paletteTypesArrayOffset = 0
        private static let paletteLabelsArrayOffset = 4
        private static let paletteEntryLabelsArrayOffset = 8

        private let data: SFNTTable

        init(data: Data) {
            self.data = DataTable(data: data)
        }

        var version: UInt16 {
            return data.readUInt16(at: Self.version)
        }

        var numPaletteEntries: UInt16 {
            return data.readUInt16(at: Self.numPaletteEntries)
        }

        var numPalettes: UInt16 {
            return data.readUInt16(at: Self.numPalettes)
        }

        var numColorRecords: UInt16 {
            return data.readUInt16(at: Self.numColorRecords)
        }

        var colorRecords: ColorRecordsArray {
            let offset = data.readOffset32(at: Self.colorRecordsArrayOffset)
            return ColorRecordsArray(data: data.subTable(at: offset))
        }

        func colorRecordIndex(at paletteIndex: Int) -> UInt16 {
            return data.readUInt16(at: Self.colorRecordIndices + (paletteIndex * 2))
        }

        var paletteTypes: PaletteTypesArray? {
            guard version >= 1 else {
                return nil
            }

            let colorIndicesEndOffset = Self.colorRecordIndices + (Int(numColorRecords) * 2)
            let typesArrayOffset = data.readOffset32(at: colorIndicesEndOffset + Self.paletteTypesArrayOffset)
            guard typesArrayOffset > 0 else {
                return nil
            }

            return PaletteTypesArray(data: data.subTable(at: typesArrayOffset))
        }

        var paletteLabels: PaletteLabelsArray? {
            guard version >= 1 else {
                return nil
            }

            let colorIndicesEndOffset = Self.colorRecordIndices + (Int(numColorRecords) * 2)
            let labelsArrayOffset = data.readOffset32(at: colorIndicesEndOffset + Self.paletteLabelsArrayOffset)
            guard labelsArrayOffset > 0 else {
                return nil
            }

            return PaletteLabelsArray(data: data.subTable(at: labelsArrayOffset))
        }

        var paletteEntryLabels: PaletteLabelsArray? {
            guard version >= 1 else {
                return nil
            }

            let colorIndicesEndOffset = Self.colorRecordIndices + (Int(numColorRecords) * 2)
            let labelsArrayOffset = data.readOffset32(at: colorIndicesEndOffset + Self.paletteEntryLabelsArrayOffset)
            guard labelsArrayOffset > 0 else {
                return nil
            }

            return PaletteLabelsArray(data: data.subTable(at: labelsArrayOffset))
        }
    }
}

extension CPAL {
    struct ColorRecord {
        private static let blue = 0
        private static let green = 1
        private static let red = 2
        private static let alpha = 3

        private let data: SFNTTable

        init(data: SFNTTable) {
            self.data = data
        }

        var blue: UInt8 {
            return data.readUInt8(at: Self.blue);
        }

        var green: UInt8 {
            return data.readUInt8(at: Self.green);
        }

        var red: UInt8 {
            return data.readUInt8(at: Self.red);
        }

        var alpha: UInt8 {
            return data.readUInt8(at: Self.alpha);
        }
    }
}

extension CPAL {
    struct ColorRecordsArray {
        private let data: SFNTTable

        init(data: SFNTTable) {
            self.data = data
        }

        subscript(index: Int) -> ColorRecord {
            return ColorRecord(data: data.subTable(at: index * 4))
        }
    }
}

extension CPAL {
    struct PaletteLabelsArray {
        private let data: SFNTTable

        init(data: SFNTTable) {
            self.data = data
        }

        subscript(index: Int) -> UInt16 {
            return data.readUInt16(at: index * 2)
        }
    }
}

extension CPAL {
    struct PaletteTypesArray {
        private let data: SFNTTable

        init(data: SFNTTable) {
            self.data = data
        }

        subscript(index: Int) -> UInt32 {
            return data.readUInt32(at: index * 4)
        }
    }
}
