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

internal import SheenBidi

import Foundation

/// Provides the Unicode properties of individual code points.
public enum CodePoint {
    /// Returns the bidirectional class of a code point.
    public static func bidiClass(of codePoint: UnicodeScalar) -> BidiClass {
        return BidiClass(rawValue: Int(SBCodepointGetBidiType(codePoint.value))) ?? .unknown
    }

    /// Returns the general category of a code point.
    public static func generalCategory(of codePoint: UnicodeScalar) -> GeneralCategory {
        return GeneralCategory(rawValue: Int(SBCodepointGetGeneralCategory(codePoint.value))) ?? .unknown
    }

    /// Returns the script of a code point.
    public static func script(of codePoint: UnicodeScalar) -> Script {
        return Script(rawValue: Int(SBCodepointGetScript(codePoint.value))) ?? .unknown
    }

    /// Returns the mirror of a code point, or `nil` if it has none.
    public static func mirror(of codePoint: UnicodeScalar) -> UnicodeScalar? {
        let mirror = SBCodepointGetMirror(codePoint.value)

        return mirror != 0 ? UnicodeScalar(mirror) : nil
    }
}
