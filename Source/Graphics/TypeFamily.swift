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

import Foundation

/// A family of typefaces, which are registered in `TypefaceManager` under the same family ID, or
/// without one and under the same font family name.
public struct TypeFamily {
    /// The name of this family. For a family with an ID, it is the name of its first typeface in the
    /// sorted order.
    public let familyName: String

    /// The ID of this family, or zero if its typefaces are grouped by the font family name.
    public let familyID: TypeFamilyID

    /// The typefaces of this family, sorted by their style names.
    public let typefaces: [Typeface]
}

extension TypeFamily {
    /// Returns the typeface of this family that is closest to the specified style, as described by
    /// CSS Fonts Level 4.
    ///
    /// - Parameters:
    ///   - width: The typographic width of the desired typeface.
    ///   - weight: The typographic weight of the desired typeface.
    ///   - slope: The typographic slope of the desired typeface.
    /// - Returns: The best matching typeface, which is `nil` only for a family without typefaces.
    public func typeface(forWidth width: Typeface.Width, weight: Typeface.Weight,
                         slope: Typeface.Slope) -> Typeface? {
        if familyID != 0 {
            return TypefaceManager.default.typeface(
                forFamilyID: familyID,
                width: width,
                weight: weight,
                slope: slope
            )
        }

        return TypefaceManager.default.typeface(
            forFamilyName: familyName,
            width: width,
            weight: weight,
            slope: slope
        )
    }
}
