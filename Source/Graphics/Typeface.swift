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

/// A tag that identifies a registered typeface. It is a positive integer, and zero means none.
public typealias TypefaceTag = Int

/// An ID of a family of typefaces. It is a positive integer, and zero means none.
public typealias TypeFamilyID = Int

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
///
/// Everything a typeface tells is read from Core when it is asked for, or the first time it is, in
/// a thread safe manner. The typeface of Core is immutable and safe to use from any thread.
// Unchecked because everything is set once in the initializers.
public final class Typeface: @unchecked Sendable {
    /// The typeface of Core that answers everything about the font.
    let core: TRTypefaceRef

    private struct Names {
        var family: String
        var style: String
        var full: String
    }

    private let names = Lazy<Names>()

    /// Creates a typeface from the first typeface of the specified file. The data for the font is
    /// directly read from the file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public convenience init?(path: String) {
        guard let fontStream = FontStream(path: path) else {
            return nil
        }

        self.init(fontStream: fontStream)
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public convenience init?(data: Data) {
        guard let fontStream = FontStream(data: data) else {
            return nil
        }

        self.init(fontStream: fontStream)
    }

    /// Creates a new typeface from the input stream by copying its data into a memory buffer. It
    /// may take some time to create the typeface if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public convenience init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream) else {
            return nil
        }

        self.init(fontStream: fontStream)
    }

    /// Creates a typeface from the first default typeface of the font file of Core.
    convenience init?(fontStream: FontStream) {
        guard let core = fontStream.coreTypeface(at: 0) else {
            return nil
        }

        self.init(retaining: core)
    }

    /// Creates a typeface that retains the typeface of Core, so it can outlive its font file.
    init(retaining core: TRTypefaceRef) {
        self.core = TRTypefaceRetain(core)!
    }

    /// Creates a typeface that takes over the reference of the typeface of Core.
    private init(owning core: TRTypefaceRef) {
        self.core = core
    }

    deinit {
        TRTypefaceRelease(core)
    }

    // MARK: Variations

    /// A Boolean value that indicates whether the typeface supports OpenType font variations.
    public var isVariable: Bool {
        return TRTypefaceGetVariationAxisCount(core) > 0
    }

    /// The variation axes of this typeface, which is empty if it is not variable.
    public var variationAxes: PrimitiveCollection<VariationAxis> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetVariationAxesPtr(core),
            count: Int(TRTypefaceGetVariationAxisCount(core))
        ) {
            VariationAxis(owner: self, axis: $0)
        })
    }

    /// The named styles of this typeface, which is empty if it has none.
    public var namedStyles: PrimitiveCollection<NamedStyle> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetNamedStylesPtr(core),
            count: Int(TRTypefaceGetNamedStyleCount(core))
        ) {
            NamedStyle(owner: self, style: $0)
        })
    }

    /// Returns a variation instance of this typeface with the specified design coordinates.
    ///
    /// - Parameter coordinates: The variation design coordinates.
    /// - Returns: A variation instance of this typeface with the specified design coordinates, or
    ///            `nil` if this typeface is not variable.
    public func variationInstance(forCoordinates coordinates: [CGFloat]) -> Typeface? {
        guard isVariable else {
            return nil
        }

        let floats = coordinates.map { TRFloat($0) }
        guard let derivedCore = TRTypefaceCreateWithVariation(core, floats, TRUInteger(floats.count)) else {
            return nil
        }

        return Typeface(owning: derivedCore)
    }

    /// The design variation coordinates of this typeface.
    public var variationCoordinates: PrimitiveCollection<CGFloat> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetVariationCoordinatesPtr(core),
            count: Int(TRTypefaceGetVariationAxisCount(core))
        ) {
            CGFloat($0)
        })
    }

    // MARK: Colors

    /// The names of the palette entries of this typeface, which is empty if it has no color
    /// palettes.
    public var paletteEntryNames: PrimitiveCollection<String> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetPaletteEntriesPtr(core),
            count: Int(TRTypefaceGetPaletteEntryCount(core))
        ) {
            String($0.name)
        })
    }

    /// The predefined color palettes of this typeface.
    public var predefinedPalettes: PrimitiveCollection<ColorPalette> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetPredefinedPalettesPtr(core),
            count: Int(TRTypefaceGetPredefinedPaletteCount(core))
        ) {
            ColorPalette(owner: self, palette: $0)
        })
    }

    /// The colors associated with this typeface if it supports OpenType color palettes.
    public var associatedColors: PrimitiveCollection<UIColor> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetAssociatedColorsPtr(core),
            count: Int(TRTypefaceGetPaletteEntryCount(core))
        ) {
            UIColor(coreValue: $0)
        })
    }

    /// Returns a color instance of this typeface with the specified colors array.
    ///
    /// - Parameter colors: The colors array.
    /// - Returns: A color instance of this typeface with the specified colors array, or `nil` if
    ///            this typeface has no color palettes.
    public func colorInstance(forColors colors: [UIColor]) -> Typeface? {
        guard TRTypefaceGetPaletteEntryCount(core) > 0 else {
            return nil
        }

        let values = colors.map { $0.coreValue }
        guard let derivedCore = TRTypefaceCreateWithColors(core, values, TRUInteger(values.count)) else {
            return nil
        }

        return Typeface(owning: derivedCore)
    }

    // MARK: Description

    private var lazyNames: Names {
        return names.get {
            Names(
                family: String(TRTypefaceGetFamilyName(core)),
                style: String(TRTypefaceGetSubfamilyName(core)),
                full: String(TRTypefaceGetFullName(core))
            )
        }
    }

    /// The family name of this typeface.
    public var familyName: String {
        return lazyNames.family
    }

    /// The style name of this typeface.
    public var styleName: String {
        return lazyNames.style
    }

    /// The full name of this typeface.
    public var fullName: String {
        return lazyNames.full
    }

    /// The typographic weight of this typeface. The weight value determines the thickness
    /// associated with a given character in a typeface.
    public var weight: Weight {
        return Weight(coreValue: TRTypefaceGetWeight(core))
    }

    /// The typographic width of this typeface. The width value determines whether a typeface is
    /// expanded or condensed when it is displayed.
    public var width: Width {
        return Width(coreValue: TRTypefaceGetWidth(core))
    }

    /// The typographic slope of this typeface. The slope value determines whether a typeface is
    /// plain or slanted when it is displayed.
    public var slope: Slope {
        return Slope(coreValue: TRTypefaceGetSlope(core))
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
        return CGRect(TRTypefaceGetBoundingBox(core))
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

    /// A Boolean value that indicates whether the glyphs of this typeface have outlines. The glyphs
    /// of a typeface that is not scalable, such as a color emoji font with bitmaps only, have
    /// images at the sizes of its bitmap strikes.
    public var isScalable: Bool {
        return TRTypefaceIsScalable(core) != 0
    }

    /// The sizes at which this typeface has the images of its glyphs, which is empty for a typeface
    /// that has none.
    public var bitmapStrikes: PrimitiveCollection<BitmapStrike> {
        return PrimitiveCollection(CoreCollection(
            owner: self,
            pointer: TRTypefaceGetBitmapStrikesPtr(core),
            count: Int(TRTypefaceGetBitmapStrikeCount(core))
        ) {
            BitmapStrike(pixelWidth: CGFloat($0.pixelWidth), pixelHeight: CGFloat($0.pixelHeight))
        })
    }

    // MARK: Tables

    /// Returns the size of the table specified by the tag, without reading it.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The size of the table in bytes, which is zero if no such table exists.
    public func sizeOfTable(_ tag: SFNTTag) -> Int {
        return Int(TRTypefaceGetTableSize(core, tag.rawValue))
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func dataOfTable(_ tag: SFNTTag) -> Data? {
        return dataOfTable(tag, offset: 0, length: sizeOfTable(tag))
    }

    /// Returns a part of the data of the table specified by the tag. Only the part that is asked
    /// for is read from the font, so a part of a big table is cheap.
    ///
    /// - Parameters:
    ///   - tag: The tag of the table.
    ///   - offset: The offset in the table from where to copy, in bytes.
    ///   - length: The maximum number of bytes to copy. A part that goes beyond the end of the
    ///             table is cut short.
    /// - Returns: The data copied from the table, or `nil` if no such table exists or the offset is
    ///            not within it.
    public func dataOfTable(_ tag: SFNTTag, offset: Int, length: Int) -> Data? {
        precondition(offset >= 0 && length >= 0, .indexOutOfRange)

        guard length > 0 else {
            return nil
        }

        var data = Data(count: length)
        let copied = data.withUnsafeMutableBytes { (bytes) in
            Int(TRTypefaceGetTableData(
                core,
                tag.rawValue,
                TRUInteger(offset),
                bytes.baseAddress,
                TRUInteger(length)
            ))
        }

        guard copied > 0 else {
            return nil
        }

        data.removeSubrange(copied...)
        return data
    }

    // MARK: Glyphs

    /// Returns the glyph id for the specified code point.
    ///
    /// - Parameter codePoint: The code point for which the glyph id is obtained.
    /// - Returns: The glyph id for the specified code point.
    public func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        return TRTypefaceGetGlyphID(core, codePoint)
    }

    /// Returns the glyph id for the specified code point followed by a variation selector.
    ///
    /// - Parameters:
    ///   - codePoint: The code point for which the glyph id is obtained.
    ///   - selector: The variation selector that follows the code point.
    /// - Returns: The glyph id of the variant, or zero if the typeface has no such variant.
    public func variantGlyphID(forCodePoint codePoint: UTF32Char, selector: UTF32Char) -> GlyphID {
        return TRTypefaceGetVariantGlyphID(core, codePoint, selector)
    }

    /// Returns the name that the font gives to a glyph in its post table, or its charset if it is
    /// a CFF font.
    ///
    /// - Parameter glyphID: The id of the glyph.
    /// - Returns: The name of the glyph, or `nil` if the font has none for it.
    public func glyphName(forGlyph glyphID: GlyphID) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = Int(TRTypefaceGetGlyphName(core, glyphID, &buffer, TRUInteger(buffer.count)))

        return length > 0 ? String(coreCharacters: buffer, length: length) : nil
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
        var matrix = CGAffineTransform.identity.coreValue
        if let transform = transform {
            let flip = CGAffineTransform(scaleX: 1.0, y: -1.0)

            matrix = flip.concatenating(transform).concatenating(flip).coreValue
        }

        return CGPath.make(from: corePath, transform: &matrix)
    }
}
