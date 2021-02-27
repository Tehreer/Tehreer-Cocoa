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

/// Represents font variation axis.
public struct VariationAxis {
    /// Flags for variation axis.
    public struct Flags: OptionSet {
        /// The axis should not be exposed directly in user interfaces.
        public static let hiddenAxis = Flags(rawValue: 0x0001)

        /// The corresponding value of the raw type.
        public let rawValue: Int

        /// Creates a new option set from the given raw value.
        ///
        /// - Parameter rawValue: The raw value of the option set to create.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// The tag identifying the design variation.
    public let tag: SFNTTag

    /// The display name.
    public let name: String

    /// The axis qualifiers.
    public let flags: Flags

    /// The default coordinate value.
    public let defaultValue: CGFloat

    /// The minimum coordinate value.
    public let minValue: CGFloat

    /// The maximum coordinate value.
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
