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
import SheenFigure

private func toF26Dot6(_ value: CGFloat) -> FT_F26Dot6 {
    return FT_F26Dot6((value * 64) + 0.5)
}

private func toF16Dot16(_ value: CGFloat) -> FT_Fixed {
    return FT_Fixed((value * 0x10000) + 0.5)
}

private func f16Dot16ToFloat(_ value: FT_Fixed) -> CGFloat {
    return CGFloat(value) / CGFloat(0x10000)
}

private func f26Dot6ToFloat(_ value: FT_Pos) -> CGFloat {
    return CGFloat(value) / 64.0
}

/// An ID of a glyph in a font.
public typealias GlyphID = UInt16

/// A tag of a typeface.
public typealias TypefaceTag = AnyHashable

/// The `Typeface` class specifies the typeface and intrinsic style of a font. This is used in the
/// renderer, along with optionally `Renderer` settings like `typeSize`, `slantAngle`, `scaleX`, to
/// specify how text appears when drawn (and measured).
public class Typeface {
    /// Specifies the wideness of a typeface, in terms of the width of characters in relation to
    /// their heights.
    public enum Width: Int {
        case ultraCondensed = 1
        case extraCondensed = 2
        case condensed = 3
        case semiCondensed = 4
        case normal = 5
        case semiExpanded = 6
        case expanded = 7
        case extraExpanded = 8
        case ultraExpanded = 9

        static let allValues: [Typeface.Width] = [
            .ultraCondensed, .extraCondensed, .condensed,
            .semiCondensed, .normal, .semiExpanded,
            .expanded, .extraExpanded, .ultraExpanded
        ]

        init(value: UInt16) {
            let index = Int(value - 1)
            self = Typeface.Width.allValues[max(0, min(8, index))]
        }

        init(wdth: FT_Fixed) {
            let value = f16Dot16ToFloat(wdth)
            var width: UInt16

            if (value < 50) {
                width = 1
            } else if (value < 125) {
                width = UInt16(((value - 50) / 12.5) + 1)
            } else if (value < 200) {
                width = UInt16(((value - 125) / 25) + 7)
            } else {
                width = 9
            }

            self.init(value: width)
        }
    }

    /// Specifies the slope of a typeface.
    public enum Slope: Int {
        /// The plain slope indicating upright characters.
        case plain = 0
        /// The italic slope indicating truly slanted characters which appear as they were designed.
        case italic = 1
        /// The oblique slope indicating artificially slanted characters.
        case oblique = 2

        init(ital: FT_Fixed) {
            self = ital >= 0x10000 ? .italic : .plain
        }

        init(slnt: FT_Fixed) {
            self = slnt != 0 ? .oblique : .plain
        }
    }

    private let mutex = Mutex()
    private var fontStream: FontStream!

    var tag: TypefaceTag?

    var ftFace: FT_Face!
    private var ftSize: FT_Size!
    private var ftStroker: FT_Stroker!

    var sfFont: SFFontRef!
    let patternCache = PatternCache()

    struct NameIndexes {
        var family: Int?
        var style: Int?
        var full: Int?
    }
    private var nameIndexes = NameIndexes()

    struct Variation {
        var axes: [VariationAxis]?
    }
    private var variation = Variation()

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public init?(path: String) {
        guard let fontStream = FontStream(path: path),
              let ftFace = fontStream.makeFTFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        setup(fontStream: fontStream, ftFace: ftFace)
    }

    public init?(data: Data) {
        guard let fontStream = FontStream(data: data),
              let ftFace = fontStream.makeFTFace(faceIndex: 0, instanceIndex: 0) else {
            return nil
        }

        setup(fontStream: fontStream, ftFace: ftFace)
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

        setup(fontStream: fontStream, ftFace: ftFace)
    }

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
        var fontProtocol = SFFontProtocol(
            finalize: nil,
            loadTable: { (object, tag, buffer, length) in
                let unmanaged = Unmanaged<Typeface>.fromOpaque(object!)
                let typeface = unmanaged.takeUnretainedValue()

                typeface.loadSFNTTable(tag: FT_ULong(tag),
                                       buffer: buffer,
                                       length: length)
            },
            getGlyphIDForCodepoint: { (object, codepoint) in
                let unmanaged = Unmanaged<Typeface>.fromOpaque(object!)
                let typeface = unmanaged.takeUnretainedValue()

                return typeface.glyphID(forCodePoint: codepoint)
            },
            getAdvanceForGlyph: { (object, layout, glyphID) in
                let unmanaged = Unmanaged<Typeface>.fromOpaque(object!)
                let typeface = unmanaged.takeUnretainedValue()
                let advance = typeface.unscaledAdvance(forGlyph: FT_UInt(glyphID),
                                                       vertical: layout == SFFontLayoutVertical)

                return SFInt32(advance)
            }
        )

        var size: FT_Size! = nil
        FT_New_Size(ftFace, &size)

        self.fontStream = fontStream
        self.ftFace = ftFace
        self.ftSize = size
        self.sfFont = SFFontCreateWithProtocol(&fontProtocol, Unmanaged.passUnretained(self).toOpaque())

        setupDescription()
        setupVariation()
        setupAxes()
        setupNames()
    }

    private func setupDescription() {
        let headTable = HeadTable(typeface: self)
        let os2Table = OS2Table(typeface: self)
        let nameTable = NameTable(typeface: self)

        nameIndexes.family = nameTable?.indexOfFamilyName(considering: os2Table)
        nameIndexes.style = nameTable?.indexOfStyleName(considering: os2Table)
        nameIndexes.full = nameTable?.indexOfEnglishName(for: NameTable.NameID.full)

        if let os2Table = os2Table {
            if let value = Weight(rawValue: Int(os2Table.usWeightClass)) {
                weight = value
            }
            if let value = Width(rawValue: Int(os2Table.usWidthClass)) {
                width = value
            }

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

        if FT_Get_Var_Blend_Coordinates(ftFace, numCoords, &fixedCoords) == FT_Err_Ok {
            let normalFont = sfFont
            var coordArray = Array<SFInt16>(repeating: 0, count: Int(numCoords))

            // Convert the FreeType's F16DOT16 coordinates to standard normalized F2DOT14 format.
            for i in 0 ..< Int(numCoords) {
                coordArray[i] = SFInt16(fixedCoords[i] >> 2)
            }

            // Derive the variable font of SheenFigure.
            sfFont = SFFontCreateWithVariationCoordinates(normalFont, Unmanaged.passUnretained(self).toOpaque(), &coordArray, SFUInteger(numCoords))
            SFFontRelease(normalFont)
        }

        if FT_Get_Var_Design_Coordinates(ftFace, numCoords, &fixedCoords) == FT_Err_Ok {
            let nameTable = NameTable(typeface: self)

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
                    slope = Slope(ital: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "slnt").rawValue):
                    slope = Slope(slnt: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wdth").rawValue):
                    width = Width(wdth: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wght").rawValue):
                    weight = Weight(wght: f16Dot16ToFloat(fixedCoords[i]))
                    break

                default:
                    break
                }
            }
        }
    }

    private func setupAxes() {
        guard let fvarTable = FVAR.Table(typeface: self) else { return }

        let nameTable = NameTable(typeface: self)

        variation.axes = []

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

            variation.axes?.append(variationAxis)
        }
    }

    private func setupNames() {
        guard let nameTable = NameTable(typeface: self) else { return }

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
        SFFontRelease(sfFont)

        mutex.synchronized {
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
        if ftStroker == nil {
            mutex.lock()
            defer { mutex.unlock() }

            if ftStroker == nil {
                FreeType.withLibrary { (library) -> Void in
                    FT_Stroker_New(library, &ftStroker)
                }
            }
        }

        return try body(ftStroker)
    }

    public var isVariable: Bool {
        return variation.axes != nil
    }

    public func variationInstance(forCoordinates coordinates: [CGFloat]) -> Typeface? {
        guard let axes = variation.axes else {
            return nil
        }
        guard let ftFace = fontStream.makeFTFace(faceIndex: ftFace.pointee.face_index, instanceIndex: 0) else {
            return nil
        }

        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: axes.count)
        let numCoords = min(coordinates.count, axes.count)

        for i in 0 ..< numCoords {
            fixedCoords[i] = toF16Dot16(coordinates[i])
        }

        FT_Set_Var_Design_Coordinates(ftFace, FT_UInt(axes.count), &fixedCoords)

        return Typeface(fontStream: fontStream, ftFace: ftFace)
    }

    public var variationAxes: [VariationAxis]? {
        return variation.axes
    }

    public var variationCoordinates: [CGFloat]? {
        guard let axes = variation.axes else {
            return nil
        }

        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: axes.count)
        var coordValues = Array<CGFloat>(repeating: 0, count: axes.count)

        if FT_Get_Var_Design_Coordinates(ftFace, FT_UInt(axes.count), &fixedCoords) == FT_Err_Ok {
            for i in 0 ..< axes.count {
                coordValues[i] = f16Dot16ToFloat(fixedCoords[i])
            }
        }

        return coordValues
    }

    /// The family name of this typeface.
    public private(set) var familyName = ""

    /// The style name of this typeface.
    public private(set) var styleName = ""

    /// The full name of this typeface.
    public private(set) var fullName = ""

    /// The typographic weight of this typeface. The weight value determines the thickness
    /// associated with a given character in a typeface.
    public private(set) var weight: Weight = .regular

    /// The typographic width of this typeface. The width value determines whether a typeface is
    /// expanded or condensed when it is displayed.
    public private(set) var width: Width = .normal

    /// The typographic slope of this typeface. The slope value determines whether a typeface is
    /// plain or slanted when it is displayed.
    public private(set) var slope: Slope = .plain

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
    public var underlineThicknes: Int {
        return Int(ftFace.pointee.underline_thickness)
    }

    /// The position, in font units, of the strikeout for this typeface.
    public private(set) var strikeoutPosition: Int = 0

    /// The thickness, in font units, of the strikeout for this typeface.
    public private(set) var strikeoutThickness: Int = 0

    private func loadSFNTTable(tag: FT_ULong, buffer: UnsafeMutablePointer<FT_Byte>?, length: UnsafeMutablePointer<FT_ULong>?) {
        withFreeTypeFace { (face) -> Void in
            FT_Load_Sfnt_Table(face, tag, 0, buffer, length)
        }
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func dataOfTable(_ tag: SFNTTag) -> Data? {
        let inputTag = FT_ULong(tag.rawValue)

        return withFreeTypeFace { (face) in
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

    private func unscaledAdvance(forGlyph glyphID: FT_UInt, vertical: Bool) -> FT_Fixed {
        var loadFlags: FT_Int32 = FT_Int32(FT_LOAD_NO_SCALE)
        if (vertical) {
            loadFlags |= FT_Int32(FT_LOAD_VERTICAL_LAYOUT)
        }

        return withFreeTypeFace { (face) in
            var advance: FT_Fixed = 0
            FT_Get_Advance(face, glyphID, loadFlags, &advance)

            return advance
        }
    }

    private func fixedAdvance(forGlyph glyphID: FT_UInt, typeSize: FT_F26Dot6, vertical: Bool) -> FT_Fixed {
        var loadFlags: FT_Int32 = FT_LOAD_DEFAULT
        if (vertical) {
            loadFlags |= FT_Int32(FT_LOAD_VERTICAL_LAYOUT)
        }

        return withFreeTypeFace { (face) in
            FT_Activate_Size(ftSize);
            FT_Set_Char_Size(face, 0, typeSize, 0, 0);
            FT_Set_Transform(face, nil, nil);

            var advance: FT_Fixed = 0
            FT_Get_Advance(face, glyphID, loadFlags, &advance)

            return advance
        }
    }

    /// Retrieves the advance for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which to retrieve the advance.
    ///   - typeSize: The size for which the advance is retrieved.
    ///   - vertical: The flag which indicates the type of advance, either horizontal or vertical.
    /// - Returns: The advance for the specified glyph.
    public func advance(forGlyph glyphID: GlyphID, typeSize: CGFloat, vertical: Bool) -> CGFloat {
        let advance = fixedAdvance(forGlyph: FT_UInt(glyphID),
                                   typeSize: toF26Dot6(typeSize),
                                   vertical: vertical)

        return f16Dot16ToFloat(advance)
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
                let point = CGPoint(x: f26Dot6ToFloat(to!.pointee.x),
                                    y: f26Dot6ToFloat(to!.pointee.y))
                path.move(to: point)

                return 0
            },
            line_to: { (to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: f26Dot6ToFloat(to!.pointee.x),
                                    y: f26Dot6ToFloat(to!.pointee.y))
                path.addLine(to: point)

                return 0
            },
            conic_to: { (control1, to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: f26Dot6ToFloat(to!.pointee.x),
                                    y: f26Dot6ToFloat(to!.pointee.y))
                let first = CGPoint(x: f26Dot6ToFloat(control1!.pointee.x),
                                    y: f26Dot6ToFloat(control1!.pointee.y))
                path.addQuadCurve(to: point, control: first)

                return 0
            },
            cubic_to: { (control1, control2, to, user) -> Int32 in
                let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                let path = unmanaged.takeUnretainedValue()
                let point = CGPoint(x: f26Dot6ToFloat(to!.pointee.x),
                                    y: f26Dot6ToFloat(to!.pointee.y))
                let first = CGPoint(x: f26Dot6ToFloat(control1!.pointee.x),
                                    y: f26Dot6ToFloat(control1!.pointee.y))
                let second = CGPoint(x: f26Dot6ToFloat(control2!.pointee.x),
                                     y: f26Dot6ToFloat(control2!.pointee.y))
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
        let fixedSize = toF26Dot6(typeSize)
        var matrix = FT_Matrix(xx: 0x10000, xy: 0, yx: 0, yy: -0x10000)
        var delta = FT_Vector(x: 0, y: 0)

        if let transform = transform {
            let flip = transform.concatenating(CGAffineTransform(scaleX: 1.0, y: -1.0))

            matrix = FT_Matrix(xx: toF16Dot16(flip.a), xy: toF16Dot16(flip.b),
                               yx: toF16Dot16(flip.c), yy: toF16Dot16(flip.d))
            delta = FT_Vector(x: toF16Dot16(transform.tx), y: toF16Dot16(transform.ty))
        }

        return withFreeTypeFace { (face) -> CGPath? in
            FT_Activate_Size(ftSize)
            FT_Set_Char_Size(face, 0, fixedSize, 0, 0)
            FT_Set_Transform(face, &matrix, &delta)

            return unsafeMakePath(glyphID: FT_UInt(glyphID))
        }
    }
}
