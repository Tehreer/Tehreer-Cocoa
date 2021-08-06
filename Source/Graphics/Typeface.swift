//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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
import Foundation
import FreeType
import HarfBuzz
import UIKit

/// An ID of a glyph in a font.
public typealias GlyphID = UInt16

/// A tag of a typeface.
public typealias TypefaceTag = AnyHashable

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
public class Typeface {
    private let instance: IntrinsicFace
    private var colors: [FT_Color] = []

    var tag: TypefaceTag?

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public init?(path: String) {
        guard let fontStream = FontStream(path: path),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0) else {
            return nil
        }

        self.instance = IntrinsicFace(renderableFace: renderableFace)
        setup()
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public init?(data: Data) {
        guard let fontStream = FontStream(data: data),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0) else {
            return nil
        }

        self.instance = IntrinsicFace(renderableFace: renderableFace)
        setup()
    }

    /// Creates a new typeface from the input stream by copying its data into a memory buffer. It
    /// may take some time to create the typeface if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0) else {
            return nil
        }

        self.instance = IntrinsicFace(renderableFace: renderableFace)
        setup()
    }

    init(instance: IntrinsicFace) {
        self.instance = instance
        setup()
    }

    private init(instance: IntrinsicFace, colors: [FT_Color]) {
        self.instance = instance
        self.colors = colors
    }

    private func setup() {
        // Select first pallete by default.
        if let colors = instance.predefinedPalettes.first?.colors {
            self.colors = colors.map { $0.ftColor() }
        }
    }

    func withFreeTypeFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        return try instance.withFreeTypeFace(body)
    }

    func withFreeTypeStroker<Result>(_ body: (FT_Stroker) throws -> Result) rethrows -> Result {
        return try instance.withFreeTypeStroker(body)
    }

    var ftFace: FT_Face {
        return instance.renderableFace.ftFace
    }

    var ftSize: FT_Size {
        return instance.ftSize
    }

    var hbFont: OpaquePointer {
        return instance.shapableFace.hbFont
    }

    var ftColors: [FT_Color] {
        return colors
    }

    /// A Boolean value that indicates whether the typeface supports OpenType font variations.
    public var isVariable: Bool {
        return !variationAxes.isEmpty
    }

    /// Returns a variation instance of this typeface with the specified design coordinates.
    ///
    /// - Parameter coordinates: The variation design coordinates.
    /// - Returns: A variation instance of this typeface with the specified design coordinates.
    public func variationInstance(forCoordinates coordinates: [CGFloat]) -> Typeface? {
        guard let instance = instance.variationInstance(forCoordinates: coordinates) else {
            return nil
        }

        return Typeface(instance: instance, colors: colors)
    }

    /// The variation axes of this typeface.
    public var variationAxes: [VariationAxis] {
        return instance.variationAxes
    }

    /// The design variation coordinates of this typeface.
    public var variationCoordinates: [CGFloat] {
        return instance.variationCoordinates
    }

    /// The names associated with palette entries if this typeface supports OpenType color palettes.
    public var paletteEntryNames: [String] {
        return instance.paletteEntryNames
    }

    /// The predefined palettes in this typeface if it supports OpenType color palettes.
    public var predefinedPalettes: [ColorPalette] {
        return instance.predefinedPalettes
    }

    /// The colors associated with this typeface if it supports OpenType color palettes.
    public var associatedColors: [UIColor] {
        var array: [UIColor] = []
        array.reserveCapacity(colors.count)

        for i in 0 ..< colors.count {
            array.append(UIColor(red: CGFloat(colors[i].red) / 255.0,
                                 green: CGFloat(colors[i].green) / 255.0,
                                 blue: CGFloat(colors[i].blue) / 255.0,
                                 alpha: CGFloat(colors[i].alpha) / 255.0))
        }

        return array
    }

    /// Returns a color instance of this typeface with the specified colors array.
    ///
    /// - Parameter colors: The colors array.
    /// - Returns: A color instance of this typeface with the specified colors array.
    public func colorInstance(forColors colors: [UIColor]) -> Typeface? {
        guard !paletteEntryNames.isEmpty else {
            return nil
        }

        var array = Array<UIColor>(repeating: .black, count: paletteEntryNames.count)
        let count = min(array.count, paletteEntryNames.count)

        for i in 0 ..< count {
            array[i] = colors[i]
        }

        return Typeface(instance: instance, colors: array.map { $0.ftColor() })
    }

    /// The family name of this typeface.
    public var familyName: String {
        return instance.familyName
    }

    /// The style name of this typeface.
    public var styleName: String {
        return instance.styleName
    }

    /// The full name of this typeface.
    public var fullName: String {
        return instance.fullName
    }

    /// The typographic weight of this typeface. The weight value determines the thickness
    /// associated with a given character in a typeface.
    public var weight: Weight {
        return instance.weight
    }

    /// The typographic width of this typeface. The width value determines whether a typeface is
    /// expanded or condensed when it is displayed.
    public var width: Width {
        return instance.width
    }

    /// The typographic slope of this typeface. The slope value determines whether a typeface is
    /// plain or slanted when it is displayed.
    public var slope: Slope {
        return instance.slope
    }

    /// The number of font units per EM square for this typeface.
    public var unitsPerEm: Int {
        return instance.unitsPerEm
    }

    /// The typographic ascender of this typeface expressed in font units.
    public var ascent: Int {
        return instance.ascent
    }

    /// The typographic descender of this typeface expressed in font units.
    public var descent: Int {
        return instance.descent
    }

    /// The typographic leading of this typeface expressed in font units.
    public var leading: Int {
        return instance.leading
    }

    /// The number of glyphs in this typeface.
    public var glyphCount: Int {
        return instance.glyphCount
    }

    /// The font bounding box expressed in font units. The box is large enough to contain any glyph
    /// from the font.
    public var boundingBox: CGRect {
        return instance.boundingBox
    }

    /// The position, in font units, of the underline for this typeface.
    public var underlinePosition: Int {
        return instance.underlinePosition
    }

    /// The thickness, in font units, of the underline for this typeface.
    public var underlineThickness: Int {
        return instance.underlineThickness
    }

    /// The position, in font units, of the strikeout for this typeface.
    public var strikeoutPosition: Int {
        return instance.strikeoutPosition
    }

    /// The thickness, in font units, of the strikeout for this typeface.
    public var strikeoutThickness: Int {
        return instance.strikeoutThickness
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func dataOfTable(_ tag: SFNTTag) -> Data? {
        return instance.renderableFace.dataOfTable(tag)
    }

    /// Returns the glyph id for the specified code point.
    ///
    /// - Parameter codePoint: The code point for which the glyph id is obtained.
    /// - Returns: The glyph id for the specified code point.
    public func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        return instance.glyphID(forCodePoint: codePoint)
    }

    /// Retrieves the advance for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which to retrieve the advance.
    ///   - typeSize: The size for which the advance is retrieved.
    ///   - vertical: The flag which indicates the type of advance, either horizontal or vertical.
    /// - Returns: The advance for the specified glyph.
    public func advance(forGlyph glyphID: GlyphID, typeSize: CGFloat, vertical: Bool) -> CGFloat {
        return instance.advance(forGlyph: glyphID, typeSize: typeSize, vertical: vertical)
    }

    func unsafeMakePath(glyphID: FT_UInt) -> CGPath? {
        return instance.unsafeMakePath(glyphID: glyphID)
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
        return instance.path(forGlyph: glyphID, typeSize: typeSize, transform: transform)
    }
}
