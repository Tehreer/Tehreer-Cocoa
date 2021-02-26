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
import Foundation

extension Typeface {
    /// Specifies the wideness of a typeface, in terms of the width of characters in relation to
    /// their heights.
    public enum Width: Int {
        case ultraCondensed = 1
        case extraCondensed = 2
        case condensed = 3
        case semiCondensed = 4
        case normal = 5
        case semiExpanded = 6
        case expanded = 7
        case extraExpanded = 8
        case ultraExpanded = 9

        static let allValues: [Typeface.Width] = [
            .ultraCondensed, .extraCondensed, .condensed,
            .semiCondensed, .normal, .semiExpanded,
            .expanded, .extraExpanded, .ultraExpanded
        ]

        init(value: UInt16) {
            let index = Int(value - 1)
            self = Self.allValues[max(0, min(8, index))]
        }

        init(wdth: CGFloat) {
            let value: UInt16

            if (wdth < 50) {
                value = 1
            } else if (wdth < 125) {
                value = UInt16(((wdth - 50) / 12.5) + 1)
            } else if (wdth < 200) {
                value = UInt16(((wdth - 125) / 25) + 7)
            } else {
                value = 9
            }

            self.init(value: value)
        }
    }
}
