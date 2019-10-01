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

fileprivate class FontCache: LRUSegment<UInt16, Glyph> {
    let rasterizer: GlyphRasterizer

    init(cache: LRUCache<UInt16, Glyph>, rasterizer: GlyphRasterizer) {
        self.rasterizer = rasterizer
        super.init(cache: cache)
    }

    override func sizeOf(key: UInt16, value: Glyph) -> Int {
        guard let maskImage = value.image else {
            return 0
        }

        return maskImage.width * maskImage.height
    }
}

class GlyphCache: LRUCache<UInt16, Glyph> {
    static let instance = GlyphCache(capacity: 4096)

    private let mutex = Mutex()
    private var segments: [GlyphStrike: FontCache] = [:]

    init(capacity: Int) {
        super.init(capacity: capacity, dummyPair: (1, Glyph(glyphID: 0)))
    }

    override func clear() {
        super.clear()
        segments.removeAll()
    }

    private func unsafeFontCache(for strike: GlyphStrike) -> FontCache {
        if let fontCache = segments[strike] {
            return fontCache
        }

        let rasterizer = GlyphRasterizer(strike)
        let fontCache = FontCache(cache: self, rasterizer: rasterizer)
        segments[strike] = fontCache

        return fontCache
    }

    private func unsafeGlyph(in fontCache: FontCache, for glyphID: UInt16) -> Glyph {
        if let glyph = fontCache.unsafeValue(forKey: glyphID) {
            return glyph
        }

        return Glyph(glyphID: glyphID)
    }

    func maskGlyph(with strike: GlyphStrike, for glyphID: UInt16) -> Glyph {
        let (fontCache, glyph) = mutex.synchronized { () -> (FontCache, Glyph) in
            let fontCache = unsafeFontCache(for: strike)
            let glyph = unsafeGlyph(in: fontCache, for: glyphID)

            return (fontCache, glyph)
        }

        if glyph.image == nil {
            let result = fontCache.rasterizer.makeImage(glyphID: glyph.glyphID)

            mutex.synchronized {
                if glyph.image == nil {
                    fontCache.unsafeRemoveValue(forKey: glyphID)

                    glyph.own(image: result.image, left: result.left, top: result.top)
                    fontCache.unsafeSetValue(glyph, forKey: glyphID)
                }
            }
        }

        return glyph
    }

    func maskGlyph(with strike: GlyphStrike, for glyphID: UInt16, lineRadius: FT_Fixed, lineCap: FT_Stroker_LineCap, lineJoin: FT_Stroker_LineJoin, miterLimit: FT_Fixed) -> Glyph {
        let (fontCache, glyph) = mutex.synchronized { () -> (FontCache, Glyph) in
            let fontCache = unsafeFontCache(for: strike)
            let glyph = unsafeGlyph(in: fontCache, for: glyphID)

            return (fontCache, glyph)
        }

        if glyph.outline == nil {
            let outline = fontCache.rasterizer.makeOutline(glyphID: glyph.glyphID)

            mutex.synchronized {
                if glyph.outline == nil {
                    fontCache.unsafeRemoveValue(forKey: glyphID)

                    glyph.own(outline: outline)
                    fontCache.unsafeSetValue(glyph, forKey: glyphID)
                } else {
                    FT_Done_Glyph(outline)
                }
            }
        }

        return fontCache.rasterizer.makeStrokedGlyph(of: glyph,
                                                     lineRadius: lineRadius,
                                                     lineCap: lineCap,
                                                     lineJoin: lineJoin,
                                                     miterLimit: miterLimit)
    }

    func glyphPath(with strike: GlyphStrike, for glyphID: UInt16) -> CGPath? {
        let (fontCache, glyph) = mutex.synchronized { () -> (FontCache, Glyph) in
            let fontCache = unsafeFontCache(for: strike)
            let glyph = unsafeGlyph(in: fontCache, for: glyphID)

            return (fontCache, glyph)
        }

        if glyph.path == nil {
            let path = fontCache.rasterizer.makePath(glyphID: glyphID)

            mutex.synchronized {
                if glyph.path == nil {
                    fontCache.unsafeRemoveValue(forKey: glyphID)

                    glyph.own(path: path)
                    fontCache.unsafeSetValue(glyph, forKey: glyphID)
                }
            }
        }

        return glyph.path
    }
}
