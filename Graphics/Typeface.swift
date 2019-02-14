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

public class Typeface {
    let semaphore = DispatchSemaphore(value: 1)

    private let fontFile: FontFile
    private let ftSize: FT_Size

    let ftFace: FT_Face
    var sfFont: SFFontRef! = nil

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

                var tableSize = FT_ULong(0)
                typeface.loadSFNTTable(tag: FT_ULong(tag),
                                       buffer: buffer,
                                       length: &tableSize)

                if let length = length {
                    length[0] = tableSize
                }
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
    }

    deinit {
        SFFontRelease(sfFont)

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
        var loadFlags: FT_Int32 = FT_LOAD_DEFAULT
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
}
