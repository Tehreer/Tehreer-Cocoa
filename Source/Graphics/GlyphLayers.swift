//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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


internal import Tehreer

import CoreGraphics
import Foundation

/// The layer that a glyph image is drawn from, which is kept with the image of Core.
private final class GlyphLayer {
    let layer: CGLayer

    init(_ layer: CGLayer) {
        self.layer = layer
    }
}

enum GlyphLayers {
    private static let maskDecode: [CGFloat] = [1.0, 0.0]
    private static let maskSpace = CGColorSpaceCreateDeviceGray()
    private static let rgbSpace = CGColorSpaceCreateDeviceRGB()

    /// Returns the layer of an image, which is made when it is asked for the first time.
    static func layer(of image: TRGlyphImageRef) -> CGLayer? {
        if let data = TRGlyphImageGetNativeData(image) {
            return Unmanaged<GlyphLayer>.fromOpaque(data).takeUnretainedValue().layer
        }

        guard let layer = makeLayer(of: image) else {
            return nil
        }

        let box = Unmanaged.passRetained(GlyphLayer(layer))
        let isAttached = TRGlyphImageSetNativeData(image, box.toOpaque()) { (data) in
            Unmanaged<GlyphLayer>.fromOpaque(data!).release()
        }

        // Another thread attached its own layer first, which is used as it is.
        if isAttached == 0 {
            box.release()

            if let data = TRGlyphImageGetNativeData(image) {
                return Unmanaged<GlyphLayer>.fromOpaque(data).takeUnretainedValue().layer
            }
        }

        return layer
    }

    private static func makeLayer(of image: TRGlyphImageRef) -> CGLayer? {
        let width = Int(TRGlyphImageGetWidth(image))
        let height = Int(TRGlyphImageGetHeight(image))
        guard width > 0, height > 0, let pixels = TRGlyphImageGetPixelsPtr(image) else {
            return nil
        }

        let isAlpha = TRGlyphImageGetFormat(image) == TRGlyphImageFormat(TRGlyphImageFormatAlpha)
        let bytesPerPixel = isAlpha ? 1 : 4

        // The pixels stay with the image, and are only read while the layer is made.
        guard let provider = CGDataProvider(dataInfo: nil,
                                            data: pixels,
                                            size: width * height * bytesPerPixel,
                                            releaseData: { (info, data, size) in }) else {
            return nil
        }

        let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height))

        if isAlpha {
            guard let mask = CGImage(maskWidth: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bitsPerPixel: 8,
                                     bytesPerRow: width,
                                     provider: provider,
                                     decode: maskDecode,
                                     shouldInterpolate: false),
                  let context = CGContext(data: nil,
                                          width: 1,
                                          height: 1,
                                          bitsPerComponent: 8,
                                          bytesPerRow: 1,
                                          space: maskSpace,
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
                  let layer = CGLayer(context, size: rect.size, auxiliaryInfo: nil) else {
                return nil
            }

            let layerContext = layer.context
            layerContext?.translateBy(x: 0, y: rect.height)
            layerContext?.scaleBy(x: 1.0, y: -1.0)
            layerContext?.draw(mask, in: rect)

            return layer
        }

        // The pixels have the alpha first, and the colors are premultiplied with it.
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                                              | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let colorImage = CGImage(width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 32,
                                       bytesPerRow: width * 4,
                                       space: rgbSpace,
                                       bitmapInfo: bitmapInfo,
                                       provider: provider,
                                       decode: nil,
                                       shouldInterpolate: false,
                                       intent: .defaultIntent),
              let context = CGContext(data: nil,
                                      width: 1,
                                      height: 1,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4,
                                      space: rgbSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue),
              let layer = CGLayer(context, size: rect.size, auxiliaryInfo: nil) else {
            return nil
        }

        let layerContext = layer.context
        layerContext?.translateBy(x: 0, y: rect.height)
        layerContext?.scaleBy(x: 1.0, y: -1.0)
        layerContext?.draw(colorImage, in: rect)

        return layer
    }
}
