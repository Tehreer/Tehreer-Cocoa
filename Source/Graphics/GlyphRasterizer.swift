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

class GlyphRasterizer {
    private static var decode: [CGFloat] = [1.0, 0.0]

    let typeface: Typeface

    private var size: FT_Size!
    private var transform: FT_Matrix

    init(_ key: GlyphKey) {
        self.typeface = key.typeface
        self.transform = FT_Matrix(xx: 0x10000, xy: -key.skewX, yx: 0, yy: 0x10000)

        typeface.withFreeTypeFace { (face) in
            FT_New_Size(face, &size)
            FT_Activate_Size(size)
            FT_Set_Char_Size(face, key.pixelWidth, key.pixelHeight, 0, 0)
        }
    }

    deinit {
        typeface.withFreeTypeFace { _ -> Void in
            FT_Done_Size(size)
        }
    }

    private func activate(for face: FT_Face) {
        FT_Activate_Size(size)
        FT_Set_Transform(face, &transform, nil)
    }

    private func makeImage(bitmap: UnsafePointer<FT_Bitmap>) -> CGImage? {
        let pixelMode = bitmap.pointee.pixel_mode
        var glyphImage: CGImage?

        switch (pixelMode) {
        case UInt8(FT_PIXEL_MODE_GRAY.rawValue):
            let bitmapLength = Int(bitmap.pointee.width * bitmap.pointee.rows)
            if bitmapLength > 0 {
                let data = UnsafeMutablePointer<UInt8>.allocate(capacity: bitmapLength)
                data.assign(from: bitmap.pointee.buffer, count: bitmapLength)

                let provider = CGDataProvider(
                    dataInfo: nil,
                    data: data,
                    size: bitmapLength,
                    releaseData: { (info, data, size) in
                        data.deallocate()
                    })!

                glyphImage = CGImage(
                    maskWidth: Int(bitmap.pointee.width),
                    height: Int(bitmap.pointee.rows),
                    bitsPerComponent: 8,
                    bitsPerPixel: 8,
                    bytesPerRow: Int(bitmap.pointee.width),
                    provider: provider,
                    decode: &GlyphRasterizer.decode,
                    shouldInterpolate: false)
            }

        default:
            print("Unsupported pixel mode of freetype bitmap")
        }

        return glyphImage
    }

    func makeImage(glyphID: GlyphID) -> (image: CGImage?, left: Int, top: Int) {
        var glyphImage: CGImage?
        var left = 0
        var top = 0

        typeface.withFreeTypeFace { (face) in
            activate(for: face)

            if FT_Load_Glyph(face, FT_UInt(glyphID), FT_Int32(FT_LOAD_RENDER)) == FT_Err_Ok {
                let glyphSlot = face.pointee.glyph
                glyphImage = makeImage(bitmap: &glyphSlot!.pointee.bitmap)

                if glyphImage != nil {
                    left = Int(glyphSlot!.pointee.bitmap_left)
                    top = Int(glyphSlot!.pointee.bitmap_top)
                }
            }
        }

        return (glyphImage, left, top)
    }

    func makeOutline(glyphID: GlyphID) -> FT_Glyph? {
        return typeface.withFreeTypeFace { (face) in
            activate(for: face)

            if FT_Load_Glyph(face, FT_UInt(glyphID), FT_Int32(FT_LOAD_NO_BITMAP)) == FT_Err_Ok {
                var outline: FT_Glyph?
                FT_Get_Glyph(face.pointee.glyph, &outline)

                return outline
            }

            return nil
        }
    }

    func makePath(glyphID: GlyphID) -> CGPath? {
        return typeface.withFreeTypeFace { (face) in
            activate(for: face)

            return typeface.unsafeMakePath(glyphID: FT_UInt(glyphID))
        }
    }

    func makeStrokedGlyph(of glyph: Glyph, lineRadius: FT_Fixed, lineCap: FT_Stroker_LineCap,
                          lineJoin: FT_Stroker_LineJoin, miterLimit: FT_Fixed) -> Glyph {
        let result = Glyph(glyphID: glyph.glyphID)
        var baseGlyph = glyph.outline

        if baseGlyph != nil {
            let error = typeface.withFreeTypeStroker { (stroker) -> FT_Error in
                FT_Stroker_Set(stroker, lineRadius, lineCap, lineJoin, miterLimit)

                return FT_Glyph_Stroke(&baseGlyph, stroker, 0)
            }

            if error == FT_Err_Ok {
                FT_Glyph_To_Bitmap(&baseGlyph, FT_RENDER_MODE_NORMAL, nil, 1)

                let bitmapGlyph = UnsafeMutablePointer<FT_BitmapGlyphRec_>(OpaquePointer(baseGlyph))!
                var strokeImage: CGImage? = nil
                var left = 0
                var top = 0

                strokeImage = makeImage(bitmap: &bitmapGlyph.pointee.bitmap)
                if strokeImage != nil {
                    left = Int(bitmapGlyph.pointee.left)
                    top = Int(bitmapGlyph.pointee.top)
                }

                result.own(image: strokeImage, left: left, top: top)

                // Dispose the stroked / bitmap glyph.
                FT_Done_Glyph(baseGlyph)
            }
        }

        return result
    }
}
