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
import UIKit

public struct ColorPalette {
    /// Flags for color palette.
    public struct Flags: OptionSet {
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

    /// The display name.
    public let name: String

    /// The property flags.
    public let flags: Flags

    /// The colors array.
    public let colors: [UIColor]

    init(name: String, flags: Flags, colors: [UIColor]) {
        self.name = name
        self.flags = flags
        self.colors = colors
    }
}
