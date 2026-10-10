//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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

import CoreGraphics
import Foundation

/// Represents font variation axis. It reads what it tells from Core when it is asked for.
public struct VariationAxis: @unchecked Sendable {
    /// Flags for variation axis.
    public struct Flags: OptionSet, Sendable {
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

    // The typeface owns the memory that the axis of Core points to.
    private let owner: Typeface
    private let axis: TRVariationAxis

    init(owner: Typeface, axis: TRVariationAxis) {
        self.owner = owner
        self.axis = axis
    }

    /// The tag identifying the design variation.
    public var tag: SFNTTag {
        return SFNTTag(rawValue: axis.tag)!
    }

    /// The display name.
    public var name: String {
        return String(axis.name)
    }

    /// The axis qualifiers.
    public var flags: Flags {
        return Flags(rawValue: Int(axis.flags))
    }

    /// The default coordinate value.
    public var defaultValue: CGFloat {
        return CGFloat(axis.defaultValue)
    }

    /// The minimum coordinate value.
    public var minValue: CGFloat {
        return CGFloat(axis.minValue)
    }

    /// The maximum coordinate value.
    public var maxValue: CGFloat {
        return CGFloat(axis.maxValue)
    }
}
