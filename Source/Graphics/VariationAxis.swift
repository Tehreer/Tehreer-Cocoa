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

public struct VariationAxis {
    public struct Flags: OptionSet {
        public static let hiddenAxis = Flags(rawValue: 0x0001)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let tag: SFNTTag
    public let name: String
    public let flags: Flags
    public let defaultValue: CGFloat
    public let minValue: CGFloat
    public let maxValue: CGFloat

    init(tag: SFNTTag, name: String, flags: VariationAxis.Flags,
         defaultValue: CGFloat, minValue: CGFloat, maxValue: CGFloat) {
        self.tag = tag
        self.name = name
        self.flags = flags
        self.defaultValue = defaultValue
        self.minValue = minValue
        self.maxValue = maxValue
    }
}
