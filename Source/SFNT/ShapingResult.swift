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

/// A `ShapingResult` object is a container for the results of text shaping. It is generated by a
/// `ShapingEngine` object to provide the information related to characters, their glyphs, offsets,
/// and advances.
public class ShapingResult {
    let sfAlbum: SFAlbumRef

    private var sizeByEm: CGFloat = 0.0
    private var stringRange: Range<String.Index>!
    private var codeUnitCount: Int = 0

    init() {
        sfAlbum = SFAlbumCreate()
    }

    deinit {
        SFAlbumRelease(sfAlbum)
    }

    /// A boolean value that indicates whether the shaped text segment flows backward.
    public private(set) var isBackward: Bool = false

    public var startIndex: String.Index {
        return stringRange.lowerBound
    }

    public var endIndex: String.Index {
        return stringRange.upperBound
    }

    var glyphCount: Int {
        return Int(SFAlbumGetGlyphCount(sfAlbum))
    }

    /// The collection of glyph IDs.
    public var glyphIDs: GlyphIDs {
        return GlyphIDs(self)
    }

    /// The collection of glyph offsets.
    public var glyphOffsets: GlyphOffsets {
        return GlyphOffsets(self)
    }

    /// The collection of glyph advances.
    public var glyphAdvances: GlyphAdvances {
        return GlyphAdvances(self)
    }

    /// A collection of indexes, mapping each shaped UTF-16 code unit in source string to
    /// corresponding glyph.
    ///
    /// The map is produced according to following rules.
    ///
    /// 1. If a single code unit translates into multiple glyphs, then it maps to the first glyph in
    ///    the sequence.
    /// 2. If multiple code units form a group, such as a grapheme, which in turn translates into
    ///    into multiple glyphs, then each character maps to the first glyph in the sequence.
    /// 3. If nonconsecutive code units translate to a single glyph or ligature, then each
    ///    participating code unit, and all in-between characters, map to this glyph or ligature.
    public var clusterMap: ClusterMap {
        return ClusterMap(self)
    }

    public func makeCaretEdges(caretStops: [Bool]?) -> [CGFloat] {
        if let caretStops = caretStops {
            precondition(caretStops.count >= codeUnitCount)
        }

        let edgeCount = codeUnitCount + 1
        let unsafeEdges = UnsafeMutablePointer<SFInt32>.allocate(capacity: edgeCount)
        defer { unsafeEdges.deallocate() }

        let loaded = caretStops?.withUnsafeBufferPointer { (buffer) -> Bool? in
            guard let baseAddress = buffer.baseAddress else {
                return nil
            }

            let unsafeStops = UnsafeMutablePointer<SFBoolean>(OpaquePointer(baseAddress))
            SFAlbumGetCaretEdges(sfAlbum, unsafeStops, unsafeEdges)

            return true
        }

        if loaded == nil {
            SFAlbumGetCaretEdges(sfAlbum, nil, unsafeEdges)
        }

        let edgesBuffer = UnsafeBufferPointer(start: unsafeEdges, count: edgeCount)
        let edgesArray = edgesBuffer.map { CGFloat($0) * sizeByEm }

        return edgesArray
    }

    func setAdditionalInfo(sizeByEm: CGFloat, isBackward: Bool, stringRange: Range<String.Index>, codeUnitCount: Int) {
        self.sizeByEm = sizeByEm
        self.isBackward = isBackward
        self.stringRange = stringRange
        self.codeUnitCount = codeUnitCount
    }
}

extension ShapingResult {
    public struct GlyphIDs: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafePointer<GlyphID>!
        public let count: Int

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = SFAlbumGetGlyphIDsPtr(owner.sfAlbum)
            self.count = owner.glyphCount
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return count
        }

        public subscript(position: Int) -> GlyphID {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            return pointer[position]
        }
    }

    public struct GlyphOffsets: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafePointer<SFPoint>!
        public let count: Int

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = SFAlbumGetGlyphOffsetsPtr(owner.sfAlbum)
            self.count = owner.glyphCount
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return count
        }

        public subscript(position: Int) -> CGPoint {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            let element = pointer[position]
            let point = CGPoint(x: element.x * owner.sizeByEm,
                                y: element.y * owner.sizeByEm)

            return point
        }
    }

    public struct GlyphAdvances: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafePointer<SFInt32>!
        public let count: Int

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = SFAlbumGetGlyphAdvancesPtr(owner.sfAlbum)
            self.count = owner.glyphCount
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return count
        }

        public subscript(position: Int) -> CGFloat {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            return pointer[position] * owner.sizeByEm
        }
    }

    public struct ClusterMap: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafePointer<SFUInteger>!
        public let count: Int

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = SFAlbumGetCodeunitToGlyphMapPtr(owner.sfAlbum)
            self.count = owner.codeUnitCount
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return count
        }

        public subscript(position: Int) -> Int {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            return Int(pointer[position])
        }
    }
}
