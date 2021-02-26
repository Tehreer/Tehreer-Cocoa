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
import FreeType

extension Typeface {
    /// Specifies the slope of a typeface.
    public enum Slope: Int {
        /// The plain slope indicating upright characters.
        case plain = 0
        /// The italic slope indicating truly slanted characters which appear as they were designed.
        case italic = 1
        /// The oblique slope indicating artificially slanted characters.
        case oblique = 2

        init(ital: FT_Fixed) {
            self = ital >= 0x10000 ? .italic : .plain
        }

        init(slnt: FT_Fixed) {
            self = slnt != 0 ? .oblique : .plain
        }
    }
}
