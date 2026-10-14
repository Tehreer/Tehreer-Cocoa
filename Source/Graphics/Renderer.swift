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
/// paths, measure their ink boxes and draw them in a `CGContext` object.
public final class Renderer {
    /// Specifies if the glyph being drawn is filled, stroked, or both.
    public enum DrawStyle: Sendable {
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

    let core: TRRendererRef

    /// The context and the objects of the text while a run, a line or a frame is being drawn, which
    /// the draw callbacks of Core use.
    private var drawingContext: CGContext?
    private var drawingObjects = CoreTextObjects()
    private var drawingColor: (core: TRColor, color: CGColor)?

    /// Creates a renderer.
    public init() {
        core = TRRendererCreate()

        var callbacks = TRDrawCallbacks()
        callbacks.drawGlyphImage = { (user, image, origin, scaleX, scaleY, color, clip) in
            Unmanaged<Renderer>.fromOpaque(user!).takeUnretainedValue()
                .drawGlyphImage(
                    image,
                    origin: origin,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    color: color,
                    clip: clip
                )
        }
        callbacks.fillRect = { (user, rect, color) in
            Unmanaged<Renderer>.fromOpaque(user!).takeUnretainedValue()
                .fillRect(rect, color: color)
        }
        callbacks.drawReplacement = { (user, run, origin) in
            Unmanaged<Renderer>.fromOpaque(user!).takeUnretainedValue()
                .drawReplacement(of: run, origin: origin)
        }

        callbacks.beginShadow = { (user, radius, dx, dy, color) in
            Unmanaged<Renderer>.fromOpaque(user!).takeUnretainedValue()
                .beginShadow(radius: radius, dx: dx, dy: dy, color: color)
        }
        callbacks.endShadow = { (user) in
            Unmanaged<Renderer>.fromOpaque(user!).takeUnretainedValue().endShadow()
        }

        TRRendererSetDrawCallbacks(core, &callbacks, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        TRRendererSetDrawCallbacks(core, nil, nil)
        TRRendererRelease(core)
    }

    /// The cache that this renderer takes the images and outlines of glyphs from. Its default value
    /// is `GlyphCache.default`.
    public var glyphCache: GlyphCache = .default {
        didSet {
            TRRendererSetGlyphCache(core, glyphCache.core)
        }
    }

    /// The typeface, used for drawing glyphs.
    public var typeface: Typeface! = nil {
        didSet {
            TRRendererSetTypeface(core, typeface?.core)
        }
    }

    /// The type size applied on the glyphs while drawing.
    public var typeSize: CGFloat {
        get { CGFloat(TRRendererGetTypeSize(core)) }
        set { TRRendererSetTypeSize(core, TRFloat(newValue)) }
    }

    /// The horizontal scale factor applied on the glyphs while drawing. Its default value is 1.0.
    /// Values greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the
    /// glyphs narrower.
    public var scaleX: CGFloat {
        get { CGFloat(TRRendererGetScaleX(core)) }
        set { TRRendererSetScaleX(core, TRFloat(newValue)) }
    }

    /// The vertical scale factor applied on the glyphs while drawing. Its default value is 1.0.
    /// Values greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the
    /// glyphs narrower.
    public var scaleY: CGFloat {
        get { CGFloat(TRRendererGetScaleY(core)) }
        set { TRRendererSetScaleY(core, TRFloat(newValue)) }
    }

    /// The slant angle for glyphs. Its default value is zero.
    public var slantAngle: CGFloat {
        get { CGFloat(TRRendererGetSkewX(core)) }
        set { TRRendererSetSkewX(core, TRFloat(newValue)) }
    }

    /// The scale factor applied to the glyphs and their metrics such as offsets and advances.
    public var renderScale: CGFloat {
        get { CGFloat(TRRendererGetRenderScale(core)) }
        set { TRRendererSetRenderScale(core, TRFloat(newValue)) }
    }

    /// The direction in which the pen will advance after drawing a glyph. Its default value is
    /// `.leftToRight`.
    public var writingDirection: WritingDirection {
        get { WritingDirection(coreValue: TRRendererGetWritingDirection(core)) }
        set { TRRendererSetWritingDirection(core, newValue.coreValue) }
    }

    /// The fill color for glyphs. Its default value is `.black`.
    public var fillColor: UIColor {
        get { UIColor(coreValue: TRRendererGetForegroundColor(core)) }
        set { TRRendererSetForegroundColor(core, newValue.coreValue) }
    }

    /// The radius, in pixels, for stroking glyphs: how far the stroke reaches from the outline of a
    /// glyph, so a stroked line is twice as wide. Its default value is 0.5.
    public var strokeRadius: CGFloat {
        get { CGFloat(TRRendererGetStrokeRadius(core)) }
        set { TRRendererSetStrokeRadius(core, TRFloat(newValue)) }
    }

    /// The stroke cap style which controls how the start and end of stroked lines and paths are
    /// treated. Its default value is `.butt`.
    public var strokeCap: StrokeCap {
        get { StrokeCap(coreValue: TRRendererGetStrokeCap(core)) }
        set { TRRendererSetStrokeCap(core, newValue.coreValue) }
    }

    /// The stroke join type. Its default value is `.round`.
    public var strokeJoin: StrokeJoin {
        get { StrokeJoin(coreValue: TRRendererGetStrokeJoin(core)) }
        set { TRRendererSetStrokeJoin(core, newValue.coreValue) }
    }

    /// The stroke miter limit in pixels. This is used to control the behavior of miter joins when
    /// the joins angle is sharp.
    public var strokeMiter: CGFloat {
        get { CGFloat(TRRendererGetStrokeMiter(core)) }
        set { TRRendererSetStrokeMiter(core, TRFloat(newValue)) }
    }

    /// The stroke color for glyphs. Its default value is `.black`.
    public var strokeColor: UIColor {
        get { UIColor(coreValue: TRRendererGetStrokeColor(core)) }
        set { TRRendererSetStrokeColor(core, newValue.coreValue) }
    }

    /// The shadow radius, in pixels, used when drawing glyphs. Its default value is
    /// zero. The shadow would be disabled if the value is set to zero.
    public var shadowRadius: CGFloat {
        get { CGFloat(TRRendererGetShadowRadius(core)) }
        set { TRRendererSetShadowRadius(core, TRFloat(newValue)) }
    }

    /// The horizontal shadow offset, in pixels.
    public var shadowDx: CGFloat {
        get { CGFloat(TRRendererGetShadowDx(core)) }
        set { TRRendererSetShadowDx(core, TRFloat(newValue)) }
    }

    /// The vertical shadow offset in pixels.
    public var shadowDy: CGFloat {
        get { CGFloat(TRRendererGetShadowDy(core)) }
        set { TRRendererSetShadowDy(core, TRFloat(newValue)) }
    }

    /// The shadow color.
    public var shadowColor: UIColor {
        get { UIColor(coreValue: TRRendererGetShadowColor(core)) }
        set { TRRendererSetShadowColor(core, newValue.coreValue) }
    }

    /// The style, used for controlling how glyphs should appear while drawing. Its default value is
    /// `.fill`.
    public var drawStyle: DrawStyle {
        get { DrawStyle(coreValue: TRRendererGetDrawStyle(core)) }
        set { TRRendererSetDrawStyle(core, newValue.coreValue) }
    }

    /// A Boolean value that indicates whether the glyphs are big enough to be rendered, which takes
    /// at least one pixel in each direction.
    public var isRenderable: Bool {
        return TRRendererIsRenderable(core) != 0
    }

    /// Creates the layer that fills the specified glyph. The image of a glyph of a bitmap font is
    /// the one of its nearest strike, which is not scaled to the type size.
    ///
    /// - Parameter glyphID: The ID of glyph whose layer is created.
    /// - Returns: The layer of the glyph, or `nil` if there is no typeface or the glyph has no
    ///            image, such as a space.
    public func makeGlyphLayer(glyphID: GlyphID) -> CGLayer? {
        guard let image = TRRendererCopyGlyphImage(core, glyphID) else {
            return nil
        }
        defer { TRGlyphImageRelease(image) }

        return GlyphLayers.layer(of: image)
    }

    /// Creates the layer that is made of the outline of the specified glyph, as stroked with the
    /// stroke settings of this renderer.
    ///
    /// - Parameter glyphID: The ID of glyph whose stroke layer is created.
    /// - Returns: The layer of the stroke, or `nil` if there is no typeface or the glyph has no
    ///            outline.
    public func makeStrokeLayer(glyphID: GlyphID) -> CGLayer? {
        guard let image = TRRendererCopyStrokeImage(core, glyphID) else {
            return nil
        }
        defer { TRGlyphImageRelease(image) }

        return GlyphLayers.layer(of: image)
    }

    /// Generates the path of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose path is generated.
    /// - Returns: The path of the glyph specified by `glyphID`, or `nil` if the glyph has no
    ///            outline, as in a bitmap font.
    public func makePath(glyphID: GlyphID) -> CGPath? {
        guard let corePath = TRRendererCopyGlyphPath(core, glyphID) else {
            return nil
        }
        defer { TRPathRelease(corePath) }

        return CGPath.make(from: corePath, transform: nil)
    }

    /// Calculates the ink box of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose ink box is calculated.
    /// - Returns: A rectangle that tightly encloses the image of the specified glyph when it is
    ///            placed at its pen position.
    public func computeInkBox(forGlyph glyphID: GlyphID) -> CGRect {
        return CGRect(TRRendererGetGlyphInkBox(core, glyphID))
    }

    /// Calculates the ink box of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIDs: The glyph IDs, such as those of a glyph run.
    ///   - offsets: The glyph offsets.
    ///   - advances: The glyph advances.
    /// - Returns: A rectangle that tightly encloses the images of specified glyphs.
    public func computeInkBox(
        forGlyphs glyphIDs: PrimitiveCollection<GlyphID>,
        offsets: PrimitiveCollection<CGPoint>,
        advances: PrimitiveCollection<CGFloat>
    ) -> CGRect {
        let box = withGlyphRun(
            glyphIDs,
            offsets,
            advances
        ) { (glyphIDs, offsets, advances, count) in
            TRRendererGetRunInkBox(core, glyphIDs, offsets, advances, count)
        }

        return CGRect(inkBox: box)
    }

    /// Calculates the ink box of specified glyphs, as the variant for the collections of a glyph run
    /// does.
    public func computeInkBox<GS, OS, AS>(forGlyphs glyphIDs: GS, offsets: OS, advances: AS) -> CGRect
        where GS: RandomAccessCollection, GS.Index == Int, GS.Element == GlyphID,
              OS: RandomAccessCollection, OS.Index == Int, OS.Element == CGPoint,
              AS: RandomAccessCollection, AS.Index == Int, AS.Element == CGFloat {
        return computeInkBox(
            forGlyphs: PrimitiveCollection(glyphIDs),
            offsets: PrimitiveCollection(offsets),
            advances: PrimitiveCollection(advances)
        )
    }

    /// Calls the body with the memory that Core reads for a run of glyphs. The collections of a
    /// glyph run or a shaping result are not copied.
    private func withGlyphRun<Result>(
        _ glyphIDs: PrimitiveCollection<GlyphID>,
        _ offsets: PrimitiveCollection<CGPoint>,
        _ advances: PrimitiveCollection<CGFloat>,
        _ body: (UnsafePointer<GlyphID>?, UnsafePointer<TRPoint>?, UnsafePointer<TRFloat>?, TRUInteger) -> Result
    ) -> Result {
        precondition(offsets.count >= glyphIDs.count && advances.count >= glyphIDs.count)

        return glyphIDs.withCoreBuffer(of: GlyphID.self, convert: { $0 }) { (ids) in
            offsets.withCoreBuffer(of: TRPoint.self, convert: { $0.coreValue }) { (points) in
                advances.withCoreBuffer(of: TRFloat.self, convert: { TRFloat($0) }) { (widths) in
                    body(
                        ids.baseAddress,
                        points.baseAddress,
                        widths.baseAddress,
                        TRUInteger(ids.count)
                    )
                }
            }
        }
    }

    // MARK: Drawing

    /// Draws the layer of a glyph with the current fill color of the context. The layer of a bitmap
    /// font is scaled to match the size that was asked for.
    private static func drawLayer(_ layer: CGLayer, at origin: CGPoint, scaleX: CGFloat,
                                  scaleY: CGFloat, in context: CGContext) {
        let rect = CGRect(
            x: origin.x,
            y: origin.y,
            width: layer.size.width * scaleX,
            height: layer.size.height * scaleY
        )

        context.draw(layer, in: rect)
    }

    /// Draws everything up to `endShadow` into a transparency layer with the shadow, so that a
    /// glyph that is filled and stroked casts one shadow.
    private func beginShadow(radius: TRFloat, dx: TRFloat, dy: TRFloat, color: TRColor) {
        guard let context = drawingContext else {
            return
        }

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: CGFloat(dx), height: CGFloat(dy)),
            blur: CGFloat(radius),
            color: cgColor(of: color)
        )
        context.beginTransparencyLayer(auxiliaryInfo: nil)
    }

    private func endShadow() {
        guard let context = drawingContext else {
            return
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    private func cgColor(of color: TRColor) -> CGColor {
        if let cached = drawingColor, cached.core == color {
            return cached.color
        }

        let cgColor = UIColor(coreValue: color).cgColor
        drawingColor = (color, cgColor)

        return cgColor
    }

    private func drawGlyphImage(_ image: TRGlyphImageRef?, origin: TRPoint, scaleX: TRFloat,
                                scaleY: TRFloat, color: TRColor, clip: UnsafePointer<TRRect>?) {
        guard let context = drawingContext,
              let image = image,
              let layer = GlyphLayers.layer(of: image) else {
            return
        }

        if let clip = clip {
            context.saveGState()
            context.clip(to: CGRect(clip.pointee))
        }

        context.setFillColor(cgColor(of: color))
        Renderer.drawLayer(
            layer,
            at: CGPoint(x: CGFloat(origin.x), y: CGFloat(origin.y)),
            scaleX: CGFloat(scaleX),
            scaleY: CGFloat(scaleY),
            in: context
        )

        if clip != nil {
            context.restoreGState()
        }
    }

    private func fillRect(_ rect: TRRect, color: TRColor) {
        guard let context = drawingContext else {
            return
        }

        context.setFillColor(cgColor(of: color))
        context.fill(CGRect(rect))
    }

    private func drawReplacement(of run: TRGlyphRunRef?, origin: TRPoint) {
        guard let context = drawingContext,
              let run = run,
              let core = TRGlyphRunGetReplacement(run),
              let replacement = drawingObjects.replacements[UnsafeRawPointer(core)] else {
            return
        }

        // The origin is in pixels, but the replacement draws in the user space.
        context.saveGState()
        context.translateBy(x: CGFloat(origin.x), y: CGFloat(origin.y))
        context.scaleBy(x: renderScale, y: renderScale)

        replacement.draw(in: context)

        context.restoreGState()
    }

    /// Works at the level of pixels in the context while the body runs, so that the draw functions
    /// of Core, which pass the positions in pixels, draw at the pixels of the device.
    func withDrawing(in context: CGContext, objects: CoreTextObjects = CoreTextObjects(),
                     _ body: () -> Void) {
        // Extract the pixel level translation.
        let transform = context.userSpaceToDeviceSpaceTransform
        let pixelPosition = CGPoint(x: round(transform.tx), y: round(transform.ty))
        let difference = CGSize(width: pixelPosition.x - transform.tx, height: pixelPosition.y - transform.ty)
        let translation = context.convertToUserSpace(difference)

        context.saveGState()

        // Work on pixel level.
        context.translateBy(x: translation.width, y: translation.height)
        context.scaleBy(x: 1.0 / renderScale, y: 1.0 / renderScale)

        drawingContext = context
        drawingObjects = objects

        body()

        drawingContext = nil
        drawingObjects = CoreTextObjects()

        context.restoreGState()
    }

    private func drawGlyphs(
        in context: CGContext,
        glyphIDs: PrimitiveCollection<GlyphID>,
        offsets: PrimitiveCollection<CGPoint>,
        advances: PrimitiveCollection<CGFloat>,
        kind: Int
    ) {
        withGlyphRun(glyphIDs, offsets, advances) { (glyphIDs, offsets, advances, count) in
            guard count > 0 else {
                return
            }

            let userData = Unmanaged.passUnretained(context).toOpaque()

            TRRendererEnumerateGlyphPlacements(
                core,
                TRGlyphImageKind(kind),
                glyphIDs,
                offsets,
                advances,
                count,
                { (userData, _, image, origin, scaleX, scaleY, _) in
                    guard let image = image,
                          let layer = GlyphLayers.layer(of: image) else {
                        return
                    }

                    let context = Unmanaged<CGContext>.fromOpaque(userData!).takeUnretainedValue()

                    Renderer.drawLayer(
                        layer,
                        at: CGPoint(origin),
                        scaleX: CGFloat(scaleX),
                        scaleY: CGFloat(scaleY),
                        in: context
                    )
                },
                userData
            )
        }
    }

    /// Draws the glyphs in the specified context.
    ///
    /// - Parameters:
    ///   - context: The context onto which to draw the glyphs.
    ///   - glyphIDs: The glyph IDs, such as those of a glyph run.
    ///   - offsets: The glyph offsets.
    ///   - advances: The glyph advances.
    public func drawGlyphs(
        in context: CGContext,
        glyphIDs: PrimitiveCollection<GlyphID>,
        offsets: PrimitiveCollection<CGPoint>,
        advances: PrimitiveCollection<CGFloat>
    ) {
        withDrawing(in: context) {
            let isShadowed = (TRRendererIsRenderable(core) != 0 && shadowRadius > 0.0
                              && shadowRadius.isFinite && shadowDx.isFinite && shadowDy.isFinite)
            if isShadowed {
                beginShadow(
                    radius: TRRendererGetShadowRadius(core),
                    dx: TRRendererGetShadowDx(core),
                    dy: TRRendererGetShadowDy(core),
                    color: TRRendererGetShadowColor(core)
                )
            }

            if drawStyle == .fill || drawStyle == .fillStroke {
                context.setFillColor(fillColor.cgColor)
                drawGlyphs(
                    in: context,
                    glyphIDs: glyphIDs,
                    offsets: offsets,
                    advances: advances,
                    kind: Int(TRGlyphImageKindFill)
                )
            }

            if drawStyle == .stroke || drawStyle == .fillStroke {
                context.setFillColor(strokeColor.cgColor)
                drawGlyphs(
                    in: context,
                    glyphIDs: glyphIDs,
                    offsets: offsets,
                    advances: advances,
                    kind: Int(TRGlyphImageKindStroke)
                )
            }

            if isShadowed {
                endShadow()
            }
        }
    }

    /// Draws the glyphs in the specified context, as the variant for the collections of a glyph run
    /// does.
    public func drawGlyphs<GS, OS, AS>(in context: CGContext, glyphIDs: GS, offsets: OS, advances: AS)
        where GS: RandomAccessCollection, GS.Index == Int, GS.Element == GlyphID,
              OS: RandomAccessCollection, OS.Index == Int, OS.Element == CGPoint,
              AS: RandomAccessCollection, AS.Index == Int, AS.Element == CGFloat {
        drawGlyphs(
            in: context,
            glyphIDs: PrimitiveCollection(glyphIDs),
            offsets: PrimitiveCollection(offsets),
            advances: PrimitiveCollection(advances)
        )
    }

    /// Generates a cumulative path of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIDs: The glyph IDs, such as those of a glyph run.
    ///   - offsets: The glyph offsets.
    ///   - advances: The glyph advances.
    /// - Returns: The cumulative path of specified glyphs.
    public func makePath(
        glyphIDs: PrimitiveCollection<GlyphID>,
        offsets: PrimitiveCollection<CGPoint>,
        advances: PrimitiveCollection<CGFloat>
    ) -> CGPath? {
        let path = CGMutablePath()

        withGlyphRun(glyphIDs, offsets, advances) { (glyphIDs, offsets, advances, count) in
            var callbacks = CGPath.coreCallbacks

            let user = Unmanaged.passUnretained(path).toOpaque()
            TRRendererEnumerateGlyphPaths(core, glyphIDs, offsets, advances, count, &callbacks, user)
        }

        return path
    }

    /// Generates a cumulative path of specified glyphs.
    ///
    /// The collections of a glyph run or a shaping result are read without being copied. Any other
    /// collection is converted into temporary buffers.
    public func makePath<GS, OS, AS>(glyphIDs: GS, offsets: OS, advances: AS) -> CGPath?
        where GS: RandomAccessCollection, GS.Index == Int, GS.Element == GlyphID,
              OS: RandomAccessCollection, OS.Index == Int, OS.Element == CGPoint,
              AS: RandomAccessCollection, AS.Index == Int, AS.Element == CGFloat {
        return makePath(
            glyphIDs: PrimitiveCollection(glyphIDs),
            offsets: PrimitiveCollection(offsets),
            advances: PrimitiveCollection(advances)
        )
    }
}
