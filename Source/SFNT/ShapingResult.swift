//
// Copyright (C) 2019-2023 Muhammad Tayyab Akram
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
import HarfBuzz

/// A `ShapingResult` object is a container for the results of text shaping. It is generated by a
/// `ShapingEngine` object to provide the information related to characters, their glyphs, offsets,
/// and advances.
public class ShapingResult {
    let hbBuffer: OpaquePointer!

    private var string: String!
    private var sizeByEm: CGFloat = 0.0

    init() {
        hbBuffer = hb_buffer_create()
    }

    deinit {
        hb_buffer_destroy(hbBuffer)
    }

    /// The UTF-16 range in source string.
    public private(set) var codeUnitRange = Range(uncheckedBounds: (0, 0))

    /// A boolean value that indicates whether the shaped text segment flows backward.
    public private(set) var isBackward: Bool = false

    private var isRTL: Bool = false
    private var _clusterMap: ClusterMap!

    /// The index to the first character in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    var glyphCount: Int {
        return Int(hb_buffer_get_length(hbBuffer))
    }

    /// The collection of glyph IDs.
    public var glyphIDs: GlyphIDs {
        return GlyphIDs(self)
    }

    private var glyphClusters: GlyphClusters {
        return GlyphClusters(self)
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
    ///    multiple glyphs, then each character maps to the first glyph in the sequence.
    /// 3. If nonconsecutive code units translate to a single glyph or ligature, then each
    ///    participating code unit, and all in-between characters, map to this glyph or ligature.
    public var clusterMap: ClusterMap {
        return _clusterMap
    }

    private func makeCodeUnitToGlyphMap() -> [Int] {
        let clusters = glyphClusters
        let codeunitCount = codeUnitRange.count
        var association = 0

        var array = Array<Int>(repeating: -1, count: codeUnitRange.count)
        var index = glyphCount - 1

        /* Traverse in reverse order so that first glyph takes priority in case of multiple substitution. */
        while index >= 0 {
            association = clusters[index]
            array[association] = index
            index -= 1
        }

        if isBackward {
            index = codeunitCount - 1

            /* Assign the same glyph index to preceding codeunits. */
            while index >= 0 {
                if array[index] == -1 {
                    array[index] = association
                }

                association = array[index]
                index -= 1
            }
        } else {
            index = 0

            /* Assign the same glyph index to subsequent codeunits. */
            while index < codeunitCount {
                if array[index] == -1 {
                    array[index] = association
                }

                association = array[index]
                index += 1
            }
        }

        return array
    }

    /// Creates an array of caret edges.
    ///
    /// - Parameter caretStops: An array for caret stops of the UTF-16 code units represented by
    ///                         this object.
    /// - Returns: An array of caret edges.
    public func makeCaretEdges(caretStops: [Bool]?) -> [CGFloat] {
        if let caretStops = caretStops {
            precondition(caretStops.count >= codeUnitRange.count)
        }

        let caretEdgesBuilder = CaretEdgesBuilder(
            isBackward: isBackward,
            isRTL: isRTL,
            glyphAdvances: glyphAdvances,
            clusterMap: clusterMap,
            caretStops: caretStops
        )

        return caretEdgesBuilder.build()
    }

    func setup(string: String, codeUnitRange: Range<Int>,
               isBackward: Bool, isRTL: Bool, sizeByEm: CGFloat) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.isBackward = isBackward
        self.isRTL = isRTL
        self.sizeByEm = sizeByEm
        self._clusterMap = ClusterMap(makeCodeUnitToGlyphMap())
    }
}

// MARK: - Collections

extension ShapingResult {
    /// A collection of the glyph ids in a shaping result.
    public struct GlyphIDs: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafeMutablePointer<hb_glyph_info_t>!

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = hb_buffer_get_glyph_infos(owner.hbBuffer, nil)
            self.count = owner.glyphCount
        }

        /// The number of elements in the collection.
        public let count: Int

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        /// Accesses the glyph id at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> GlyphID {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            var actualIndex = index

            if owner.isRTL {
                actualIndex = count - index - 1;
            }

            return GlyphID(pointer.advanced(by: actualIndex).pointee.codepoint)
        }
    }

    /// A collection of the glyph clusters in a shaping result.
    private struct GlyphClusters: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafeMutablePointer<hb_glyph_info_t>!

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = hb_buffer_get_glyph_infos(owner.hbBuffer, nil)
            self.count = owner.glyphCount
        }

        /// The number of elements in the collection.
        public let count: Int

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        /// Accesses the glyph cluster at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> Int {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            var actualIndex = index

            if owner.isRTL {
                actualIndex = count - index - 1;
            }

            return Int(pointer.advanced(by: actualIndex).pointee.cluster)
        }
    }

    /// A collection of the glyph offsets in a shaping result.
    public struct GlyphOffsets: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafeMutablePointer<hb_glyph_position_t>!

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = hb_buffer_get_glyph_positions(owner.hbBuffer, nil)
            self.count = owner.glyphCount
        }

        /// The number of elements in the collection.
        public let count: Int

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        /// Accesses the glyph offset at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> CGPoint {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            var actualIndex = index

            if owner.isRTL {
                actualIndex = count - index - 1;
            }

            let element = pointer.advanced(by: actualIndex)

            return CGPoint(x: CGFloat(element.pointee.x_offset) * owner.sizeByEm,
                           y: CGFloat(element.pointee.y_offset) * owner.sizeByEm)
        }
    }

    /// A collection of the glyph advances in a shaping result.
    public struct GlyphAdvances: RandomAccessCollection {
        private let owner: ShapingResult
        private let pointer: UnsafeMutablePointer<hb_glyph_position_t>!

        init(_ owner: ShapingResult) {
            self.owner = owner
            self.pointer = hb_buffer_get_glyph_positions(owner.hbBuffer, nil)
            self.count = owner.glyphCount
        }

        /// The number of elements in the collection.
        public let count: Int

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        /// Accesses the glyph advance at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> CGFloat {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            var actualIndex = index

            if owner.isRTL {
                actualIndex = count - index - 1;
            }

            let element = pointer.advanced(by: actualIndex)

            return CGFloat(element.pointee.x_advance) * owner.sizeByEm
        }
    }

    /// A collection of the cluster map in a shaping result, represented by UTF-16 code unit indices.
    public struct ClusterMap: RandomAccessCollection {
        private let array: [Int]

        init(_ array: [Int]) {
            self.array = array
        }

        /// The number of elements in the collection.
        public var count: Int {
            return array.count
        }

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        /// Accesses the glyph index at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> Int {
            return array[index]
        }
    }
}
