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

import CoreGraphics
import Foundation

class GlyphRasterizer {
    let typeface: Typeface

    private var size: FT_Size!
    private var transform: FT_Matrix

    init(_ strike: GlyphStrike) {
        self.typeface = strike.typeface
        self.transform = FT_Matrix(xx:0x10000, xy:-strike.skewX, yx:0, yy:0x10000)

        typeface.semaphore.wait()

        let ftFace = typeface.ftFace

        FT_New_Size(ftFace, &size)
        FT_Activate_Size(size)
        FT_Set_Char_Size(ftFace, strike.pixelWidth, strike.pixelHeight, 0, 0)

        typeface.semaphore.signal()
    }

    deinit {
        typeface.semaphore.wait()
        defer { typeface.semaphore.signal() }

        FT_Done_Size(size)
    }

    private func unsafeActivate() {
        FT_Activate_Size(size)
        FT_Set_Transform(typeface.ftFace, &transform, nil)
    }

    private func unsafeCreateImage(bitmap: UnsafePointer<FT_Bitmap>) -> CGImage? {
        let pixelMode = bitmap.pointee.pixel_mode
        var glyphImage: CGImage? = nil

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
                    decode: nil,
                    shouldInterpolate: false)
            }

        default:
            print("Unsupported pixel mode of freetype bitmap")
        }

        return glyphImage
    }

    func loadImage(in glyph: Glyph) {
        let glyphID = FT_UInt(glyph.glyphID)
        var glyphImage: CGImage? = nil
        var left = 0
        var top = 0

        typeface.semaphore.wait()
        unsafeActivate()

        let ftFace = typeface.ftFace
        let error = FT_Load_Glyph(ftFace, glyphID, FT_Int32(FT_LOAD_RENDER))

        if error == FT_Err_Ok {
            let glyphSlot = ftFace.pointee.glyph
            glyphImage = unsafeCreateImage(bitmap: &glyphSlot!.pointee.bitmap)

            if glyphImage != nil {
                left = Int(glyphSlot!.pointee.bitmap_left)
                top = Int(glyphSlot!.pointee.bitmap_top)
            }
        }

        typeface.semaphore.signal()

        glyph.own(image: glyphImage, left: left, top: top)
    }

    func loadOutline(in glyph: Glyph) {
        let glyphID = FT_UInt(glyph.glyphID)
        var outline: FT_Glyph? = nil

        typeface.semaphore.wait()
        unsafeActivate()

        let ftFace = typeface.ftFace
        let error = FT_Load_Glyph(ftFace, glyphID, FT_Int32(FT_LOAD_NO_BITMAP))

        if error == FT_Err_Ok {
            FT_Get_Glyph(ftFace.pointee.glyph, &outline)
        }

        typeface.semaphore.signal()

        glyph.own(outline: outline)
    }

    func loadPath(in glyph: Glyph) {
        let glyphID = FT_UInt(glyph.glyphID)

        typeface.semaphore.wait()
        unsafeActivate()

        let glyphPath = typeface.unsafeMakePath(glyphID: glyphID)

        typeface.semaphore.signal()

        glyph.own(path: glyphPath)
    }

    func stroked(glyph: Glyph, lineRadius: FT_Fixed,
                 lineCap: FT_Stroker_LineCap, lineJoin: FT_Stroker_LineJoin, miterLimit: FT_Fixed) -> Glyph {
        let result = Glyph(glyphID: glyph.glyphID)
        var baseGlyph = glyph.outline

        if baseGlyph != nil {
            typeface.semaphore.wait()

            let stroker = typeface.ftStroker
            FT_Stroker_Set(stroker, lineRadius, lineCap, lineJoin, miterLimit);
            let error = FT_Glyph_Stroke(&baseGlyph, stroker, 0)

            typeface.semaphore.signal()

            if (error == FT_Err_Ok) {
                FT_Glyph_To_Bitmap(&baseGlyph, FT_RENDER_MODE_NORMAL, nil, 1)

                let bitmapGlyph = UnsafeMutablePointer<FT_BitmapGlyphRec_>(OpaquePointer(baseGlyph))!
                var strokeImage: CGImage? = nil
                var leftSideBearing = 0
                var topSideBearing = 0

                strokeImage = unsafeCreateImage(bitmap: &bitmapGlyph.pointee.bitmap)
                if strokeImage != nil {
                    leftSideBearing = Int(bitmapGlyph.pointee.left)
                    topSideBearing = Int(bitmapGlyph.pointee.top)
                }

                result.own(image: strokeImage, left: leftSideBearing, top: topSideBearing)

                // Dispose the stroked / bitmap glyph.
                FT_Done_Glyph(baseGlyph)
            }
        }

        return result
    }
}
