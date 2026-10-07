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
import UIKit

/// An ID of a glyph in a font.
public typealias GlyphID = UInt16

/// A tag of a typeface.
public typealias TypefaceTag = AnyHashable

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
// Unchecked because everything is set once in the initializers, except `tag`, which is guarded by
// `TypefaceManager`. The typeface of Core is immutable and safe to use from any thread.
public final class Typeface: @unchecked Sendable {
    var tag: TypefaceTag?

    /// The typeface of Core that answers everything about the font.
    let core: TRTypefaceRef

    private let names: Names
    private let design: DesignCharacteristics

    public let variationAxes: [VariationAxis]
    public let namedStyles: [NamedStyle]
    public let paletteEntryNames: [String]
    public let predefinedPalettes: [ColorPalette]

    private struct DesignCharacteristics {
        var weight: Typeface.Weight
        var width: Typeface.Width
        var slope: Typeface.Slope
    }

    private struct Names {
        var family: String
        var style: String
        var full: String
    }

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public convenience init?(path: String) {
        guard let fontStream = FontStream(path: path) else {
            return nil
        }

        self.init(fontStream: fontStream, faceIndex: 0)
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public convenience init?(data: Data) {
        guard let fontStream = FontStream(data: data) else {
            return nil
        }

        self.init(fontStream: fontStream, faceIndex: 0)
    }

    /// Creates a new typeface from the input stream by copying its data into a memory buffer. It
    /// may take some time to create the typeface if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public convenience init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream) else {
            return nil
        }

        self.init(fontStream: fontStream, faceIndex: 0)
    }

    init?(fontStream: FontStream, faceIndex: Int) {
        guard let core = TRTypefaceCreate(fontStream.coreFile, TRUInteger(faceIndex)) else {
            return nil
        }

        self.core = core
        self.variationAxes = Typeface.makeVariationAxes(core: core)
        self.namedStyles = Typeface.makeNamedStyles(core: core)
        self.paletteEntryNames = Typeface.makePaletteEntryNames(core: core)
        self.predefinedPalettes = Typeface.makePredefinedPalettes(core: core)
        self.names = Typeface.makeNames(core: core)
        self.design = Typeface.makeDesign(core: core)
    }

    private init(parent: Typeface, core: TRTypefaceRef) {
        self.core = core

        self.variationAxes = parent.variationAxes
        self.namedStyles = parent.namedStyles
        self.paletteEntryNames = parent.paletteEntryNames
        self.predefinedPalettes = parent.predefinedPalettes
        self.names = Typeface.makeNames(core: core)
        self.design = Typeface.makeDesign(core: core)
    }

    deinit {
        TRTypefaceRelease(core)
    }

    // MARK: Conversion From Core

    private static func makeVariationAxes(core: TRTypefaceRef) -> [VariationAxis] {
        guard let pointer = TRTypefaceGetVariationAxesPtr(core) else {
            return []
        }

        let axes = UnsafeBufferPointer(start: pointer, count: Int(TRTypefaceGetVariationAxisCount(core)))

        return axes.map { axis in
            VariationAxis(tag: SFNTTag(rawValue: axis.tag)!,
                          name: String(axis.name),
                          flags: VariationAxis.Flags(rawValue: Int(axis.flags)),
                          defaultValue: CGFloat(axis.defaultValue),
                          minValue: CGFloat(axis.minValue),
                          maxValue: CGFloat(axis.maxValue))
        }
    }

    private static func makeNamedStyles(core: TRTypefaceRef) -> [NamedStyle] {
        guard let pointer = TRTypefaceGetNamedStylesPtr(core) else {
            return []
        }

        let styles = UnsafeBufferPointer(start: pointer, count: Int(TRTypefaceGetNamedStyleCount(core)))

        return styles.map { style in
            let coordinates = UnsafeBufferPointer(start: style.coordinatesPtr,
                                                  count: Int(style.coordinateCount))

            return NamedStyle(styleName: String(style.subfamilyName),
                              coordinates: coordinates.map { CGFloat($0) },
                              postScriptName: style.postScriptName.map { String($0) })
        }
    }

    private static func makePaletteEntryNames(core: TRTypefaceRef) -> [String] {
        guard let pointer = TRTypefaceGetPaletteEntriesPtr(core) else {
            return []
        }

        let entries = UnsafeBufferPointer(start: pointer, count: Int(TRTypefaceGetPaletteEntryCount(core)))

        return entries.map { String($0.name) }
    }

    private static func makePredefinedPalettes(core: TRTypefaceRef) -> [ColorPalette] {
        guard let pointer = TRTypefaceGetPredefinedPalettesPtr(core) else {
            return []
        }

        let palettes = UnsafeBufferPointer(start: pointer, count: Int(TRTypefaceGetPredefinedPaletteCount(core)))

        return palettes.map { palette in
            let colors = UnsafeBufferPointer(start: palette.colorsPtr, count: Int(palette.colorCount))

            return ColorPalette(name: String(palette.name),
                                flags: ColorPalette.Flags(rawValue: Int(palette.flags)),
                                colors: colors.map { UIColor(coreColor: $0) })
        }
    }

    private static func makeNames(core: TRTypefaceRef) -> Names {
        return Names(family: String(TRTypefaceGetFamilyName(core)),
                     style: String(TRTypefaceGetSubfamilyName(core)),
                     full: String(TRTypefaceGetFullName(core)))
    }

    private static func makeDesign(core: TRTypefaceRef) -> DesignCharacteristics {
        return DesignCharacteristics(
            weight: Typeface.Weight(rawValue: Int(TRTypefaceGetWeight(core))) ?? .regular,
            width: Typeface.Width(rawValue: Int(TRTypefaceGetWidth(core))) ?? .normal,
            slope: Typeface.Slope(rawValue: Int(TRTypefaceGetSlope(core))) ?? .plain
        )
    }

    // MARK: Variations

    /// A Boolean value that indicates whether the typeface supports OpenType font variations.
    public var isVariable: Bool {
        return !variationAxes.isEmpty
    }

    /// Returns a variation instance of this typeface with the specified design coordinates.
    ///
    /// - Parameter coordinates: The variation design coordinates.
    /// - Returns: A variation instance of this typeface with the specified design coordinates.
    public func variationInstance(forCoordinates coordinates: [CGFloat]) -> Typeface? {
        guard isVariable else {
            return nil
        }

        var coordArray = Array<CGFloat>(repeating: 0, count: variationAxes.count)
        let coordCount = min(coordinates.count, variationAxes.count)

        for i in 0 ..< coordCount {
            coordArray[i] = coordinates[i]
        }

        let floats = coordArray.map { Float($0) }
        guard let derivedCore = TRTypefaceCreateWithVariation(core, floats, TRUInteger(floats.count)) else {
            return nil
        }

        return Typeface(parent: self, core: derivedCore)
    }

    /// The design variation coordinates of this typeface.
    public var variationCoordinates: [CGFloat] {
        guard let pointer = TRTypefaceGetVariationCoordinatesPtr(core) else {
            return []
        }

        let coordinates = UnsafeBufferPointer(start: pointer, count: variationAxes.count)
        return coordinates.map { CGFloat($0) }
    }

    // MARK: Colors

    /// The colors associated with this typeface if it supports OpenType color palettes.
    public var associatedColors: [UIColor] {
        guard let pointer = TRTypefaceGetAssociatedColorsPtr(core) else {
            return []
        }

        let colors = UnsafeBufferPointer(start: pointer, count: paletteEntryNames.count)
        return colors.map { UIColor(coreColor: $0) }
    }

    /// Returns a color instance of this typeface with the specified colors array.
    ///
    /// - Parameter colors: The colors array.
    /// - Returns: A color instance of this typeface with the specified colors array.
    public func colorInstance(forColors colors: [UIColor]) -> Typeface? {
        guard !paletteEntryNames.isEmpty else {
            return nil
        }

        let values = colors.map { $0.coreColor }
        guard let derivedCore = TRTypefaceCreateWithColors(core, values, TRUInteger(values.count)) else {
            return nil
        }

        return Typeface(parent: self, core: derivedCore)
    }

    // MARK: Description

    /// The family name of this typeface.
    public var familyName: String {
        return names.family
    }

    /// The style name of this typeface.
    public var styleName: String {
        return names.style
    }

    /// The full name of this typeface.
    public var fullName: String {
        return names.full
    }

    /// The typographic weight of this typeface. The weight value determines the thickness
    /// associated with a given character in a typeface.
    public var weight: Weight {
        return design.weight
    }

    /// The typographic width of this typeface. The width value determines whether a typeface is
    /// expanded or condensed when it is displayed.
    public var width: Width {
        return design.width
    }

    /// The typographic slope of this typeface. The slope value determines whether a typeface is
    /// plain or slanted when it is displayed.
    public var slope: Slope {
        return design.slope
    }

    // MARK: Metrics

    /// The number of font units per EM square for this typeface.
    public var unitsPerEm: Int {
        return Int(TRTypefaceGetUnitsPerEM(core))
    }

    /// The typographic ascender of this typeface expressed in font units.
    public var ascent: Int {
        return Int(TRTypefaceGetAscent(core))
    }

    /// The typographic descender of this typeface expressed in font units.
    public var descent: Int {
        return Int(TRTypefaceGetDescent(core))
    }

    /// The typographic leading of this typeface expressed in font units.
    public var leading: Int {
        return Int(TRTypefaceGetLeading(core))
    }

    /// The number of glyphs in this typeface.
    public var glyphCount: Int {
        return Int(TRTypefaceGetGlyphCount(core))
    }

    /// The font bounding box expressed in font units. The box is large enough to contain any glyph
    /// from the font.
    public var boundingBox: CGRect {
        let box = TRTypefaceGetBoundingBox(core)

        return CGRect(x: CGFloat(box.origin.x), y: CGFloat(box.origin.y),
                      width: CGFloat(box.size.width), height: CGFloat(box.size.height))
    }

    /// The position, in font units, of the underline for this typeface.
    public var underlinePosition: Int {
        return Int(TRTypefaceGetUnderlinePosition(core))
    }

    /// The thickness, in font units, of the underline for this typeface.
    public var underlineThickness: Int {
        return Int(TRTypefaceGetUnderlineThickness(core))
    }

    /// The position, in font units, of the strikeout for this typeface.
    public var strikeoutPosition: Int {
        return Int(TRTypefaceGetStrikeoutPosition(core))
    }

    /// The thickness, in font units, of the strikeout for this typeface.
    public var strikeoutThickness: Int {
        return Int(TRTypefaceGetStrikeoutThickness(core))
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func dataOfTable(_ tag: SFNTTag) -> Data? {
        let size = Int(TRTypefaceGetTableData(core, tag.rawValue, nil, 0))
        guard size > 0 else {
            return nil
        }

        var data = Data(count: size)
        let copied = data.withUnsafeMutableBytes { (bytes) in
            TRTypefaceGetTableData(core, tag.rawValue, bytes.baseAddress, TRUInteger(size))
        }

        return Int(copied) == size ? data : nil
    }

    // MARK: Glyphs

    /// Returns the glyph id for the specified code point.
    ///
    /// - Parameter codePoint: The code point for which the glyph id is obtained.
    /// - Returns: The glyph id for the specified code point.
    public func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        return TRTypefaceGetGlyphID(core, codePoint)
    }

    /// Retrieves the advance for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which to retrieve the advance.
    ///   - typeSize: The size for which the advance is retrieved.
    ///   - vertical: The flag which indicates the type of advance, either horizontal or vertical.
    /// - Returns: The advance for the specified glyph.
    public func advance(forGlyph glyphID: GlyphID, typeSize: CGFloat, vertical: Bool) -> CGFloat {
        return CGFloat(TRTypefaceGetGlyphAdvance(core, glyphID, TRFloat(typeSize), vertical ? 1 : 0))
    }

    /// Generates the path for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which the path is generated.
    ///   - typeSize: The size for which the glyph path is required.
    ///   - transform: The transform applied to the path. Can be `nil` if no transformation is
    ///                required.
    /// - Returns: The path for the specified glyph.
    public func path(forGlyph glyphID: GlyphID, typeSize: CGFloat, transform: CGAffineTransform?) -> CGPath? {
        guard let corePath = TRTypefaceCreateGlyphPath(core, glyphID, TRFloat(typeSize)) else {
            return nil
        }
        defer { TRPathRelease(corePath) }

        // The path of Core points downward. The transform is meant for the upward path, so it
        // is applied between two flips.
        var matrix = TRAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        if let transform = transform {
            let flip = CGAffineTransform(scaleX: 1.0, y: -1.0)
            let adjusted = flip.concatenating(transform).concatenating(flip)

            matrix = TRAffineTransform(a: TRFloat(adjusted.a), b: TRFloat(adjusted.b),
                                       c: TRFloat(adjusted.c), d: TRFloat(adjusted.d),
                                       tx: TRFloat(adjusted.tx), ty: TRFloat(adjusted.ty))
        }

        let path = CGMutablePath()
        let user = Unmanaged.passUnretained(path).toOpaque()

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

        TRPathEnumerate(corePath, &matrix, &callbacks, user)

        return path
    }
}
