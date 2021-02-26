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
    /// Specifies the thickness of a typeface, in terms of lightness or heaviness of the strokes.
    public enum Weight: Int {
        case thin = 100
        case extraLight = 200
        case light = 300
        case regular = 400
        case medium = 500
        case semiBold = 600
        case bold = 700
        case extraBold = 800
        case heavy = 900

        static let allValues: [Typeface.Weight] = [
            .thin, .extraLight, .light,
            .regular, .medium, .semiBold,
            .bold, .extraBold, .heavy
        ]

        init(value: UInt16) {
            let index = Int((Float(value) / 100.0) - 0.5)
            self = Self.allValues[max(0, min(8, index))]
        }

        init(wght: CGFloat) {
            let value: UInt16

            if (wght < 1) {
                value = 1
            } else if (wght > 1000) {
                value = 1000
            } else {
                value = UInt16(wght)
            }

            self.init(value: value)
        }
    }
}
