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

import CoreGraphics
import FreeType

extension CGFloat {
    init(f16Dot16 value: FT_Fixed) {
        self = CGFloat(value) / CGFloat(0x10000)
    }

    init(f26Dot6 value: FT_Pos) {
        self = CGFloat(value) / 64.0
    }

    var f26Dot6: FT_F26Dot6 {
        return FT_F26Dot6((self * 64) + 0.5)
    }

    var f16Dot16: FT_Fixed {
        return FT_Fixed((self * 0x10000) + 0.5)
    }
}
