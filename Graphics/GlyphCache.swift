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
    let semaphore = DispatchSemaphore(value: 1)
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
        if let glyph = fontCache[glyphID] {
            return glyph
        }

        return Glyph(glyphID: glyphID)
    }

    func maskGlyph(with strike: GlyphStrike, for glyphID: UInt16) -> Glyph {
        semaphore.wait()

        let fontCache = unsafeFontCache(for: strike)
        let glyph = unsafeGlyph(in: fontCache, for: glyphID)

        semaphore.signal()

        if glyph.image == nil {
            fontCache.semaphore.wait()
            defer { fontCache.semaphore.signal() }

            if glyph.image == nil {
                fontCache[glyphID] = nil

                fontCache.rasterizer.loadImage(in: glyph)
                fontCache[glyphID] = glyph
            }
        }

        return glyph
    }

    func maskGlyph(with strike: GlyphStrike, for glyphID: UInt16, lineRadius: FT_Fixed, lineCap: FT_Stroker_LineCap, lineJoin: FT_Stroker_LineJoin, miterLimit: FT_Fixed) -> Glyph {
        semaphore.wait()

        let fontCache = unsafeFontCache(for: strike)
        let glyph = unsafeGlyph(in: fontCache, for: glyphID)

        semaphore.signal()

        if glyph.outline == nil {
            fontCache.semaphore.wait()
            defer { fontCache.semaphore.signal() }

            if glyph.outline == nil {
                fontCache[glyphID] = nil

                fontCache.rasterizer.loadOutline(in: glyph)
                fontCache[glyphID] = glyph
            }
        }

        return fontCache.rasterizer.stroked(glyph: glyph,
                                            lineRadius: lineRadius,
                                            lineCap: lineCap,
                                            lineJoin: lineJoin,
                                            miterLimit: miterLimit)
    }

    func glyphPath(with strike: GlyphStrike, for glyphID: UInt16) -> CGPath? {
        semaphore.wait()

        let fontCache = unsafeFontCache(for: strike)
        let glyph = unsafeGlyph(in: fontCache, for: glyphID)

        semaphore.signal()

        if glyph.path == nil {
            fontCache.semaphore.wait()
            defer { fontCache.semaphore.signal() }

            if glyph.path == nil {
                fontCache[glyphID] = nil

                fontCache.rasterizer.loadPath(in: glyph)
                fontCache[glyphID] = glyph
            }
        }

        return glyph.path
    }
}
