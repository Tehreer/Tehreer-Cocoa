//
// Copyright (C) 2021 Muhammad Tayyab Akram
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

class ShapableFace {
    private static let fontFuncs = makeFontFuncs()

    private let renderableFace: RenderableFace
    private var rootFace: ShapableFace!

    var hbFont: OpaquePointer!

    private static func makeFontFuncs() -> OpaquePointer! {
        let funcs = hb_font_funcs_create()

        hb_font_funcs_set_nominal_glyph_func(funcs, { (font, object, unicode, glyph, userData) -> hb_bool_t in
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
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
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
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
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
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
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
            let instance = unmanaged.takeUnretainedValue()

            return instance.withFreeTypeFace { (ftFace) in
                let loadFlags = FT_Int32(FT_LOAD_NO_SCALE)
                var advance: FT_Fixed = 0

                FT_Get_Advance(ftFace, FT_UInt(glyph), loadFlags, &advance)

                return hb_position_t(advance)
            }
        }, nil, nil)

        hb_font_funcs_set_glyph_h_advances_func(funcs, { (font, object, count, firstGlyph, glyphStride, firstAdvance, advanceStride, userData) in
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
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

        return funcs
    }

    init(renderableFace: RenderableFace) {
        self.renderableFace = renderableFace

        let object = Unmanaged.passUnretained(self).toOpaque()
        let ftFace = renderableFace.ftFace

        let hbFace = hb_face_create_for_tables({ (face, tag, object) -> OpaquePointer? in
            let unmanaged = Unmanaged<ShapableFace>.fromOpaque(object!)
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

        hbFont = hb_font_create(hbFace)
        hb_font_set_funcs(hbFont, Self.fontFuncs, object, nil)

        hb_face_destroy(hbFace)

        setupCoordinates()
    }

    init(parent: ShapableFace, renderableFace: RenderableFace) {
        self.renderableFace = renderableFace
        self.rootFace = parent.rootFace ?? parent

        let object = Unmanaged.passUnretained(self).toOpaque()
        let rootFont = rootFace.hbFont

        hbFont = hb_font_create_sub_font(rootFont)
        hb_font_set_funcs(hbFont, Self.fontFuncs, object, nil)

        setupCoordinates()
    }

    private func setupCoordinates() {
        var coordinates = renderableFace.coordinates.map { Float($0) }

        if !coordinates.isEmpty {
            hb_font_set_var_coords_design(hbFont, &coordinates, UInt32(coordinates.count))
        }
    }

    deinit {
        hb_font_destroy(hbFont)
    }

    func withFreeTypeFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        return try renderableFace.withRawFace(body)
    }
}
