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

public struct HHEATable {
    private let typeface: Typeface
    private let table: UnsafeMutablePointer<TT_HoriHeader>

    init?(typeface: Typeface) {
        let pointer = FT_Get_Sfnt_Table(typeface.ftFace, FT_SFNT_HHEA)
        guard let raw = pointer else {
            return nil
        }

        self.typeface = typeface
        self.table = raw.assumingMemoryBound(to: TT_HoriHeader.self)
    }

    public var version: Int32 {
        return Int32(table.pointee.Version)
    }

    public var ascender: Int16 {
        return table.pointee.Ascender
    }

    public var descender: Int16 {
        return table.pointee.Descender
    }

    public var lineGap: Int16 {
        return table.pointee.Line_Gap
    }

    public var advanceWidthMax: UInt16 {
        return table.pointee.advance_Width_Max
    }

    public var minLeftSideBearing: Int16 {
        return table.pointee.min_Left_Side_Bearing
    }

    public var minRightSideBearing: Int16 {
        return table.pointee.min_Right_Side_Bearing
    }

    public var xMaxExtent: Int16 {
        return table.pointee.xMax_Extent
    }

    public var caretSlopeRise: Int16 {
        return table.pointee.caret_Slope_Rise
    }

    public var caretSlopeRun: Int16 {
        return table.pointee.caret_Slope_Run
    }

    public var caretOffset: Int16 {
        return table.pointee.caret_Offset
    }

    public var metricDataFormat: Int16 {
        return table.pointee.metric_Data_Format
    }

    public var numberOfHMetrics: UInt16 {
        return table.pointee.number_Of_HMetrics
    }
}
