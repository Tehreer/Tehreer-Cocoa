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

private class Instance {
    private let mutex = Mutex()
    private var fontStream: FontStream!

    var ftFace: FT_Face!
    var ftSize: FT_Size!
    var ftStroker: FT_Stroker!

    var hbFont: OpaquePointer!

    struct NameIndexes {
        var family: Int?
        var style: Int?
        var full: Int?
    }
    var nameIndexes = NameIndexes()
    var variationAxes: [VariationAxis] = []

    var paletteEntryNames: [String] = []
    var predefinedPalettes: [ColorPalette] = []

    var familyName = ""
    var styleName = ""
    var fullName = ""

    var weight: Typeface.Weight = .regular
    var width: Typeface.Width = .normal
    var slope: Typeface.Slope = .plain

    var strikeoutPosition: Int = 0
    var strikeoutThickness: Int = 0

    init?(fontStream: FontStream, faceIndex: Int, instanceIndex: Int) {
        guard let ftFace = fontStream.makeFTFace(faceIndex: faceIndex, instanceIndex: instanceIndex) else {
            return nil
        }

        setup(fontStream: fontStream, ftFace: ftFace)
    }

    init(fontStream: FontStream, ftFace: FT_Face) {
        setup(fontStream: fontStream, ftFace: ftFace)
    }

    private func setup(fontStream: FontStream, ftFace: FT_Face) {
        var size: FT_Size! = nil
        FT_New_Size(ftFace, &size)

        self.fontStream = fontStream
        self.ftFace = ftFace
        self.ftSize = size

        setupDescription()
        setupVariation()
        setupHarfBuzz()
        setupAxes()
        setupPalettes()
        setupNames()
    }

    private func setupDescription() {
        let headTable = HeadTable(ftFace: ftFace)
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        nameIndexes.family = nameTable?.indexOfFamilyName(considering: os2Table)
        nameIndexes.style = nameTable?.indexOfStyleName(considering: os2Table)
        nameIndexes.full = nameTable?.indexOfEnglishName(for: NameTable.NameID.full)

        if let os2Table = os2Table {
            weight = Typeface.Weight(value: os2Table.usWeightClass)
            width = Typeface.Width(value: os2Table.usWidthClass)

            if (os2Table.fsSelection & OS2Table.FSSelection.oblique) != 0 {
                slope = .oblique
            } else if (os2Table.fsSelection & OS2Table.FSSelection.italic) != 0 {
                slope = .italic
            }

            strikeoutPosition = Int(os2Table.yStrikeoutPosition)
            strikeoutThickness = Int(os2Table.yStrikeoutSize)
        } else if let headTable = headTable {
            let macStyle = headTable.macStyle

            if (macStyle & OS2Table.MacStyle.bold) != 0 {
                weight = .bold
            }

            if (macStyle & OS2Table.MacStyle.condensed) != 0 {
                width = .condensed
            } else if (macStyle & OS2Table.MacStyle.extended) != 0 {
                width = .expanded
            }

            if (macStyle & OS2Table.MacStyle.italic) != 0 {
                slope = .italic
            }
        }
    }

    private func setupVariation() {
        var variation: UnsafeMutablePointer<FT_MM_Var>!
        guard FT_Get_MM_Var(ftFace, &variation) == FT_Err_Ok else { return }

        defer {
            FreeType.withLibrary { (library) -> Void in
                FT_Done_MM_Var(library, variation)
            }
        }

        let numCoords = variation.pointee.num_axis
        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: Int(numCoords))

        if FT_Get_Var_Design_Coordinates(ftFace, numCoords, &fixedCoords) == FT_Err_Ok {
            let nameTable = NameTable(ftFace: ftFace)

            // Reset the style name and the full name.
            nameIndexes.style = nil
            nameIndexes.full = nil

            // Get the style name of this instance.
            for i in 0 ..< Int(variation.pointee.num_namedstyles) {
                let namedStyle = variation.pointee.namedstyle[i]
                guard let namedCoords = namedStyle.coords else {
                    continue
                }

                let areEqual = fixedCoords.withUnsafeBufferPointer { (pointer) -> Bool in
                    guard let baseAddress = pointer.baseAddress else {
                        return false
                    }

                    let lhs = UnsafeRawPointer(namedCoords)
                    let rhs = UnsafeRawPointer(baseAddress)
                    let size = MemoryLayout<FT_Fixed>.size * Int(numCoords)

                    return memcmp(lhs, rhs, size) == 0
                }

                if areEqual {
                    nameIndexes.style = nameTable?.indexOfEnglishName(for: UInt16(namedStyle.strid))
                    break
                }
            }

            // Get the values of variation axes.
            for i in 0 ..< Int(numCoords) {
                let axis = variation.pointee.axis[i]

                switch axis.tag {
                case FT_ULong(SFNTTag(stringLiteral: "ital").rawValue):
                    slope = Typeface.Slope(ital: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "slnt").rawValue):
                    slope = Typeface.Slope(slnt: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wdth").rawValue):
                    width = Typeface.Width(wdth: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wght").rawValue):
                    weight = Typeface.Weight(wght: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                default:
                    break
                }
            }
        }
    }

    private func setupHarfBuzz() {
        FT_Set_Char_Size(ftFace, 0, Int(ftFace.pointee.units_per_EM), 0, 0)
        hbFont = hb_ft_font_create(ftFace, nil)
    }

    private func setupAxes() {
        guard let fvarData = dataOfTable("fvar") else { return }

        let fvarTable = FVAR.Table(data: fvarData)
        let nameTable = NameTable(ftFace: ftFace)

        for axisRecord in fvarTable.axisRecords {
            let axisTag: SFNTTag! = SFNTTag(rawValue: axisRecord.axisTag)
            let minValue = CGFloat(axisRecord.minValue)
            let defaultValue = CGFloat(axisRecord.defaultValue)
            let maxValue = CGFloat(axisRecord.maxValue)
            let flags = VariationAxis.Flags(rawValue: Int(axisRecord.flags))
            let axisNameId = axisRecord.axisNameId

            var axisName = ""

            if let index = nameTable?.indexOfEnglishName(for: axisNameId) {
                axisName = nameTable?.record(at: index).string ?? ""
            }

            let variationAxis = VariationAxis(tag: axisTag, name: axisName, flags: flags,
                                              defaultValue: defaultValue,
                                              minValue: minValue, maxValue: maxValue)

            variationAxes.append(variationAxis)
        }
    }

    private func setupPalettes() {
        guard let cpalData = dataOfTable("CPAL") else { return }

        let cpalTable = CPAL.Table(data: cpalData)
        let nameTable = NameTable(ftFace: ftFace)

        let numPaletteEntries = Int(cpalTable.numPaletteEntries)
        let numPalettes = Int(cpalTable.numPalettes)

        let colorRecords = cpalTable.colorRecords
        let paletteTypes = cpalTable.paletteTypes
        let paletteLabels = cpalTable.paletteLabels
        let paletteEntryLabels = cpalTable.paletteEntryLabels

        predefinedPalettes.reserveCapacity(numPalettes)

        /* Populate predefined palettes. */
        for i in 0 ..< numPalettes {
            var name = ""
            var flags: ColorPalette.Flags = []
            var colors: [UIColor] = []

            if let paletteLabels = paletteLabels {
                let nameID = paletteLabels[i]

                if nameID != 0xFFFF {
                    if let index = nameTable?.indexOfEnglishName(for: nameID) {
                        name = nameTable?.record(at: index).string ?? ""
                    }
                }
            }

            if let paletteTypes = paletteTypes {
                flags = ColorPalette.Flags(rawValue: Int(paletteTypes[i]))
            }

            let firstColorIndex = cpalTable.colorRecordIndex(at: i)
            for j in 0 ..< numPaletteEntries {
                let record = colorRecords[Int(firstColorIndex) + j]

                colors.append(UIColor(red: CGFloat(record.red) / 255.0,
                                      green: CGFloat(record.green) / 255.0,
                                      blue: CGFloat(record.blue) / 255.0,
                                      alpha: CGFloat(record.alpha) / 255.0))
            }

            predefinedPalettes.append(ColorPalette(name: name, flags: flags, colors: colors))
        }

        paletteEntryNames.reserveCapacity(numPaletteEntries)

        // Populate palette entry names.
        if let paletteEntryLabels = paletteEntryLabels {
            for i in 0 ..< numPaletteEntries {
                let nameID = paletteEntryLabels[i]
                var name = ""

                if nameID != 0xFFFF {
                    if let index = nameTable?.indexOfEnglishName(for: nameID) {
                        name = nameTable?.record(at: index).string ?? ""
                    }
                }

                paletteEntryNames.append(name)
            }
        } else {
            for _ in 0 ..< numPaletteEntries {
                paletteEntryNames.append("")
            }
        }
    }

    private func setupNames() {
        guard let nameTable = NameTable(ftFace: ftFace) else { return }

        if let index = nameIndexes.family {
            familyName = nameTable.record(at: index).string ?? ""
        }
        if let index = nameIndexes.style {
            styleName = nameTable.record(at: index).string ?? ""
        }
        if let index = nameIndexes.full {
            fullName = nameTable.record(at: index).string ?? ""
        } else {
            if !familyName.isEmpty {
                fullName = familyName
                if !styleName.isEmpty {
                    fullName += " " + styleName
                }
            }
        }
    }

    deinit {
        hb_font_destroy(hbFont)

        withFreeTypeFace { _ -> Void in
            FT_Done_Size(ftSize)
        }

        FreeType.withLibrary { _ -> Void in
            if ftStroker != nil {
                FT_Stroker_Done(ftStroker)
            }

            FT_Done_Face(ftFace)
        }
    }

    func withFreeTypeFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        mutex.lock()
        defer { mutex.unlock() }

        return try body(ftFace)
    }

    func withFreeTypeStroker<Result>(_ body: (FT_Stroker) throws -> Result) rethrows -> Result {
        mutex.lock()
        defer { mutex.unlock() }

        if ftStroker == nil {
            FreeType.withLibrary { (library) -> Void in
                if ftStroker == nil {
                    FT_Stroker_New(library, &ftStroker)
                }
            }
        }

        return try body(ftStroker)
    }

    func dataOfTable(_ tag: SFNTTag) -> Data? {
        withFreeTypeFace { (face) in
            let inputTag = FT_ULong(tag.rawValue)
            var length: FT_ULong = 0

            FT_Load_Sfnt_Table(face, inputTag, 0, nil, &length)

            guard length > 0 else {
                return nil
            }

            let count = Int(length)
            let bytes = UnsafeMutablePointer<FT_Byte>.allocate(capacity: count)
            FT_Load_Sfnt_Table(face, inputTag, 0, bytes, nil)

            return Data(bytesNoCopy: bytes, count: count, deallocator: .free)
        }
    }

    func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        let glyphID = withFreeTypeFace { (face) in
            FT_Get_Char_Index(face, FT_ULong(codePoint))
        }

        guard glyphID <= 0xFFFF else {
            print("Received invalid glyph id for code point: \(codePoint)")
            return 0
        }

        return GlyphID(glyphID)
    }

    func variationInstance(forCoordinates coordinates: [CGFloat]) -> Instance? {
        guard !variationAxes.isEmpty else {
            return nil
        }
        guard let ftFace = fontStream.makeFTFace(faceIndex: ftFace.pointee.face_index, instanceIndex: 0) else {
            return nil
        }

        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: variationAxes.count)
        let numCoords = min(coordinates.count, variationAxes.count)

        for i in 0 ..< numCoords {
            fixedCoords[i] = coordinates[i].f16Dot16
        }

        FT_Set_Var_Design_Coordinates(ftFace, FT_UInt(variationAxes.count), &fixedCoords)

        return Instance(fontStream: fontStream, ftFace: ftFace)
    }

    var variationCoordinates: [CGFloat] {
        guard variationAxes.count > 0 else {
            return []
        }

        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: variationAxes.count)
        var coordValues = Array<CGFloat>(repeating: 0, count: variationAxes.count)

        if FT_Get_Var_Design_Coordinates(ftFace, FT_UInt(variationAxes.count), &fixedCoords) == FT_Err_Ok {
            for i in 0 ..< variationAxes.count {
                coordValues[i] = CGFloat(f16Dot16: fixedCoords[i])
            }
        }

        return coordValues
    }
}

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
public class Typeface {
    private let instance: Instance
    private var colors: [FT_Color] = []

    var tag: TypefaceTag?

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public init?(path: String) {
        guard let fontStream = FontStream(path: path),
              let ftFace = fontStream.makeFTFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, ftFace: ftFace)
        setup()
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public init?(data: Data) {
        guard let fontStream = FontStream(data: data),
              let ftFace = fontStream.makeFTFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, ftFace: ftFace)
        setup()
    }

    /// Creates a new typeface from the input stream by copying its data into a memory buffer. It
    /// may take some time to create the typeface if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream),
              let ftFace = fontStream.makeFTFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, ftFace: ftFace)
        setup()
    }

    init?(fontStream: FontStream, faceIndex: Int, instanceIndex: Int) {
        guard let ftFace = fontStream.makeFTFace(faceIndex: faceIndex, instanceIndex: instanceIndex) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, ftFace: ftFace)
        setup()
    }

    private init(instance: Instance) {
        self.instance = instance
        setup()
    }

    private init(instance: Instance, colors: [FT_Color]) {
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
        return instance.ftFace
    }

    var ftSize: FT_Size {
        return instance.ftSize
    }

    var hbFont: OpaquePointer {
        return instance.hbFont
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

    /// Returns a variation instance of this typeface with the specified design coordinates.
    ///
    /// - Parameter coordinates: The variation design coordinates.
    /// - Returns: A variation instance of this typeface with the specified design coordinates.
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
        return Int(ftFace.pointee.units_per_EM)
    }

    /// The typographic ascender of this typeface expressed in font units.
    public var ascent: Int {
        return Int(ftFace.pointee.ascender)
    }

    /// The typographic descender of this typeface expressed in font units.
    public var descent: Int {
        return Int(-ftFace.pointee.descender)
    }

    /// The typographic leading of this typeface expressed in font units.
    public var leading: Int {
        let ascender = ftFace.pointee.ascender
        let descender = ftFace.pointee.descender
        let height = ftFace.pointee.height

        return Int(height - (ascender - descender))
    }

    /// The number of glyphs in this typeface.
    public var glyphCount: Int {
        return ftFace.pointee.num_glyphs
    }

    /// The font bounding box expressed in font units. The box is large enough to contain any glyph
    /// from the font.
    public var boundingBox: CGRect {
        let bbox: FT_BBox = ftFace.pointee.bbox

        return CGRect(x: bbox.xMin,
                      y: bbox.yMin,
                      width: bbox.xMax - bbox.xMin,
                      height: bbox.yMax - bbox.yMin)
    }

    /// The position, in font units, of the underline for this typeface.
    public var underlinePosition: Int {
        return Int(ftFace.pointee.underline_position)
    }

    /// The thickness, in font units, of the underline for this typeface.
    public var underlineThickness: Int {
        return Int(ftFace.pointee.underline_thickness)
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
        return instance.dataOfTable(tag)
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
        withFreeTypeFace { (face) in
            FT_Activate_Size(ftSize)
            FT_Set_Char_Size(face, 0, typeSize.f26Dot6, 0, 0)
            FT_Set_Transform(face, nil, nil)

            var loadFlags: FT_Int32 = FT_LOAD_DEFAULT
            if (vertical) {
                loadFlags |= FT_Int32(FT_LOAD_VERTICAL_LAYOUT)
            }

            var advance: FT_Fixed = 0
            FT_Get_Advance(face, FT_UInt(glyphID), loadFlags, &advance)

            return CGFloat(f16Dot16: advance)
        }
    }

    func unsafeMakePath(glyphID: FT_UInt) -> CGPath? {
        guard FT_Load_Glyph(ftFace, glyphID, FT_Int32(FT_LOAD_NO_BITMAP)) == FT_Err_Ok else {
            return nil
        }

        var outline = ftFace.pointee.glyph.pointee.outline
        var funcs = FT_Outline_Funcs(
            move_to: { (to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: CGFloat(f26Dot6: to!.pointee.x),
                                    y: CGFloat(f26Dot6: to!.pointee.y))
                path.move(to: point)

                return 0
            },
            line_to: { (to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: CGFloat(f26Dot6: to!.pointee.x),
                                    y: CGFloat(f26Dot6: to!.pointee.y))
                path.addLine(to: point)

                return 0
            },
            conic_to: { (control1, to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: CGFloat(f26Dot6: to!.pointee.x),
                                    y: CGFloat(f26Dot6: to!.pointee.y))
                let first = CGPoint(x: CGFloat(f26Dot6: control1!.pointee.x),
                                    y: CGFloat(f26Dot6: control1!.pointee.y))
                path.addQuadCurve(to: point, control: first)

                return 0
            },
            cubic_to: { (control1, control2, to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: CGFloat(f26Dot6: to!.pointee.x),
                                    y: CGFloat(f26Dot6: to!.pointee.y))
                let first = CGPoint(x: CGFloat(f26Dot6: control1!.pointee.x),
                                    y: CGFloat(f26Dot6: control1!.pointee.y))
                let second = CGPoint(x: CGFloat(f26Dot6: control2!.pointee.x),
                                     y: CGFloat(f26Dot6: control2!.pointee.y))
                path.addCurve(to: point, control1: first, control2: second)

                return 0
            },
            shift: 0,
            delta: 0
        )

        let path = CGMutablePath()
        let user = Unmanaged.passUnretained(path).toOpaque()

        guard FT_Outline_Decompose(&outline, &funcs, user) == FT_Err_Ok else {
            return nil
        }

        return path
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
        withFreeTypeFace { (face) -> CGPath? in
            let fixedSize = typeSize.f26Dot6
            var matrix = FT_Matrix(xx: 0x10000, xy: 0, yx: 0, yy: -0x10000)
            var delta = FT_Vector(x: 0, y: 0)

            if let transform = transform {
                let flip = transform.concatenating(CGAffineTransform(scaleX: 1.0, y: -1.0))

                matrix = FT_Matrix(xx: flip.a.f16Dot16, xy: flip.b.f16Dot16,
                                   yx: flip.c.f16Dot16, yy: flip.d.f16Dot16)
                delta = FT_Vector(x: transform.tx.f16Dot16, y: transform.ty.f16Dot16)
            }

            FT_Activate_Size(ftSize)
            FT_Set_Char_Size(face, 0, fixedSize, 0, 0)
            FT_Set_Transform(face, &matrix, &delta)

            return unsafeMakePath(glyphID: FT_UInt(glyphID))
        }
    }
}
