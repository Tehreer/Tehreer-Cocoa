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

import Foundation
import UIKit

/// Represents a color palette of a font. It reads what it tells from Core when it is asked for.
public struct ColorPalette: @unchecked Sendable {
    /// Flags for color palette.
    public struct Flags: OptionSet, Sendable {
        public static let usableWithLightBackground = Flags(rawValue: 0x0001)
        public static let usableWithDarkBackground = Flags(rawValue: 0x0002)

        /// The corresponding value of the raw type.
        public let rawValue: Int

        /// Creates a new option set from the given raw value.
        ///
        /// - Parameter rawValue: The raw value of the option set to create.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    // The typeface owns the memory that the palette of Core points to.
    private let owner: Typeface
    private let palette: TRPredefinedPalette

    init(owner: Typeface, palette: TRPredefinedPalette) {
        self.owner = owner
        self.palette = palette
    }

    /// The display name.
    public var name: String {
        return String(palette.name)
    }

    /// The property flags.
    public var flags: Flags {
        return Flags(rawValue: Int(palette.flags))
    }

    /// The colors array.
    public var colors: PrimitiveCollection<UIColor> {
        return PrimitiveCollection(
            CoreCollection(
                owner: owner, pointer: palette.colorsPtr, count: Int(palette.colorCount)
            ) { UIColor(coreValue: $0) }
        )
    }
}
