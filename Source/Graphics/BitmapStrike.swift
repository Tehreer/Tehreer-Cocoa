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

import CoreGraphics

/// A size at which a font has the images of its glyphs, such as the `CBDT` and `sbix` fonts of
/// color emoji. The image of a glyph is not drawn from an outline, so it is picked from the strike
/// whose size is the nearest to the one asked for, and scaled to match that size.
public struct BitmapStrike: Equatable, Sendable {
    /// The number of pixels in the em square, horizontally.
    public let pixelWidth: CGFloat

    /// The number of pixels in the em square, vertically.
    public let pixelHeight: CGFloat

    public init(pixelWidth: CGFloat, pixelHeight: CGFloat) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
