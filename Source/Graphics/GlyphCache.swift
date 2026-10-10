//
// Copyright (C) 2026 Muhammad Tayyab Akram
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

import Foundation

/// A cache of the images and outlines of glyphs. It keeps the most recently used ones within a
/// capacity that is measured in bytes, and drops the least recently used ones when it is exceeded.
///
/// A cache can be used from multiple threads. A glyph that is dropped while it is still in use
/// stays alive until its last user lets go of it.
public final class GlyphCache: @unchecked Sendable {
    /// The cache that renderers use by default. It has a capacity of 8 MB.
    public static let `default` = GlyphCache(core: TRGlyphCacheGetDefault(), isOwned: false)

    let core: TRGlyphCacheRef
    private let isOwned: Bool

    private init(core: TRGlyphCacheRef, isOwned: Bool) {
        self.core = core
        self.isOwned = isOwned
    }

    /// Creates a cache.
    ///
    /// - Parameter capacity: The size in bytes up to which the cache keeps glyphs.
    public convenience init?(capacity: Int) {
        precondition(capacity >= 0, "The capacity is negative")

        guard let core = TRGlyphCacheCreate(TRUInteger(capacity)) else {
            return nil
        }

        self.init(core: core, isOwned: true)
    }

    deinit {
        if isOwned {
            TRGlyphCacheRelease(core)
        }
    }

    /// The capacity of this cache in bytes. Glyphs are dropped if the new capacity is exceeded.
    public var capacity: Int {
        get { return Int(TRGlyphCacheGetCapacity(core)) }
        set {
            precondition(newValue >= 0, "The capacity is negative")

            TRGlyphCacheSetCapacity(core, TRUInteger(newValue))
        }
    }

    /// The number of bytes that this cache holds at the moment.
    public var size: Int {
        return Int(TRGlyphCacheGetSize(core))
    }

    /// Drops all of the glyphs of this cache.
    public func clear() {
        TRGlyphCacheClear(core)
    }
}
