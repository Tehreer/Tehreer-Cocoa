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

private func sizeOfLayer(_ layer: CGLayer) -> Int {
    let size = layer.size

    if layer.context?.bitsPerPixel == 32 {
        return Int(size.width * size.height * 4)
    }

    return Int(size.width * size.height)
}

private class DataSegment: LRUSegment<UInt16> {
    let rasterizer: GlyphRasterizer

    init(cache: LRUCache<UInt16>, rasterizer: GlyphRasterizer) {
        self.rasterizer = rasterizer
        super.init(cache: cache)
    }

    override func sizeOf(key: UInt16, value: AnyObject) -> Int {
        guard let image = (value as! Glyph).image else {
            return 0
        }

        return sizeOfLayer(image.layer)
    }
}

private class ImageSegment: LRUSegment<UInt16> {
    override init(cache: LRUCache<UInt16>) {
        super.init(cache: cache)
    }

    override func sizeOf(key: UInt16, value: AnyObject) -> Int {
        return sizeOfLayer((value as! GlyphImage).layer)
    }
}

class GlyphCache: LRUCache<UInt16> {
    static let instance = GlyphCache(capacity: 8192 * 1024)

    private let mutex = Mutex()
    private var segments: [GlyphKey: AnyObject] = [:]

    init(capacity: Int) {
        super.init(capacity: capacity, dummyPair: (1, Glyph()))
    }

    override func clear() {
        super.clear()
        segments.removeAll()
    }

    private func secureDataSegment(for key: GlyphKey) -> DataSegment {
        if let segment = segments[key] as? DataSegment {
            return segment
        }

        let rasterizer = GlyphRasterizer(key)
        let segment = DataSegment(cache: self, rasterizer: rasterizer)
        segments[key.copy()] = segment

        return segment
    }

    private func secureImageSegment(for key: GlyphKey) -> ImageSegment {
        if let segment = segments[key] as? ImageSegment {
            return segment
        }

        let segment = ImageSegment(cache: self)
        segments[key.copy()] = segment

        return segment
    }

    private func secureGlyph(_ glyphID: GlyphID, for segment: DataSegment) -> Glyph {
        if let glyph = segment.value(forKey: glyphID) as? Glyph {
            return glyph
        }

        return Glyph()
    }

    private func coloredImage(forGlyph glyphID: GlyphID, key: GlyphKey.Color,
                              rasterizer: GlyphRasterizer) -> GlyphImage? {
        var segment: ImageSegment!
        var coloredImage: GlyphImage?

        mutex.synchronized {
            segment = secureImageSegment(for: key)
            coloredImage = segment.value(forKey: glyphID) as? GlyphImage
        }

        if coloredImage == nil {
            coloredImage = rasterizer.makeImage(glyphID: glyphID,
                                                foregroundColor: key.foregroundColor)

            if coloredImage != nil {
                mutex.synchronized {
                    segment.removeValue(forKey: glyphID)
                    segment.setValue(coloredImage, forKey: glyphID)
                }
            }
        }

        return coloredImage
    }

    public func defaultImage(forGlyph glyphID: GlyphID, attributes: GlyphAttributes) -> GlyphImage? {
        var segment: DataSegment!
        var glyph: Glyph!

        mutex.synchronized {
            segment = secureDataSegment(for: attributes.dataKey)
            glyph = secureGlyph(glyphID, for: segment)
        }

        if !glyph.isLoaded {
            let glyphType = segment.rasterizer.getType(forGlyph: glyphID)
            var glyphImage: GlyphImage?

            if glyphType != .mixed {
                glyphImage = segment.rasterizer.makeImage(glyphID: glyphID)
            }

            mutex.synchronized {
                if !glyph.isLoaded {
                    segment.removeValue(forKey: glyphID)

                    glyph.type = glyphType
                    glyph.image = glyphImage

                    segment.setValue(glyph, forKey: glyphID)
                }
            }
        }

        if glyph.type == .mixed {
            return coloredImage(forGlyph: glyphID, key: attributes.colorKey,
                                rasterizer: segment.rasterizer)
        }

        return glyph.image
    }

    private func strokeImage(forGlyph glyphID: GlyphID, key: GlyphKey.Stroke,
                             rasterizer: GlyphRasterizer, outline: GlyphOutline) -> GlyphImage? {
        var segment: ImageSegment!
        var strokeImage: GlyphImage?

        mutex.synchronized {
            segment = secureImageSegment(for: key)
            strokeImage = segment.value(forKey: glyphID) as? GlyphImage
        }

        if strokeImage == nil {
            strokeImage = rasterizer.makeStrokeImage(glyph: outline.glyph,
                                                     lineRadius: key.lineRadius,
                                                     lineCap: key.lineCap, lineJoin: key.lineJoin,
                                                     miterLimit: key.miterLimit)

            if strokeImage != nil {
                mutex.synchronized {
                    segment.removeValue(forKey: glyphID)
                    segment.setValue(strokeImage, forKey: glyphID)
                }
            }
        }

        return strokeImage
    }

    func strokeImage(forGlyph glyphID: GlyphID, attributes: GlyphAttributes) -> GlyphImage? {
        var segment: DataSegment!
        var glyph: Glyph!

        mutex.synchronized {
            segment = secureDataSegment(for: attributes.dataKey)
            glyph = secureGlyph(glyphID, for: segment)
        }

        var glyphOutline = glyph.outline

        if glyphOutline == nil {
            glyphOutline = segment.rasterizer.makeOutline(glyphID: glyphID)

            mutex.synchronized {
                if glyph.outline == nil {
                    segment.removeValue(forKey: glyphID)
                    glyph.outline = glyphOutline
                    segment.setValue(glyph, forKey: glyphID)
                }
            }
        }

        if let glyphOutline = glyphOutline {
            return strokeImage(forGlyph: glyphID, key: attributes.strokeKey,
                               rasterizer: segment.rasterizer, outline: glyphOutline)
        }

        return nil
    }

    func path(forGlyph glyphID: GlyphID, attributes: GlyphAttributes) -> CGPath? {
        var segment: DataSegment!
        var glyph: Glyph!

        mutex.synchronized {
            segment = secureDataSegment(for: attributes.dataKey)
            glyph = secureGlyph(glyphID, for: segment)
        }

        var glyphPath = glyph.path

        if glyphPath == nil {
            glyphPath = segment.rasterizer.makePath(glyphID: glyphID)

            mutex.synchronized {
                if glyph.path == nil {
                    segment.removeValue(forKey: glyphID)
                    glyph.path = glyphPath
                    segment.setValue(glyph, forKey: glyphID)
                }
            }
        }

        return glyphPath
    }
}
