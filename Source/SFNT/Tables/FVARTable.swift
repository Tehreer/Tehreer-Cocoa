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

enum FVAR { }

extension FVAR {
    struct Table {
        private static let majorVersion = 0
        private static let minorVersion = 2
        private static let axesArrayOffset = 4
        private static let axisCount = 8
        private static let axisSize = 10
        private static let instanceCount = 12
        private static let instanceSize = 14

        private let data: SFNTTable

        public init?(typeface: Typeface) {
            guard let data = typeface.dataOfTable("fvar") else {
                return nil
            }

            self.data = DataTable(data: data)
        }

        init(data: Data) {
            self.data = DataTable(data: data)
        }

        var majorVersion: UInt16 {
            return data.readUInt16(at: Self.majorVersion);
        }

        var minorVersion: UInt16 {
            return data.readUInt16(at: Self.minorVersion);
        }

        var axesArrayOffset: UInt16 {
            return data.readUInt16(at: Self.axesArrayOffset);
        }

        var axisCount: UInt16 {
            return data.readUInt16(at: Self.axisCount);
        }

        var axisSize: UInt16 {
            return data.readUInt16(at: Self.axisSize);
        }

        var instanceCount: UInt16 {
            return data.readUInt16(at: Self.instanceCount);
        }

        var instanceSize: UInt16 {
            return data.readUInt16(at: Self.instanceSize);
        }

        var axisRecords: [AxisRecord] {
            let axesArrayOffset = self.axesArrayOffset
            let axisCount = self.axisCount
            let axisSize = self.axisSize
            var axisRecords: [AxisRecord] = []

            for i in 0 ..< axisCount {
                let recordOffset = Int(axesArrayOffset + (i * axisSize))
                let recordData = data.subTable(at: recordOffset)
                axisRecords.append(AxisRecord(data: recordData))
            }

            return axisRecords
        }

        var instanceRecords: [InstanceRecord] {
            let axesArrayOffset = self.axesArrayOffset
            let axisCount = self.axisCount
            let axisSize = self.axisSize
            let axesEndOffset = axesArrayOffset + (axisCount * axisSize)
            let instanceCount = self.instanceCount
            let instanceSize = self.instanceSize
            var instanceRecords: [InstanceRecord] = []

            for i in 0 ..< instanceCount {
                let recordData = data.subTable(at: Int(axesEndOffset + (i * instanceSize)))
                instanceRecords.append(InstanceRecord(data: recordData, axisCount: Int(axisCount), instanceSize: Int(instanceSize)))
            }

            return instanceRecords;
        }
    }
}

extension FVAR {
    struct AxisRecord {
        private static let axisTag = 0
        private static let minValue = 4
        private static let defaultValue = 8
        private static let maxValue = 12
        private static let flags = 16
        private static let axisNameId = 18

        private let data: SFNTTable

        init(data: SFNTTable) {
            self.data = data
        }

        var axisTag: UInt32 {
            return data.readUInt32(at: Self.axisTag);
        }

        var minValue: Float32 {
            return data.readFixed(at: Self.minValue);
        }

        var defaultValue: Float32 {
            return data.readFixed(at: Self.defaultValue);
        }

        var maxValue: Float32 {
            return data.readFixed(at: Self.maxValue);
        }

        var flags: UInt16 {
            return data.readUInt16(at: Self.flags);
        }

        var axisNameId: UInt16 {
            return data.readUInt16(at: Self.axisNameId);
        }
    }
}

extension FVAR {
    struct InstanceRecord {
        private static let subfamilyNameID = 0
        private static let flags = 2
        private static let coordinates = 4

        private let data: SFNTTable
        private let axisCount: Int
        private let postScriptNameIDOffset: Int?

        init(data: SFNTTable, axisCount: Int, instanceSize: Int) {
            let coordsEndOffset = Self.coordinates + (axisCount * 4)

            self.data = data
            self.axisCount = axisCount
            self.postScriptNameIDOffset = ((instanceSize - coordsEndOffset) < 2) ? nil : coordsEndOffset
        }

        var subfamilyNameID: UInt16 {
            return data.readUInt16(at: Self.subfamilyNameID)
        }

        var flags: UInt16 {
            return data.readUInt16(at: Self.flags)
        }

        var coordinates: [Float32] {
            var coordinates: [Float32] = []

            for i in 0 ..< axisCount {
                coordinates.append(data.readFixed(at: Self.coordinates + (i * 4)))
            }

            return coordinates
        }

        var postScriptNameID: Int32? {
            guard let offset = postScriptNameIDOffset else {
                return nil
            }

            return data.readInt32(at: offset)
        }
    }
}
