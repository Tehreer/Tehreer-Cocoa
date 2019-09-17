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
import CoreGraphics

fileprivate func toF26Dot6(_ value: CGFloat) -> FT_F26Dot6 {
    return FT_F26Dot6((value * 64) + 0.5)
}

fileprivate func toF16Dot16(_ value: CGFloat) -> FT_Fixed {
    return FT_Fixed((value * 0x10000) + 0.5)
}

fileprivate func f16Dot16toFloat(_ value: FT_Fixed) -> CGFloat {
    return CGFloat(value) / CGFloat(0x10000)
}

fileprivate func f26Dot6PosToFloat(_ value: FT_Pos) -> CGFloat {
    return CGFloat(value) / 64.0
}

public typealias TypefaceTag = AnyHashable

public class Typeface {
    let semaphore = DispatchSemaphore(value: 1)

    private let fontFile: FontFile
    private let ftSize: FT_Size

    var tag: TypefaceTag?

    let ftFace: FT_Face
    var _ftStroker: FT_Stroker!

    var ftStroker: FT_Stroker! {
        // NOTE:
        //      The caller is responsible to wait on semaphore.

        if _ftStroker == nil {
            // There is no need to lock 'library' as it is only taken to have access to FreeType's
            // memory handling functions.
            FT_Stroker_New(FreeType.library, &_ftStroker)
        }

        return _ftStroker
    }

    var sfFont: SFFontRef! = nil
    let patternCache = PatternCache()

    /// Creates a typeface from the specified file. The data for the font is directly read from the
    /// file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public convenience init?(path: String) {
        guard let fontFile = FontFile(path: path) else {
            return nil
        }

        self.init(fontFile: fontFile, faceIndex: 0, instanceIndex: 0)
    }

    /// Creates a typeface from the specified input stream. The data of the stream is not copied
    /// into the memory. Rather, it is directly read from the stream when needed. So the performance
    /// of resulting typeface might be slower and should be used with caution.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public convenience init?(stream: InputStream) {
        guard let fontFile = FontFile(stream: stream) else {
            return nil
        }

        self.init(fontFile: fontFile, faceIndex: 0, instanceIndex: 0)
    }

    private init?(fontFile: FontFile, faceIndex: Int, instanceIndex: Int) {
        guard let ftFace = fontFile.createFTFace(faceIndex: faceIndex, instanceIndex: instanceIndex) else {
            return nil
        }

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

                return typeface.glyphID(for: codepoint)
            },
            getAdvanceForGlyph: { (object, layout, glyphID) in
                let unmanaged = Unmanaged<Typeface>.fromOpaque(object!)
                let typeface = unmanaged.takeUnretainedValue()
                let advance = typeface.fixedAdvance(for: FT_UInt(glyphID),
                                                    vertical: layout == SFFontLayoutVertical)

                return SFInt32(advance)
            }
        )

        var size: FT_Size! = nil
        FT_New_Size(ftFace, &size)

        self.fontFile = fontFile
        self.ftFace = ftFace
        self.ftSize = size
        self.sfFont = SFFontCreateWithProtocol(&fontProtocol, Unmanaged.passUnretained(self).toOpaque())

        setupDescription()
    }

    private func setupDescription() {
        let headTable = HeadTable(typeface: self)
        let os2Table = OS2Table(typeface: self)
        let nameTable = NameTable(typeface: self)

        if let nameTable = nameTable {
            if let familyName = nameTable.suitableFamilyName(considering: os2Table) {
                self.familyName = familyName
            }
            if let styleName = nameTable.suitableStyleName(considering: os2Table) {
                self.styleName = styleName
            }
            if let fullName = nameTable.englishName(for: NameTable.NameID.full.rawValue) {
                self.fullName = fullName
            }
        }

        if let os2Table = os2Table {
            if let weight = TypeWeight(rawValue: Int(os2Table.usWeightClass)) {
                self.weight = weight
            }
            if let width = TypeWidth(rawValue: Int(os2Table.usWidthClass)) {
                self.width = width
            }

            if (os2Table.fsSelection & OS2Table.FSSelection.oblique.rawValue) != 0 {
                self.slope = .oblique
            } else if (os2Table.fsSelection & OS2Table.FSSelection.italic.rawValue) != 0 {
                self.slope = .italic
            }
        } else if let headTable = headTable {
            let macStyle = headTable.macStyle

            if (macStyle & OS2Table.MacStyle.bold.rawValue) != 0 {
                self.weight = .bold
            }

            if (macStyle & OS2Table.MacStyle.condensed.rawValue) != 0 {
                self.width = .condensed
            } else if (macStyle & OS2Table.MacStyle.extended.rawValue) != 0 {
                self.width = .expanded
            }

            if (macStyle & OS2Table.MacStyle.italic.rawValue) != 0 {
                self.slope = .italic
            }
        }
    }

    deinit {
        SFFontRelease(sfFont)

        if let ftStroker = _ftStroker {
            FT_Stroker_Done(ftStroker)
        }

        semaphore.wait()
        FT_Done_Size(ftSize)
        semaphore.signal()

        FreeType.semaphore.wait()
        FT_Done_Face(ftFace)
        FreeType.semaphore.signal()
    }

    /// The family name of this typeface.
    public private(set) var familyName = ""

    /// The style name of this typeface.
    public private(set) var styleName = ""

    /// The full name of this typeface.
    public private(set) var fullName = ""

    /// The typographic weight of this typeface. The weight value determines the thickness
    /// associated with a given character in a typeface.
    public private(set) var weight: TypeWeight = .regular

    /// The typographic width of this typeface. The width value determines whether a typeface is
    /// expanded or condensed when it is displayed.
    public private(set) var width: TypeWidth = .normal

    /// The typographic slope of this typeface. The slope value determines whether a typeface is
    /// plain or slanted when it is displayed.
    public private(set) var slope: TypeSlope = .plain

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

    private func loadSFNTTable(tag: FT_ULong, buffer: UnsafeMutablePointer<FT_Byte>?, length: UnsafeMutablePointer<FT_ULong>?) {
        semaphore.wait()
        defer { semaphore.signal() }

        FT_Load_Sfnt_Table(ftFace, tag, 0, buffer, length)
    }

    /// Returns the data of the table specified by the tag.
    ///
    /// - Parameter tag: The tag of the table.
    /// - Returns: The data of the intended table, or `nil` if no such table exists.
    public func tableData(for tag: SFNTTag) -> Data? {
        let inputTag = FT_ULong(tag.rawValue)
        var length: FT_ULong = 0
        var data: Data? = nil

        semaphore.wait()

        FT_Load_Sfnt_Table(ftFace, inputTag, 0, nil, &length)

        if length > 0 {
            let count = Int(length)
            let bytes = UnsafeMutablePointer<FT_Byte>.allocate(capacity: count)
            FT_Load_Sfnt_Table(ftFace, inputTag, 0, bytes, nil)

            data = Data(bytesNoCopy: bytes, count: count, deallocator: .free)
        }

        semaphore.signal()

        return data
    }

    /// Returns the glyph id for the specified code point.
    ///
    /// - Parameter codePoint: The code point for which the glyph id is obtained.
    /// - Returns: The glyph id for the specified code point.
    public func glyphID(for codePoint: UTF32Char) -> UInt16 {
        semaphore.wait()
        let glyphID = FT_Get_Char_Index(ftFace, FT_ULong(codePoint))
        semaphore.signal()

        guard glyphID <= 0xFFFF else {
            print("Received invalid glyph id for code point: \(codePoint)")
            return 0
        }

        return UInt16(glyphID)
    }

    private func fixedAdvance(for glyphID: FT_UInt, vertical: Bool) -> FT_Fixed {
        var loadFlags: FT_Int32 = FT_Int32(FT_LOAD_NO_SCALE)
        if (vertical) {
            loadFlags |= FT_Int32(FT_LOAD_VERTICAL_LAYOUT)
        }

        semaphore.wait()
        defer { semaphore.signal() }

        var advance: FT_Fixed = 0
        FT_Get_Advance(ftFace, glyphID, loadFlags, &advance)

        return advance
    }

    private func fixedAdvance(for glyphID: FT_UInt, typeSize: FT_F26Dot6, vertical: Bool) -> FT_Fixed {
        var loadFlags: FT_Int32 = FT_LOAD_DEFAULT
        if (vertical) {
            loadFlags |= FT_Int32(FT_LOAD_VERTICAL_LAYOUT)
        }

        semaphore.wait()
        defer { semaphore.signal() }

        FT_Activate_Size(ftSize);
        FT_Set_Char_Size(ftFace, 0, typeSize, 0, 0);
        FT_Set_Transform(ftFace, nil, nil);

        var advance: FT_Fixed = 0
        FT_Get_Advance(ftFace, glyphID, loadFlags, &advance)

        return advance
    }

    /// Retrieves the advance for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which to retrieve the advance.
    ///   - typeSize: The size for which the advance is retrieved.
    ///   - vertical: The flag which indicates the type of advance, either horizontal or vertical.
    /// - Returns: The advance for the specified glyph.
    public func advance(for glyphID: UInt16, typeSize: CGFloat, vertical: Bool) -> CGFloat {
        let advance = fixedAdvance(for: FT_UInt(glyphID),
                                   typeSize: toF26Dot6(typeSize),
                                   vertical: vertical)

        return f16Dot16toFloat(advance)
    }

    func unsafeMakePath(glyphID: FT_UInt) -> CGPath? {
        var glyphPath: CGPath? = nil

        if FT_Load_Glyph(ftFace, glyphID, FT_Int32(FT_LOAD_NO_BITMAP)) == FT_Err_Ok {
            var funcs = FT_Outline_Funcs(
                move_to: { (to, user) -> Int32 in
                    let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                    let path = unmanaged.takeUnretainedValue()
                    let point = CGPoint(x: f26Dot6PosToFloat(to!.pointee.x),
                                        y: f26Dot6PosToFloat(to!.pointee.y))
                    path.move(to: point)

                    return 0
                },
                line_to: { (to, user) -> Int32 in
                    let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                    let path = unmanaged.takeUnretainedValue()
                    let point = CGPoint(x: f26Dot6PosToFloat(to!.pointee.x),
                                        y: f26Dot6PosToFloat(to!.pointee.y))
                    path.addLine(to: point)

                    return 0
                },
                conic_to: { (control1, to, user) -> Int32 in
                    let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                    let path = unmanaged.takeUnretainedValue()
                    let point = CGPoint(x: f26Dot6PosToFloat(to!.pointee.x),
                                        y: f26Dot6PosToFloat(to!.pointee.y))
                    let first = CGPoint(x: f26Dot6PosToFloat(control1!.pointee.x),
                                        y: f26Dot6PosToFloat(control1!.pointee.y))
                    path.addQuadCurve(to: point, control: first)

                    return 0
                },
                cubic_to: { (control1, control2, to, user) -> Int32 in
                    let unmanaged = Unmanaged<CGMutablePath>.fromOpaque(user!)
                    let path = unmanaged.takeUnretainedValue()
                    let point = CGPoint(x: f26Dot6PosToFloat(to!.pointee.x),
                                        y: f26Dot6PosToFloat(to!.pointee.y))
                    let first = CGPoint(x: f26Dot6PosToFloat(control1!.pointee.x),
                                        y: f26Dot6PosToFloat(control1!.pointee.y))
                    let second = CGPoint(x: f26Dot6PosToFloat(control2!.pointee.x),
                                         y: f26Dot6PosToFloat(control2!.pointee.y))
                    path.addCurve(to: point, control1: first, control2: second)

                    return 0
                },
                shift: 0,
                delta: 0
            )

            var outline = ftFace.pointee.glyph.pointee.outline

            let output = CGMutablePath()
            let user = Unmanaged.passUnretained(output).toOpaque()

            if FT_Outline_Decompose(&outline, &funcs, user) == FT_Err_Ok {
                glyphPath = output
            }
        }

        return glyphPath
    }

    /// Generates the path for the specified glyph.
    ///
    /// - Parameters:
    ///   - glyphID: The glyph id for which the path is generated.
    ///   - typeSize: The size for which the glyph path is required.
    ///   - transform: The transform applied to the path. Can be `nil` if no transformation is
    ///                required.
    /// - Returns: The path for the specified glyph.
    public func glyphPath(for glyphID: UInt16, typeSize: CGFloat, transform: CGAffineTransform?) -> CGPath? {
        let fixedSize = toF26Dot6(typeSize)
        var matrix = FT_Matrix(xx: 0x10000, xy: 0, yx: 0, yy: -0x10000)
        var delta = FT_Vector(x: 0, y: 0)

        if let transform = transform {
            let flip = transform.concatenating(CGAffineTransform(scaleX: 1.0, y: -1.0))

            matrix = FT_Matrix(xx: toF16Dot16(flip.a), xy: toF16Dot16(flip.b),
                               yx: toF16Dot16(flip.c), yy: toF16Dot16(flip.d))
            delta = FT_Vector(x: toF16Dot16(transform.tx), y: toF16Dot16(transform.ty))
        }

        semaphore.wait()
        defer { semaphore.signal() }

        FT_Activate_Size(ftSize)
        FT_Set_Char_Size(ftFace, 0, fixedSize, 0, 0)
        FT_Set_Transform(ftFace, &matrix, &delta)

        return unsafeMakePath(glyphID: FT_UInt(glyphID))
    }
}
