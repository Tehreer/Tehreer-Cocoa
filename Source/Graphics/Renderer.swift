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

/// The `Renderer` class represents a generic glyph renderer. It can be used to generate glyph
/// paths, measure their bounding boxes and draw them in a `CGContext` object.
public final class Renderer {
    /// Specifies if the glyph being drawn is filled, stroked, or both.
    public enum RenderingStyle: Sendable {
        /// Glyphs drawn with this style will be filled, ignoring all stroke-related settings in the
        /// renderer.
        case fill
        /// Glyphs drawn with this style will be both filled and stroked at the same time,
        /// respecting the stroke-related settings in the renderer.
        case fillStroke
        /// Glyphs drawn with this style will be stroked, respecting the stroke-related settings in
        /// the renderer.
        case stroke
    }

    /// Specifies the treatment for the beginning and ending of stroked lines and paths.
    public enum StrokeCap: Int, Sendable {
        /// The stroke ends with the path, and does not project beyond it.
        case butt = 0
        /// The stroke projects out as a semicircle, with the center at the end of the path.
        case round = 1
        /// The stroke projects out as a square, with the center at the end of the path.
        case square = 2
    }

    /// Specifies the treatment where lines and curve segments join on a stroked path.
    public enum StrokeJoin: Int, Sendable {
        /// The outer edges of a join meet with a straight line.
        case bevel = 1
        /// The outer edges of a join meet at a sharp angle.
        case miter = 2
        /// The outer edges of a join meet in a circular arc.
        case round = 0
    }

    private let core: TRRendererRef

    /// Creates a renderer.
    public init() {
        core = TRRendererCreate()
    }

    deinit {
        TRRendererRelease(core)
    }

    /// The fill color for glyphs. Its default value is `.black`.
    public var fillColor: UIColor = .black {
        didSet {
            TRRendererSetForegroundColor(core, fillColor.coreColor)
        }
    }

    /// The style, used for controlling how glyphs should appear while drawing. Its default value is
    /// `.fill`.
    public var renderingStyle: RenderingStyle = .fill

    /// The direction in which the pen will advance after drawing a glyph. Its default value is
    /// `.leftToRight`.
    public var writingDirection: WritingDirection = .leftToRight {
        didSet {
            let direction = (writingDirection == .rightToLeft
                             ? TRWritingDirectionRightToLeft
                             : TRWritingDirectionLeftToRight)

            TRRendererSetWritingDirection(core, TRWritingDirection(direction))
        }
    }

    /// The typeface, used for drawing glyphs.
    public var typeface: Typeface! = nil {
        didSet {
            TRRendererSetTypeface(core, typeface?.core)
        }
    }

    /// The type size applied on the glyphs while drawing.
    public var typeSize: CGFloat = 16.0 {
        didSet {
            TRRendererSetTypeSize(core, TRFloat(typeSize))
        }
    }

    /// The slant angle for glyphs. Its default value is zero.
    public var slantAngle: CGFloat = 0.0 {
        didSet {
            TRRendererSetSkewX(core, TRFloat(slantAngle))
        }
    }

    /// The scale factor applied to the glyphs and their metrics such as offsets and advances.
    public var renderScale: CGFloat = 1.0 {
        didSet {
            TRRendererSetRenderScale(core, TRFloat(renderScale))
        }
    }

    /// The horizontal scale factor applied on the glyphs while drawing. Its default value is 1.0.
    /// Values greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the
    /// glyphs narrower.
    public var scaleX: CGFloat = 1.0 {
        didSet {
            TRRendererSetScaleX(core, TRFloat(scaleX))
        }
    }

    /// The vertical scale factor applied on the glyphs while drawing. Its default value is 1.0.
    /// Values greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the
    /// glyphs narrower.
    public var scaleY: CGFloat = 1.0 {
        didSet {
            TRRendererSetScaleY(core, TRFloat(scaleY))
        }
    }

    /// The stroke color for glyphs. Its default value is `.black`.
    public var strokeColor: UIColor = .black

    /// The width, in pixels, for stroking glyphs.
    public var strokeWidth: CGFloat = 1.0 {
        didSet {
            TRRendererSetStrokeWidth(core, TRFloat(strokeWidth))
        }
    }

    /// The stroke cap style which controls how the start and end of stroked lines and paths are
    /// treated. Its default value is `.butt`.
    public var strokeCap: StrokeCap = .butt {
        didSet {
            TRRendererSetStrokeCap(core, TRStrokeCap(strokeCap.rawValue))
        }
    }

    /// The stroke join type. Its default value is `.round`.
    public var strokeJoin: StrokeJoin = .round {
        didSet {
            TRRendererSetStrokeJoin(core, TRStrokeJoin(strokeJoin.rawValue))
        }
    }

    /// The stroke miter limit in pixels. This is used to control the behavior of miter joins when
    /// the joins angle is sharp.
    public var strokeMiter: CGFloat = 1.0 {
        didSet {
            TRRendererSetStrokeMiter(core, TRFloat(strokeMiter))
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
    public var shadowColor: UIColor = .clear

    /// Generates the path of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose path is generated.
    /// - Returns: The path of the glyph specified by `glyphID`.
    public func makePath(glyphID: GlyphID) -> CGPath? {
        guard let corePath = TRRendererGetGlyphPath(core, glyphID) else {
            return nil
        }
        defer { TRPathRelease(corePath) }

        return Renderer.makeCGPath(from: corePath, transform: nil)
    }

    /// Generates a cumulative path of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIds: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    /// - Returns: The cumulative path of specified glyphs.
    public func makePath<GS, OS, AS>(glyphIDs: GS, offsets: OS, advances: AS) -> CGPath?
        where GS : Sequence, GS.Element == GlyphID,
              OS : Sequence, OS.Element == CGPoint,
              AS : Sequence, AS.Element == CGFloat {
        let run = GlyphRunData(glyphIDs: glyphIDs, offsets: offsets, advances: advances)
        let path = CGMutablePath()

        run.withPointers { (glyphIDs, offsets, advances, count) in
            var callbacks = Renderer.makePathCallbacks()

            let user = Unmanaged.passUnretained(path).toOpaque()
            TRRendererEnumerateGlyphPaths(core, glyphIDs, offsets, advances, count, &callbacks, user)
        }

        return path
    }

    private static func makePathCallbacks() -> TRPathCallbacks {
        var callbacks = TRPathCallbacks()
        callbacks.moveTo = { (user, x, y) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        callbacks.lineTo = { (user, x, y) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        callbacks.quadTo = { (user, controlX, controlY, x, y) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addQuadCurve(to: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                              control: CGPoint(x: CGFloat(controlX), y: CGFloat(controlY)))
        }
        callbacks.cubicTo = { (user, control1X, control1Y, control2X, control2Y, x, y) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addCurve(to: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                          control1: CGPoint(x: CGFloat(control1X), y: CGFloat(control1Y)),
                          control2: CGPoint(x: CGFloat(control2X), y: CGFloat(control2Y)))
        }
        callbacks.close = { (user) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue().closeSubpath()
        }

        return callbacks
    }

    private static func makeCGPath(from corePath: TRPathRef, transform: UnsafePointer<TRAffineTransform>?) -> CGPath {
        let path = CGMutablePath()
        let user = Unmanaged.passUnretained(path).toOpaque()

        var callbacks = makePathCallbacks()
        TRPathEnumerate(corePath, transform, &callbacks, user)

        return path
    }

    /// Calculates the bounding box of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose bounding box is calculated.
    /// - Returns: A rectangle that tightly encloses the path of the specified glyph.
    public func computeBoundingBox(forGlyph glyphID: GlyphID) -> CGRect {
        let box = TRRendererGetGlyphBoundingBox(core, glyphID)

        return CGRect(x: CGFloat(box.origin.x), y: CGFloat(box.origin.y),
                      width: CGFloat(box.size.width), height: CGFloat(box.size.height))
    }

    /// Calculates the bounding box of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIDs: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    /// - Returns: A rectangle that tightly encloses the paths of specified glyphs.
    public func computeBoundingBox<GS, OS, AS>(forGlyphs glyphIDs: GS, offsets: OS, advances: AS) -> CGRect
        where GS: Sequence, GS.Element == GlyphID,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        let run = GlyphRunData(glyphIDs: glyphIDs, offsets: offsets, advances: advances)

        let box = run.withPointers { (glyphIDs, offsets, advances, count) in
            TRRendererGetRunBoundingBox(core, glyphIDs, offsets, advances, count)
        }

        // An empty box is a null rectangle, as it has no place in the space of the glyphs.
        if box.size.width == 0 && box.size.height == 0 {
            return .null
        }

        return CGRect(x: CGFloat(box.origin.x), y: CGFloat(box.origin.y),
                      width: CGFloat(box.size.width), height: CGFloat(box.size.height))
    }

    private func drawGlyphs(in context: CGContext, run: GlyphRunData, kind: Int) {
        run.withPointers { (glyphIDs, offsets, advances, count) in
            guard count > 0 else {
                return
            }

            let placements = UnsafeMutablePointer<TRGlyphPlacement>.allocate(capacity: Int(count))
            defer { placements.deallocate() }

            TRRendererGetGlyphPlacements(core, TRGlyphImageKind(kind), glyphIDs, offsets, advances,
                                         count, placements)

            for index in 0 ..< Int(count) {
                guard let image = placements[index].image,
                      let layer = GlyphLayers.layer(of: image) else {
                    continue
                }

                let rect = CGRect(x: CGFloat(placements[index].origin.x),
                                  y: CGFloat(placements[index].origin.y),
                                  width: layer.size.width,
                                  height: layer.size.height)

                context.draw(layer, in: rect)
            }

            TRRendererReleaseGlyphPlacements(placements, count)
        }
    }

    /// Draws the glyphs in the specified context.
    ///
    /// - Parameters:
    ///   - context: The context onto which to draw the glyphs.
    ///   - glyphIDs: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    public func drawGlyphs<GS, OS, AS>(in context: CGContext, glyphIDs: GS, offsets: OS, advances: AS)
        where GS: Sequence, GS.Element == GlyphID,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        let run = GlyphRunData(glyphIDs: glyphIDs, offsets: offsets, advances: advances)

        if TRRendererIsRenderable(core) != 0 {
            context.setShadow(offset: CGSize(width: shadowDx, height: shadowDy),
                              blur: shadowRadius,
                              color: shadowColor.cgColor)
        }

        // Extract the pixel level translation.
        let transform = context.userSpaceToDeviceSpaceTransform
        let pixelPosition = CGPoint(x: round(transform.tx), y: round(transform.ty))
        let difference = CGSize(width: pixelPosition.x - transform.tx, height: pixelPosition.y - transform.ty)
        let translation = context.convertToUserSpace(difference)

        // Work on pixel level.
        context.translateBy(x: translation.width, y: translation.height)
        context.scaleBy(x: 1.0 / renderScale, y: 1.0 / renderScale)

        if renderingStyle == .fill || renderingStyle == .fillStroke {
            context.setFillColor(fillColor.cgColor)
            drawGlyphs(in: context, run: run, kind: Int(TRGlyphImageKindFill))
        }

        if renderingStyle == .stroke || renderingStyle == .fillStroke {
            context.setFillColor(strokeColor.cgColor)
            drawGlyphs(in: context, run: run, kind: Int(TRGlyphImageKindStroke))
        }

        // Reset the scale and the translation.
        context.scaleBy(x: renderScale, y: renderScale)
        context.translateBy(x: -translation.width, y: -translation.height)
    }
}

/// The glyphs of a run, which are copied into arrays that Core can read.
private struct GlyphRunData {
    private var glyphIDs: [GlyphID]
    private var offsets: [TRPoint]
    private var advances: [TRFloat]

    init<GS, OS, AS>(glyphIDs: GS, offsets: OS, advances: AS)
        where GS: Sequence, GS.Element == GlyphID,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        self.glyphIDs = Array(glyphIDs)
        self.offsets = offsets.map { TRPoint(x: TRFloat($0.x), y: TRFloat($0.y)) }
        self.advances = advances.map { TRFloat($0) }

        precondition(self.offsets.count >= self.glyphIDs.count
                     && self.advances.count >= self.glyphIDs.count)
    }

    func withPointers<Result>(_ body: (UnsafePointer<GlyphID>?, UnsafePointer<TRPoint>?,
                                       UnsafePointer<TRFloat>?, TRUInteger) -> Result) -> Result {
        return glyphIDs.withUnsafeBufferPointer { (glyphIDs) in
            offsets.withUnsafeBufferPointer { (offsets) in
                advances.withUnsafeBufferPointer { (advances) in
                    body(glyphIDs.baseAddress, offsets.baseAddress, advances.baseAddress,
                         TRUInteger(glyphIDs.count))
                }
            }
        }
    }
}
