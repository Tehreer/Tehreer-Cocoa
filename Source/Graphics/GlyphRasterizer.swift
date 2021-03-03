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

private func freetypeBitmapInfo() -> CGBitmapInfo {
    let byteOrder = CFByteOrderGetCurrent()

    if byteOrder == CFByteOrderLittleEndian.rawValue {
        return CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue
                                    | CGImageAlphaInfo.premultipliedFirst.rawValue)
    }

    if byteOrder == CFByteOrderBigEndian.rawValue {
        return CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                                    | CGImageAlphaInfo.premultipliedFirst.rawValue)
    }

    // FIXME: Need to copy the bitmap data in this case.
    return .byteOrderMask
}

class GlyphRasterizer {
    private static var maskDecode: [CGFloat] = [1.0, 0.0]
    private static let maskSpace = CGColorSpaceCreateDeviceGray()

    private static let rgbSpace = CGColorSpaceCreateDeviceRGB()
    private static let rgbBitmapInfo = freetypeBitmapInfo()

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

    private func activate(face: FT_Face, colors: [FT_Color]? = nil) {
        activate(face: face, transform: &transform, colors: colors)
    }

    private func activate(face: FT_Face, transform: inout FT_Matrix, colors: [FT_Color]? = nil) {
        FT_Activate_Size(size)
        FT_Set_Transform(face, &transform, nil)

        if let colors = colors, !colors.isEmpty {
            var input: UnsafeMutablePointer<FT_Color>?
            FT_Palette_Select(face, 0, &input)

            if let input = input {
                colors.withUnsafeBufferPointer { pointer in
                    guard let baseAddress = pointer.baseAddress else {
                        return
                    }

                    input.assign(from: baseAddress, count: pointer.count)
                }
            }
        }
    }

    private func makeLayer(bitmap: UnsafePointer<FT_Bitmap>) -> CGLayer? {
        switch bitmap.pointee.pixel_mode {
        case UInt8(FT_PIXEL_MODE_GRAY.rawValue):
            let bitmapLength = Int(bitmap.pointee.width * bitmap.pointee.rows)
            guard bitmapLength > 0 else {
                return nil
            }
            guard let data = bitmap.pointee.buffer else {
                return nil
            }
            guard let provider = CGDataProvider(
                    dataInfo: nil,
                    data: data,
                    size: bitmapLength,
                    releaseData: { (info, data, size) in }) else {
                return nil
            }
            guard let mask = CGImage(
                    maskWidth: Int(bitmap.pointee.width),
                    height: Int(bitmap.pointee.rows),
                    bitsPerComponent: 8,
                    bitsPerPixel: 8,
                    bytesPerRow: Int(bitmap.pointee.width),
                    provider: provider,
                    decode: &Self.maskDecode,
                    shouldInterpolate: false) else {
                return nil
            }
            guard let context = CGContext(
                    data: data,
                    width: Int(bitmap.pointee.width),
                    height: Int(bitmap.pointee.rows),
                    bitsPerComponent: 8,
                    bytesPerRow: Int(bitmap.pointee.width),
                    space: Self.maskSpace,
                    bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else {
                return nil
            }

            let rect = CGRect(x: 0.0, y: 0.0,
                              width: CGFloat(bitmap.pointee.width),
                              height: CGFloat(bitmap.pointee.rows))

            let glyphLayer = CGLayer(context, size: rect.size, auxiliaryInfo: nil)

            let glyphContext = glyphLayer?.context
            glyphContext?.translateBy(x: 0, y: rect.height)
            glyphContext?.scaleBy(x: 1.0, y: -1.0)
            glyphContext?.draw(mask, in: rect)

            return glyphLayer

        case UInt8(FT_PIXEL_MODE_BGRA.rawValue):
            let bitmapLength = Int(bitmap.pointee.width * bitmap.pointee.rows * 4)
            guard bitmapLength > 0 else {
                return nil
            }
            guard let data = bitmap.pointee.buffer else {
                return nil
            }
            guard let provider = CGDataProvider(
                    dataInfo: nil,
                    data: data,
                    size: bitmapLength,
                    releaseData: { (info, data, size) in }) else {
                return nil
            }
            guard let image = CGImage(
                    width: Int(bitmap.pointee.width),
                    height: Int(bitmap.pointee.rows),
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: Int(bitmap.pointee.width * 4),
                    space: Self.rgbSpace,
                    bitmapInfo: Self.rgbBitmapInfo,
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent) else {
                return nil
            }
            guard let context = CGContext(
                    data: data,
                    width: Int(bitmap.pointee.width),
                    height: Int(bitmap.pointee.rows),
                    bitsPerComponent: 8,
                    bytesPerRow: Int(bitmap.pointee.width * 4),
                    space: Self.rgbSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                return nil
            }

            let rect = CGRect(x: 0.0, y: 0.0,
                              width: CGFloat(bitmap.pointee.width),
                              height: CGFloat(bitmap.pointee.rows))

            let glyphLayer = CGLayer(context, size: rect.size, auxiliaryInfo: nil)

            let glyphContext = glyphLayer?.context
            glyphContext?.translateBy(x: 0, y: rect.height)
            glyphContext?.scaleBy(x: 1.0, y: -1.0)
            glyphContext?.draw(image, in: rect)

            return glyphLayer

        default:
            print("Unsupported pixel mode of freetype bitmap")
            return nil
        }
    }

    func getType(forGlyph glyphID: GlyphID) -> GlyphType {
        typeface.withFreeTypeFace { (face) -> GlyphType in
            var iterator = FT_LayerIterator()
            iterator.p = nil

            var layerGlyphID: FT_UInt = 0
            var colorIndex: FT_UInt = 0

            var isColored = false
            var hasMask = false

            while FT_Get_Color_Glyph_Layer(face, FT_UInt(glyphID), &layerGlyphID, &colorIndex, &iterator) != 0 {
                isColored = true

                if colorIndex == 0xFFFF {
                    hasMask = true
                    break
                }
            }

            if !isColored {
                return .mask
            }
            if !hasMask {
                return .color
            }

            return .mixed
        }
    }

    func makeImage(glyphID: GlyphID, foregroundColor: FT_Color = FT_Color(blue: 0, green: 0, red: 0, alpha: 0)) -> GlyphImage? {
        typeface.withFreeTypeFace { (face) in
            activate(face: face, colors: typeface.ftColors)

            FT_Palette_Set_Foreground_Color(face, foregroundColor)

            let inputGlyph = FT_UInt(glyphID)
            let loadFlags = FT_Int32(FT_LOAD_COLOR | FT_LOAD_RENDER)

            guard FT_Load_Glyph(face, inputGlyph, loadFlags) == FT_Err_Ok else {
                return nil
            }

            guard let glyphSlot = face.pointee.glyph,
                  let glyphLayer = makeLayer(bitmap: &glyphSlot.pointee.bitmap) else {
                return nil
            }

            return GlyphImage(layer: glyphLayer,
                              left: CGFloat(glyphSlot.pointee.bitmap_left),
                              top: CGFloat(glyphSlot.pointee.bitmap_top))
        }
    }

    func makeStrokeImage(glyph: FT_Glyph, lineRadius: FT_Fixed, lineCap: FT_Stroker_LineCap,
                         lineJoin: FT_Stroker_LineJoin, miterLimit: FT_Fixed) -> GlyphImage? {
        var baseGlyph: FT_Glyph! = glyph

        let error = typeface.withFreeTypeStroker { (stroker) -> FT_Error in
            FT_Stroker_Set(stroker, lineRadius, lineCap, lineJoin, miterLimit)

            return FT_Glyph_Stroke(&baseGlyph, stroker, 0)
        }

        if error == FT_Err_Ok {
            FT_Glyph_To_Bitmap(&baseGlyph, FT_RENDER_MODE_NORMAL, nil, 1)

            defer {
                // Dispose the stroked / bitmap glyph.
                FT_Done_Glyph(baseGlyph)
            }

            let bitmapGlyph = UnsafeMutablePointer<FT_BitmapGlyphRec_>(OpaquePointer(baseGlyph))!

            if let strokeLayer = makeLayer(bitmap: &bitmapGlyph.pointee.bitmap) {
                return GlyphImage(layer: strokeLayer,
                                  left: CGFloat(bitmapGlyph.pointee.left),
                                  top: CGFloat(bitmapGlyph.pointee.top))
            }
        }

        return nil
    }

    func makeOutline(glyphID: GlyphID) -> GlyphOutline? {
        typeface.withFreeTypeFace { (face) in
            activate(face: face, colors: typeface.ftColors)

            let inputGlyph = FT_UInt(glyphID)
            let loadFlags = FT_Int32(FT_LOAD_NO_BITMAP)

            guard FT_Load_Glyph(face, inputGlyph, loadFlags) == FT_Err_Ok else {
                return nil
            }

            var outline: FT_Glyph?
            FT_Get_Glyph(face.pointee.glyph, &outline)

            guard let glyph = outline else {
                return nil
            }

            return GlyphOutline(glyph: glyph)
        }
    }

    func makePath(glyphID: GlyphID) -> CGPath? {
        return typeface.withFreeTypeFace { (face) in
            activate(face: face)

            return typeface.unsafeMakePath(glyphID: FT_UInt(glyphID))
        }
    }
}
