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
import UIKit

/// An ID of a glyph in a font.
public typealias GlyphID = UInt16

/// A tag of a typeface.
public typealias TypefaceTag = AnyHashable

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
public class Typeface {
    private let mutex = Mutex()

    var tag: TypefaceTag?

    private var renderableFace: RenderableFace!
    private var ftSize: FT_Size!
    private var ftStroker: FT_Stroker!

    private var shapableFace: ShapableFace!

    private struct DesignCharacteristics {
        var weight: Typeface.Weight = .regular
        var width: Typeface.Width = .normal
        var slope: Typeface.Slope = .plain
    }

    private struct DefaultProperties {
        var names: Names!
        var design: DesignCharacteristics!

        var variationAxes: [VariationAxis] = []
        var namedStyles: [NamedStyle] = []

        var paletteEntryNames: [String] = []
        var predefinedPalettes: [ColorPalette] = []
    }

    private struct Strikeout {
        var position: Int = 0
        var thickness: Int = 0
    }

    private struct Names {
        var family: String = ""
        var style: String = ""
        var full: String = ""
    }

    private struct Palette {
        var colors: [FT_Color] = []
    }

    private var defaults: DefaultProperties!
    private var design: DesignCharacteristics!
    private var strikeout: Strikeout!
    private var names: Names!
    private var palette: Palette!

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public init?(path: String) {
        guard let fontStream = FontStream(path: path),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0) else {
            return nil
        }

        setupFull(renderableFace: renderableFace)
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public init?(data: Data) {
        guard let fontStream = FontStream(data: data),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0) else {
            return nil
        }

        setupFull(renderableFace: renderableFace)
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

        setupFull(renderableFace: renderableFace)
    }

    init?(fontStream: FontStream, faceIndex: Int) {
        guard let renderableFace = fontStream.makeRenderableFace(faceIndex: faceIndex) else {
            return nil
        }

        setupFull(renderableFace: renderableFace)
    }

    init(renderableFace: RenderableFace) {
        setupFull(renderableFace: renderableFace)
    }

    private init(parent: Typeface, renderableFace: RenderableFace) {
        setupDerived(parent: parent, renderableFace: renderableFace)
    }

    private init(parent: Typeface, colors: [FT_Color]) {
        setupDerived(parent: parent, colors: colors)
    }

    private func setupFull(renderableFace: RenderableFace) {
        self.renderableFace = renderableFace
        self.ftSize = nil
        self.ftStroker = nil
        self.shapableFace = nil
        self.defaults = nil
        self.design = nil
        self.strikeout = nil
        self.names = nil
        self.palette = nil

        let ftFace = renderableFace.ftFace
        let headTable = HeadTable(ftFace: ftFace)
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)
        let fvarTable = renderableFace.fvarTable()
        let cpalTable = renderableFace.cpalTable()

        setupSize()
        setupHarfBuzz()
        setupDefaultProperties(headTable: headTable, os2Table: os2Table, nameTable: nameTable,
                               fvarTable: fvarTable, cpalTable: cpalTable)
        setupDesignCharacteristics()
        setupDefaultCoordinates()
        setupStrikeout(os2Table: os2Table)
        setupNames(nameTable: nameTable)
        setupVariableDescription()
        setupDefaultPalette()
    }

    private func setupDerived(parent: Typeface, renderableFace: RenderableFace) {
        self.renderableFace = renderableFace
        self.ftSize = nil
        self.ftStroker = nil
        self.shapableFace = nil
        self.defaults = parent.defaults
        self.design = nil
        self.strikeout = nil
        self.names = nil
        self.palette = parent.palette

        let ftFace = renderableFace.ftFace
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        setupSize()
        setupHarfBuzz(parent: parent)
        setupDesignCharacteristics()
        setupStrikeout(os2Table: os2Table)
        setupNames(nameTable: nameTable)
        setupVariableDescription()
    }

    private func setupDerived(parent: Typeface, colors: [FT_Color]) {
        self.renderableFace = parent.renderableFace
        self.ftSize = nil
        self.ftStroker = nil
        self.shapableFace = parent.shapableFace
        self.defaults = parent.defaults
        self.design = parent.design
        self.strikeout = parent.strikeout
        self.names = parent.names
        self.palette = Palette(colors: colors)

        setupSize()
    }

    private func setupSize() {
        FT_New_Size(renderableFace.ftFace, &ftSize)
    }

    private func setupHarfBuzz(parent: Typeface? = nil) {
        if let parent = parent {
            shapableFace = ShapableFace(parent: parent.shapableFace, renderableFace: renderableFace)
        } else {
            shapableFace = ShapableFace(renderableFace: renderableFace)
        }
    }

    private func setupDefaultProperties(headTable: HeadTable?, os2Table: OS2Table?,
                                        nameTable: NameTable?,
                                        fvarTable: FVAR.Table?, cpalTable: CPAL.Table?) {
        defaults = DefaultProperties()

        setupDefaultDescription(headTable: headTable, os2Table: os2Table, nameTable: nameTable)
        setupVariations(fvarTable: fvarTable, nameTable: nameTable)
        setupPalettes(cpalTable: cpalTable, nameTable: nameTable)
    }

    private func setupDefaultDescription(headTable: HeadTable?, os2Table: OS2Table?, nameTable: NameTable?) {
        var names = Names()
        defer { defaults.names = names }

        if let nameTable = nameTable {
            if let nameIndex = nameTable.indexOfFamilyName(considering: os2Table) {
                names.family = nameTable.record(at: nameIndex).string ?? ""
            }
            if let nameIndex = nameTable.indexOfStyleName(considering: os2Table) {
                names.style = nameTable.record(at: nameIndex).string ?? ""
            }
            if let nameIndex = nameTable.indexOfEnglishName(for: NameTable.NameID.full) {
                names.full = nameTable.record(at: nameIndex).string ?? ""
            }
        }

        var design = DesignCharacteristics()
        defer { defaults.design = design }

        if let os2Table = os2Table {
            design.weight = Typeface.Weight(value: os2Table.usWeightClass)
            design.width = Typeface.Width(value: os2Table.usWidthClass)

            if (os2Table.fsSelection & OS2Table.FSSelection.oblique) != 0 {
                design.slope = .oblique
            } else if (os2Table.fsSelection & OS2Table.FSSelection.italic) != 0 {
                design.slope = .italic
            }
        } else if let headTable = headTable {
            let macStyle = headTable.macStyle

            if (macStyle & OS2Table.MacStyle.bold) != 0 {
                design.weight = .bold
            }

            if (macStyle & OS2Table.MacStyle.condensed) != 0 {
                design.width = .condensed
            } else if (macStyle & OS2Table.MacStyle.extended) != 0 {
                design.width = .expanded
            }

            if (macStyle & OS2Table.MacStyle.italic) != 0 {
                design.slope = .italic
            }
        }
    }

    private func setupVariations(fvarTable: FVAR.Table?, nameTable: NameTable?) {
        guard let fvarTable = fvarTable else { return }

        let axisRecords = fvarTable.axisRecords
        let instanceRecords = fvarTable.instanceRecords

        var variationAxes: [VariationAxis] = []
        variationAxes.reserveCapacity(axisRecords.count)

        defer {
            defaults.variationAxes = variationAxes
        }

        for axisRecord in axisRecords {
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

        var namedStyles: [NamedStyle] = []
        namedStyles.reserveCapacity(instanceRecords.count)

        defer {
            defaults.namedStyles = namedStyles
        }

        var hasDefaultInstance = false

        for instanceRecord in instanceRecords {
            let styleNameID = instanceRecord.subfamilyNameID
            let coordinates = instanceRecord.coordinates.map { CGFloat($0) }
            let postScriptNameID = instanceRecord.postScriptNameID

            var styleName = ""
            var postScriptName: String? = nil

            if let index = nameTable?.indexOfEnglishName(for: styleNameID) {
                styleName = nameTable?.record(at: index).string ?? ""
            }

            if let postScriptNameID = postScriptNameID {
                if let index = nameTable?.indexOfEnglishName(for: postScriptNameID) {
                    postScriptName = nameTable?.record(at: index).string
                }
            }

            if !hasDefaultInstance {
                let minValue = 1.0 / CGFloat(0x10000)
                var matched = true

                // Check if this is the default instance.
                for i in 0 ..< variationAxes.count {
                    if abs(coordinates[i] - variationAxes[i].defaultValue) >= minValue {
                        matched = false
                        break
                    }
                }

                if matched {
                    hasDefaultInstance = true
                }
            }

            let namedStyle = NamedStyle(styleName: styleName,
                                        coordinates: coordinates,
                                        postScriptName: postScriptName)

            namedStyles.append(namedStyle)
        }

        if !hasDefaultInstance {
            let defaultStyle = NamedStyle(styleName: defaults.names.style,
                                          coordinates: variationAxes.map { $0.defaultValue },
                                          postScriptName: nil)

            namedStyles.insert(defaultStyle, at: 0)
        }
    }

    private func setupPalettes(cpalTable: CPAL.Table?, nameTable: NameTable?) {
        guard let cpalTable = cpalTable else { return }

        let numPaletteEntries = Int(cpalTable.numPaletteEntries)
        let numPalettes = Int(cpalTable.numPalettes)

        let colorRecords = cpalTable.colorRecords
        let paletteTypes = cpalTable.paletteTypes
        let paletteLabels = cpalTable.paletteLabels
        let paletteEntryLabels = cpalTable.paletteEntryLabels

        var predefinedPalettes: [ColorPalette] = []
        predefinedPalettes.reserveCapacity(numPalettes)

        defer {
            defaults.predefinedPalettes = predefinedPalettes
        }

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

        var paletteEntryNames: [String] = []
        paletteEntryNames.reserveCapacity(numPaletteEntries)

        defer {
            defaults.paletteEntryNames = paletteEntryNames
        }

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

    private func setupDefaultCoordinates() {
        if !variationAxes.isEmpty {
            renderableFace.setupCoordinates(variationAxes.map { $0.defaultValue })
        }
    }

    private func setupDesignCharacteristics() {
        design = defaults.design
    }

    private func setupStrikeout(os2Table: OS2Table?) {
        strikeout = Strikeout()

        if let os2Table = os2Table {
            strikeout.position = Int(os2Table.yStrikeoutPosition)
            strikeout.thickness = Int(os2Table.yStrikeoutSize)
        }
    }

    private func setupNames(nameTable: NameTable?) {
        names = defaults.names

        if fullName.isEmpty {
            generateFullName()
        }
    }

    private func generateFullName() {
        if !familyName.isEmpty {
            names.full = familyName
            if !styleName.isEmpty {
                names.full += " " + styleName
            }
        } else {
            names.full = styleName
        }
    }

    private func setupVariableDescription() {
        let coordinates = variationCoordinates
        if coordinates.isEmpty {
            return
        }

        if !namedStyles.isEmpty {
            // Reset the style name and the full name.
            names.style = ""
            names.full = ""

            let coordCount = coordinates.count
            let minValue = 1.0 / CGFloat(0x10000)

            // Get the style name of this instance.
            for instance in namedStyles {
                let name = instance.styleName
                if name.isEmpty {
                    continue
                }

                let namedCoords = instance.coordinates
                var matched = true

                for i in 0 ..< coordCount {
                    if abs(coordinates[i] - namedCoords[i]) >= minValue {
                        matched = false
                        break
                    }
                }

                if matched {
                    names.style = instance.styleName
                    generateFullName()
                }
            }
        }

        if !variationAxes.isEmpty {
            let ital: SFNTTag = "ital"
            let slnt: SFNTTag = "slnt"
            let wdth: SFNTTag = "wdth"
            let wght: SFNTTag = "wght"

            // Get the values of variation axes.
            for i in 0 ..< variationAxes.count {
                let axis = variationAxes[i]

                switch axis.tag {
                case ital:
                    design.slope = Typeface.Slope(ital: coordinates[i])
                case slnt:
                    design.slope = Typeface.Slope(slnt: coordinates[i])
                case wdth:
                    design.width = Typeface.Width(wdth: coordinates[i])
                case wght:
                    design.weight = Typeface.Weight(wght: coordinates[i])
                default:
                    break
                }
            }
        }
    }

    private func setupDefaultPalette() {
        palette = Palette()

        // Select first pallete by default.
        if let colors = predefinedPalettes.first?.colors {
            palette.colors = colors.map { $0.ftColor() }
        }
    }

    deinit {
        withFreeTypeFace { _ -> Void in
            FT_Done_Size(ftSize)
        }

        if ftStroker != nil {
            FT_Stroker_Done(ftStroker)
        }
    }

    func withFreeTypeFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        return try renderableFace.withRawFace(body)
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

    var ftFace: FT_Face {
        return renderableFace.ftFace
    }

    var hbFont: OpaquePointer {
        return shapableFace.hbFont
    }

    var ftColors: [FT_Color] {
        return palette.colors
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
        guard isVariable else {
            return nil
        }

        var coordArray = Array<CGFloat>(repeating: 0, count: variationAxes.count)
        let coordCount = min(coordinates.count, variationAxes.count)

        for i in 0 ..< coordCount {
            coordArray[i] = coordinates[i]
        }

        guard let derivedFace = renderableFace.variationInstance(forCoordinates: coordArray) else {
            return nil
        }

        return Typeface(parent: self, renderableFace: derivedFace)
    }

    /// The variation axes of this typeface.
    public var variationAxes: [VariationAxis] {
        return defaults.variationAxes
    }

    /// The named instance records of this typeface.
    public var namedStyles: [NamedStyle] {
        return defaults.namedStyles
    }

    /// The design variation coordinates of this typeface.
    public var variationCoordinates: [CGFloat] {
        return renderableFace.coordinates
    }

    /// The names associated with palette entries if this typeface supports OpenType color palettes.
    public var paletteEntryNames: [String] {
        return defaults.paletteEntryNames
    }

    /// The predefined palettes in this typeface if it supports OpenType color palettes.
    public var predefinedPalettes: [ColorPalette] {
        return defaults.predefinedPalettes
    }

    /// The colors associated with this typeface if it supports OpenType color palettes.
    public var associatedColors: [UIColor] {
        let colors = palette.colors

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

        return Typeface(parent: self, colors: array.map { $0.ftColor() })
    }

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
        return strikeout.position
    }

    /// The thickness, in font units, of the strikeout for this typeface.
    public var strikeoutThickness: Int {
        return strikeout.thickness
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func dataOfTable(_ tag: SFNTTag) -> Data? {
        return renderableFace.dataOfTable(tag)
    }

    /// Returns the glyph id for the specified code point.
    ///
    /// - Parameter codePoint: The code point for which the glyph id is obtained.
    /// - Returns: The glyph id for the specified code point.
    public func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        let glyphID = withFreeTypeFace { (face) in
            FT_Get_Char_Index(face, FT_ULong(codePoint))
        }

        guard glyphID <= 0xFFFF else {
            print("Received invalid glyph id for code point: \(codePoint)")
            return 0
        }

        return GlyphID(glyphID)
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
        let ftFace = renderableFace.ftFace
        let loadFlags = FT_Int32(FT_LOAD_NO_BITMAP)

        guard FT_Load_Glyph(ftFace, glyphID, loadFlags) == FT_Err_Ok else {
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
            var matrix = FT_Matrix(xx: 0x10000, xy: 0, yx: 0, yy: -0x10000)
            var delta = FT_Vector(x: 0, y: 0)

            if let transform = transform {
                let flip = transform.concatenating(CGAffineTransform(scaleX: 1.0, y: -1.0))

                matrix = FT_Matrix(xx: flip.a.f16Dot16, xy: flip.b.f16Dot16,
                                   yx: flip.c.f16Dot16, yy: flip.d.f16Dot16)
                delta = FT_Vector(x: transform.tx.f16Dot16, y: transform.ty.f16Dot16)
            }

            FT_Activate_Size(ftSize)
            FT_Set_Char_Size(face, 0, typeSize.f26Dot6, 0, 0)
            FT_Set_Transform(face, &matrix, &delta)

            return unsafeMakePath(glyphID: FT_UInt(glyphID))
        }
    }
}
