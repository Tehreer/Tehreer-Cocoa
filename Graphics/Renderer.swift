//
// Copyright (C) 2019 Muhammad Tayyab Akram
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

public enum RenderingStyle {
    /// Glyphs drawn with this style will be filled, ignoring all stroke-related settings in the
    /// renderer.
    case fill
    /// Glyphs drawn with this style will be both filled and stroked at the same time, respecting
    /// the stroke-related settings in the renderer.
    case fillStroke
    /// Glyphs drawn with this style will be stroked, respecting the stroke-related settings in the
    /// the renderer.
    case stroke
}

/// Specifies the treatment for the beginning and ending of stroked lines and paths.
public enum StrokeCap: Int {
    /// The stroke ends with the path, and does not project beyond it.
    case butt = 0
    /// The stroke projects out as a semicircle, with the center at the end of the
    case round = 1
    /// The stroke projects out as a square, with the center at the end of the path.
    case square = 2
}

/// Specifies the treatment where lines and curve segments join on a stroked path.
public enum StrokeJoin : Int {
    /// The outer edges of a join meet with a straight line.
    case bevel = 1
    /// The outer edges of a join meet at a sharp angle.
    case miter = 2
    /// The outer edges of a join meet in a circular arc.
    case round = 0
}

public class Renderer {
    private var glyphStrike: GlyphStrike = GlyphStrike()
    private var glyphLineRadius: Int = 32
    private var glyphMiterLimit: Int = 0x10000
    private var shouldRender: Bool = false

    init() {
        updatePixelSizes()
    }

    /// The fill color for glyphs. Its default value is `.black`.
    public var fillColor: UIColor = .black

    /// The style, used for controlling how glyphs should appear while drawing. Its default value is
    /// `.fill`.
    public var renderingStyle: RenderingStyle = .fill

    /// The direction in which the pen will advance after drawing a glyph. Its default value is
    /// `.leftToRight`.
    public var writingDirection: WritingDirection = .leftToRight

    /// The typeface, used for drawing glyphs.
    public var typeface: Typeface! = nil {
        didSet {
            glyphStrike.typeface = typeface
        }
    }

    /// The type size, applied on glyphs while drawing.
    public var typeSize: CGFloat = 16.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The slant angle for glyphs. Its default value is 0.
    public var slantAngle: CGFloat = 0.0 {
        didSet {
            updateTransform()
        }
    }

    /// The horizontal scale factor for drawing/measuring glyphs. Its default value is 1.0. Values
    /// greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the glyphs
    /// narrower.
    public var scaleX: CGFloat = 1.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The vertical scale factor for drawing/measuring glyphs. Its default value is 1.0. Values
    /// greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the glyphs
    /// narrower.
    public var scaleY: CGFloat = 1.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The stroke color for glyphs. Its default value is `.black`.
    public var strokeColor: UIColor = .black

    /// The width, in pixels, for stroking glyphs.
    public var strokeWidth: CGFloat = 1.0 {
        didSet {
            glyphLineRadius = Int((strokeWidth * 64.0 / 2.0) + 0.5)
        }
    }

    /// The stroke cap style which controls how the start and end of stroked lines and paths are
    /// treated. Its default value is `.butt`.
    public var strokeCap: StrokeCap = .butt

    /// The stroke join type. Its default value is `.round`.
    public var strokeJoin: StrokeJoin = .round

    /// The stroke miter limit in pixels. This is used to control the behavior of miter joins when
    /// the joins angle is sharp.
    public var strokeMiter: CGFloat = 1.0 {
        didSet {
            glyphMiterLimit = Int((strokeMiter * 0x10000) + 0.5)
        }
    }

    /// The shadow radius, in pixels, used when drawing glyphs. Its default value is
    /// zero. The shadow would be disabled if the value is set to zero.
    public var shadowRadius: CGFloat = 0.0

    /// The horizontal shadow offset, in pixels.
    public var shadowDx: CGFloat = 0.0

    /// The vertical shadow offset in pixels.
    public var shadowDy: CGFloat = 0.0

    /// The shadow color.
    public var shadowColor: UIColor = .black

    private func updatePixelSizes() {
        let pixelWidth = Int((typeSize * scaleX * 64.0) + 0.5)
        let pixelHeight = Int((typeSize * scaleY * 64.0) + 0.5)

        // Minimum size supported by Freetype is 64x64.
        shouldRender = (pixelWidth >= 64 && pixelHeight >= 64)
        glyphStrike.pixelWidth = pixelWidth
        glyphStrike.pixelHeight = pixelHeight
    }

    private func updateTransform() {
        glyphStrike.skewX = Int((slantAngle * 0x10000) + 0.5)
    }
}
