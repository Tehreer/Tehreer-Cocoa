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

internal import Tehreer

import CoreGraphics
import Foundation

/// The `GlyphImage` class represents the image of a glyph that a renderer gets from its glyph
/// cache. The pixels are not exposed, the image is drawn through its layer.
public final class GlyphImage: @unchecked Sendable {
    // The image of Core is immutable once it is created, and its native data, which holds the layer,
    // is attached in a thread safe way, so the image can be read from any thread.

    /// Specifies how the pixels of a glyph image are stored.
    public enum Format: Sendable {
        /// One byte for each pixel, holding its coverage. The image is drawn with a color.
        case alpha
        /// Four bytes for each pixel, with the colors of the glyph. The image is drawn as it is.
        case argb
    }

    private let core: TRGlyphImageRef

    /// Creates an image that takes over the reference of the image of Core.
    init(owning core: TRGlyphImageRef) {
        self.core = core
    }

    deinit {
        TRGlyphImageRelease(core)
    }

    /// The format of the pixels of this image.
    public var format: Format {
        return TRGlyphImageGetFormat(core) == TRGlyphImageFormat(TRGlyphImageFormatAlpha)
            ? .alpha : .argb
    }

    /// The horizontal distance from the pen position to the left edge of this image.
    public var left: Int {
        return Int(TRGlyphImageGetLeft(core))
    }

    /// The vertical distance from the baseline to the top edge of this image.
    public var top: Int {
        return Int(TRGlyphImageGetTop(core))
    }

    /// The width of this image in pixels.
    public var width: Int {
        return Int(TRGlyphImageGetWidth(core))
    }

    /// The height of this image in pixels.
    public var height: Int {
        return Int(TRGlyphImageGetHeight(core))
    }

    /// The layer that this image is drawn from, which is made the first time it is asked for and is
    /// kept with the image. It is `nil` if the image has no pixels.
    public var layer: CGLayer? {
        return GlyphLayers.layer(of: core)
    }
}
