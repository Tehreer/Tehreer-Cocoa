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

    var renderableFace: RenderableFace!
    var ftSize: FT_Size!
    var ftStroker: FT_Stroker!

    var hbFont: OpaquePointer!

    private struct Description {
        var familyIndex: Int?
        var styleIndex: Int?
        var fullIndex: Int?

        var weight: Typeface.Weight = .regular
        var width: Typeface.Width = .normal
        var slope: Typeface.Slope = .plain
    }

    private struct DefaultProperties {
        var description = Description()

        var variationAxes: [VariationAxis] = []
        var paletteEntryNames: [String] = []
        var predefinedPalettes: [ColorPalette] = []
    }

    private var defaults = DefaultProperties()
    private var description = Description()

    var familyName = ""
    var styleName = ""
    var fullName = ""

    var strikeoutPosition: Int = 0
    var strikeoutThickness: Int = 0

    init?(fontStream: FontStream, faceIndex: Int, instanceIndex: Int) {
        guard let renderableFace = fontStream.makeRenderableFace(faceIndex: faceIndex, instanceIndex: instanceIndex) else {
            return nil
        }

        setupFull(fontStream: fontStream, renderableFace: renderableFace)
    }

    init(fontStream: FontStream, renderableFace: RenderableFace) {
        setupFull(fontStream: fontStream, renderableFace: renderableFace)
    }

    init?(parent: Instance, coordinates: [CGFloat]) {
        guard parent.isVariable,
              let fontStream = parent.fontStream,
              let faceIndex = parent.renderableFace?.ftFace.pointee.face_index,
              let renderableFace = fontStream.makeRenderableFace(faceIndex: faceIndex, instanceIndex: 0) else {
            return nil
        }

        let variationAxes = parent.variationAxes

        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: variationAxes.count)
        let numCoords = min(coordinates.count, variationAxes.count)

        for i in 0 ..< numCoords {
            fixedCoords[i] = coordinates[i].f16Dot16
        }

        FT_Set_Var_Design_Coordinates(renderableFace.ftFace, FT_UInt(variationAxes.count), &fixedCoords)

        setupDerived(parent: parent, renderableFace: renderableFace)
    }

    private func setupFull(fontStream: FontStream, renderableFace: RenderableFace) {
        self.fontStream = fontStream
        self.renderableFace = renderableFace

        let ftFace = renderableFace.ftFace
        let headTable = HeadTable(ftFace: ftFace)
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        setupSize()
        setupDescription(headTable: headTable, os2Table: os2Table, nameTable: nameTable)
        setupStrikeout(os2Table: os2Table)
        setupVariation()
        setupHarfBuzz()
        setupAxes(nameTable: nameTable)
        setupPalettes(nameTable: nameTable)
        setupNames(nameTable: nameTable)
    }

    private func setupDerived(parent: Instance, renderableFace: RenderableFace) {
        self.fontStream = parent.fontStream
        self.renderableFace = renderableFace
        self.defaults = parent.defaults

        let ftFace = renderableFace.ftFace
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        setupSize()
        setupStrikeout(os2Table: os2Table)
        setupVariation()
        setupHarfBuzz()
        setupNames(nameTable: nameTable)
    }

    private func setupSize() {
        FT_New_Size(renderableFace.ftFace, &ftSize)
    }

    private func setupDescription(headTable: HeadTable?, os2Table: OS2Table?, nameTable: NameTable?) {
        var description = Description()
        description.familyIndex = nameTable?.indexOfFamilyName(considering: os2Table)
        description.styleIndex = nameTable?.indexOfStyleName(considering: os2Table)
        description.fullIndex = nameTable?.indexOfEnglishName(for: NameTable.NameID.full)

        defer {
            defaults.description = description
        }

        if let os2Table = os2Table {
            description.weight = Typeface.Weight(value: os2Table.usWeightClass)
            description.width = Typeface.Width(value: os2Table.usWidthClass)

            if (os2Table.fsSelection & OS2Table.FSSelection.oblique) != 0 {
                description.slope = .oblique
            } else if (os2Table.fsSelection & OS2Table.FSSelection.italic) != 0 {
                description.slope = .italic
            }
        } else if let headTable = headTable {
            let macStyle = headTable.macStyle

            if (macStyle & OS2Table.MacStyle.bold) != 0 {
                description.weight = .bold
            }

            if (macStyle & OS2Table.MacStyle.condensed) != 0 {
                description.width = .condensed
            } else if (macStyle & OS2Table.MacStyle.extended) != 0 {
                description.width = .expanded
            }

            if (macStyle & OS2Table.MacStyle.italic) != 0 {
                description.slope = .italic
            }
        }
    }

    private func setupStrikeout(os2Table: OS2Table?) {
        if let os2Table = os2Table {
            strikeoutPosition = Int(os2Table.yStrikeoutPosition)
            strikeoutThickness = Int(os2Table.yStrikeoutSize)
        }
    }

    private func setupVariation() {
        let ftFace = renderableFace.ftFace
        var variation: UnsafeMutablePointer<FT_MM_Var>!

        guard FT_Get_MM_Var(ftFace, &variation) == FT_Err_Ok else { return }

        defer {
            FreeType.withLibrary { (library) -> Void in
                FT_Done_MM_Var(library, variation)
            }
        }

        var description = defaults.description
        defer { self.description = description }

        let numCoords = variation.pointee.num_axis
        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: Int(numCoords))

        if FT_Get_Var_Design_Coordinates(ftFace, numCoords, &fixedCoords) == FT_Err_Ok {
            let nameTable = NameTable(ftFace: ftFace)

            // Reset the style name and the full name.
            description.styleIndex = nil
            description.fullIndex = nil

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
                    description.styleIndex = nameTable?.indexOfEnglishName(for: UInt16(namedStyle.strid))
                    break
                }
            }

            // Get the values of variation axes.
            for i in 0 ..< Int(numCoords) {
                let axis = variation.pointee.axis[i]

                switch axis.tag {
                case FT_ULong(SFNTTag(stringLiteral: "ital").rawValue):
                    description.slope = Typeface.Slope(ital: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "slnt").rawValue):
                    description.slope = Typeface.Slope(slnt: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wdth").rawValue):
                    description.width = Typeface.Width(wdth: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wght").rawValue):
                    description.weight = Typeface.Weight(wght: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                default:
                    break
                }
            }
        }
    }

    private func setupHarfBuzz() {
        let object = Unmanaged.passUnretained(self).toOpaque()
        let ftFace = renderableFace.ftFace

        let hbFace = hb_face_create_for_tables({ (face, tag, object) -> OpaquePointer? in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) -> OpaquePointer? in
                var length: FT_ULong = 0
                FT_Load_Sfnt_Table(ftFace, FT_ULong(tag), 0, nil, &length)

                guard length > 0 else {
                    return nil
                }

                let buffer = UnsafeMutablePointer<FT_Byte>.allocate(capacity: Int(length))
                FT_Load_Sfnt_Table(ftFace, FT_ULong(tag), 0, buffer, nil)

                return hb_blob_create(UnsafeRawPointer(buffer).assumingMemoryBound(to: Int8.self),
                                      UInt32(length),
                                      HB_MEMORY_MODE_WRITABLE,
                                      nil,
                                      { $0?.deallocate() })
            }
        }, object, nil)

        hb_face_set_index(hbFace, UInt32(ftFace.pointee.face_index))
        hb_face_set_upem(hbFace, UInt32(ftFace.pointee.units_per_EM))

        let funcs = hb_font_funcs_create()

        hb_font_funcs_set_nominal_glyph_func(funcs, { (font, object, unicode, glyph, userData) -> hb_bool_t in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) in
                let codePoint = FT_ULong(unicode)
                let glyphID = FT_Get_Char_Index(ftFace, codePoint)

                guard glyphID > 0 else {
                    return 0
                }

                glyph?.initialize(to: hb_codepoint_t(glyphID))

                return 1
            }
        }, nil, nil)

        hb_font_funcs_set_nominal_glyphs_func(funcs, { (font, object, count, firstUnicode, unicodeStride, firstGlyph, glyphStride, userData) -> UInt32 in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) in
                var unicodePtr = UnsafeRawPointer(firstUnicode)!
                var glyphPtr = UnsafeMutableRawPointer(firstGlyph)!
                var done: UInt32 = 0

                for _ in 0 ..< count {
                    let unicodeRef = unicodePtr.assumingMemoryBound(to: hb_codepoint_t.self)
                    let glyphRef = glyphPtr.assumingMemoryBound(to: hb_codepoint_t.self)

                    let codePoint = FT_ULong(unicodeRef.pointee)
                    let glyphID = FT_Get_Char_Index(ftFace, codePoint)

                    guard glyphID > 0 else {
                        break
                    }

                    glyphRef.initialize(to: glyphID)

                    unicodePtr = unicodePtr.advanced(by: Int(unicodeStride))
                    glyphPtr = glyphPtr.advanced(by: Int(glyphStride))
                    done += 1
                }

                return done
            }
        }, nil, nil)

        hb_font_funcs_set_variation_glyph_func(funcs, { (font, object, unicode, variationSelector, glyph, userData) -> hb_bool_t in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) in
                let glyphID = FT_Face_GetCharVariantIndex(ftFace, FT_ULong(unicode), FT_ULong(variationSelector))

                guard glyphID > 0 else {
                    return 0
                }

                glyph?.initialize(to: hb_codepoint_t(glyphID))

                return 1
            }
        }, nil, nil)

        hb_font_funcs_set_glyph_h_advance_func(funcs, { (font, object, glyph, userData) -> hb_position_t in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) in
                let loadFlags = FT_Int32(FT_LOAD_NO_SCALE)
                var advance: FT_Fixed = 0

                FT_Get_Advance(ftFace, FT_UInt(glyph), loadFlags, &advance)

                return hb_position_t(advance)
            }
        }, nil, nil)

        hb_font_funcs_set_glyph_h_advances_func(funcs, { (font, object, count, firstGlyph, glyphStride, firstAdvance, advanceStride, userData) in
            let unmanaged = Unmanaged<Instance>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            instance.withFreeTypeFace { (ftFace) in
                var glyphPtr = UnsafeRawPointer(firstGlyph)!
                var advancePtr = UnsafeMutableRawPointer(firstAdvance)!

                let loadFlags = FT_Int32(FT_LOAD_NO_SCALE)
                var advance: FT_Fixed = 0

                for _ in 0 ..< count {
                    let glyphRef = glyphPtr.assumingMemoryBound(to: hb_codepoint_t.self)
                    let advanceRef = advancePtr.assumingMemoryBound(to: hb_position_t.self)

                    let glyph = FT_UInt(glyphRef.pointee)

                    FT_Get_Advance(ftFace, glyph, loadFlags, &advance)
                    advanceRef.initialize(to: hb_position_t(advance))

                    glyphPtr = glyphPtr.advanced(by: Int(glyphStride))
                    advancePtr = advancePtr.advanced(by: Int(advanceStride))
                }
            }
        }, nil, nil)

        hb_font_funcs_make_immutable(funcs)

        hbFont = hb_font_create(hbFace)
        hb_font_set_funcs(hbFont, funcs, object, nil)
    }

    private func setupAxes(nameTable: NameTable?) {
        guard let fvarTable = renderableFace.fvarTable() else { return }

        let axisRecords = fvarTable.axisRecords

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
    }

    private func setupPalettes(nameTable: NameTable?) {
        guard let cpalTable = renderableFace.cpalTable() else { return }

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

    private func setupNames(nameTable: NameTable?) {
        guard let nameTable = nameTable else { return }

        if let index = description.familyIndex {
            familyName = nameTable.record(at: index).string ?? ""
        }
        if let index = description.styleIndex {
            styleName = nameTable.record(at: index).string ?? ""
        }
        if let index = description.fullIndex {
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

    var variationAxes: [VariationAxis] {
        return defaults.variationAxes
    }

    var paletteEntryNames: [String] {
        return defaults.paletteEntryNames
    }

    var predefinedPalettes: [ColorPalette] {
        return defaults.predefinedPalettes
    }

    var weight: Typeface.Weight {
        return description.weight
    }

    var width: Typeface.Width {
        return description.width
    }

    var slope: Typeface.Slope {
        return description.slope
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

    var isVariable: Bool {
        return !variationAxes.isEmpty
    }

    func variationInstance(forCoordinates coordinates: [CGFloat]) -> Instance? {
        return Instance(parent: self, coordinates: coordinates)
    }

    var variationCoordinates: [CGFloat] {
        guard variationAxes.count > 0 else {
            return []
        }

        let rawFace = renderableFace.ftFace
        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: variationAxes.count)
        var coordValues = Array<CGFloat>(repeating: 0, count: variationAxes.count)

        if FT_Get_Var_Design_Coordinates(rawFace, FT_UInt(variationAxes.count), &fixedCoords) == FT_Err_Ok {
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
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, renderableFace: renderableFace)
        setup()
    }

    /// Creates a new typeface from the data of the font.
    ///
    /// - Parameter data: The data of the font.
    public init?(data: Data) {
        guard let fontStream = FontStream(data: data),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, renderableFace: renderableFace)
        setup()
    }

    /// Creates a new typeface from the input stream by copying its data into a memory buffer. It
    /// may take some time to create the typeface if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream),
              let renderableFace = fontStream.makeRenderableFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, renderableFace: renderableFace)
        setup()
    }

    init?(fontStream: FontStream, faceIndex: Int, instanceIndex: Int) {
        guard let renderableFace = fontStream.makeRenderableFace(faceIndex: faceIndex, instanceIndex: instanceIndex) else {
            return nil
        }

        self.instance = Instance(fontStream: fontStream, renderableFace: renderableFace)
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
        return instance.renderableFace.ftFace
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
