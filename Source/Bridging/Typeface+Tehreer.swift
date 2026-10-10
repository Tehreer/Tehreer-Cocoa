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

internal import Tehreer

extension Typeface.Weight {
    init(coreValue: TRWeight) {
        self = Typeface.Weight(rawValue: Int(coreValue)) ?? .regular
    }

    var coreValue: TRWeight {
        return TRWeight(rawValue)
    }
}

extension Typeface.Width {
    init(coreValue: TRWidth) {
        self = Typeface.Width(rawValue: Int(coreValue)) ?? .normal
    }

    var coreValue: TRWidth {
        return TRWidth(rawValue)
    }
}

extension Typeface.Slope {
    init(coreValue: TRSlope) {
        self = Typeface.Slope(rawValue: Int(coreValue)) ?? .plain
    }

    var coreValue: TRSlope {
        return TRSlope(rawValue)
    }
}
