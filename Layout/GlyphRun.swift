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

public class GlyphRun {
    private let utf16: String.UTF16View
    public let startIndex: String.Index
    public let endIndex: String.Index
    public let startExtraLength: Int
    public let endExtraLength: Int
    public let isBackward: Bool
    public let bidiLevel: UInt8
    public let writingDirection: WritingDirection
    public let typeface: Typeface
    public let typeSize: CGFloat
    public let ascent: CGFloat
    public let descent: CGFloat
    public let leading: CGFloat
    public let glyphIDs: PrimitiveCollection<UInt16>
    public let glyphOffsets: PrimitiveCollection<CGPoint>
    public let glyphAdvances: PrimitiveCollection<CGFloat>
    public let clusterMap: PrimitiveCollection<Int>
    public let caretEdges: PrimitiveCollection<CGFloat>

    private(set) var extent: CGFloat = -.infinity

    init(string: String, startIndex: String.Index, endIndex: String.Index,
         startExtraLength: Int, endExtraLength: Int, isBackward: Bool,
         bidiLevel: UInt8, writingDirection: WritingDirection, typeface: Typeface,
         typeSize: CGFloat, ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         glyphIDs: PrimitiveCollection<UInt16>, glyphOffsets: PrimitiveCollection<CGPoint>,
         glyphAdvances: PrimitiveCollection<CGFloat>,
         clusterMap: PrimitiveCollection<Int>, caretEdges: PrimitiveCollection<CGFloat>) {
        self.utf16 = string.utf16
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.startExtraLength = startExtraLength
        self.endExtraLength = endExtraLength
        self.isBackward = isBackward
        self.bidiLevel = bidiLevel
        self.writingDirection = writingDirection
        self.typeface = typeface
        self.typeSize = typeSize
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.glyphIDs = glyphIDs
        self.glyphOffsets = glyphOffsets
        self.glyphAdvances = glyphAdvances
        self.clusterMap = clusterMap
        self.caretEdges = caretEdges
    }

    public internal(set) var origin: CGPoint = .zero

    private var isRTL: Bool {
        return (bidiLevel & 1) == 1
    }

    private var glyphCount: Int {
        return glyphIDs.count
    }

    public var width: CGFloat {
        // Locking is not required for constant width.
        if extent == -CGFloat.infinity {
            extent = computeTypographicExtent(forGlyphRange: 0 ..< glyphIDs.count)
        }

        return extent
    }

    public var height: CGFloat {
        return ascent + descent + leading
    }

    private func checkCharacterIndex(_ characterIndex: String.Index) {
        precondition(characterIndex >= startIndex && characterIndex < endIndex,
                     "Index is out of range")
    }

    public func actualClusterStart(forCharacterAt index: String.Index) -> String.Index {
        checkCharacterIndex(index)

        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)
        let arrayIndex = utf16.distance(from: extraStart, to: index)

        let clusterStart = Clusters.actualClusterStart(in: clusterMap, for: arrayIndex)

        return utf16.index(extraStart, offsetBy: clusterStart)
    }

    public func actualClusterEnd(forCharacterAt index: String.Index) -> String.Index {
        checkCharacterIndex(index)

        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)
        let arrayIndex = utf16.distance(from: extraStart, to: index)

        let clusterEnd = Clusters.actualClusterEnd(in: clusterMap, for: arrayIndex)

        return utf16.index(extraStart, offsetBy: clusterEnd)
    }

    public func leadingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        checkCharacterIndex(index)

        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)
        let arrayIndex = utf16.distance(from: extraStart, to: index)

        return Clusters.leadingGlyphIndex(in: clusterMap, for: arrayIndex, isBackward: isBackward, glyphCount: glyphCount)
    }

    public func trailingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        checkCharacterIndex(index)

        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)
        let arrayIndex = utf16.distance(from: extraStart, to: index)

        return Clusters.trailingGlyphIndex(in: clusterMap, for: arrayIndex, isBackward: isBackward, glyphCount: glyphCount)
    }

    private func caretEdge(forCharacterAt index: String.Index) -> CGFloat {
        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)
        let arrayIndex = utf16.distance(from: extraStart, to: index)

        return caretEdges[arrayIndex]
    }

    private func leadingEdge(forCharacterRange range: Range<String.Index>) -> CGFloat {
        return caretEdge(forCharacterAt: !isBackward ? range.lowerBound : range.upperBound)
    }

    public func distanceForCharacter(at index: String.Index) -> CGFloat {
        checkCharacterIndex(index)

        return caretEdge(forCharacterAt: index)
    }

    func distanceForCharacters(in range: Range<String.Index>) -> CGFloat {
        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)

        let lowerBound = utf16.distance(from: extraStart, to: range.lowerBound)
        let upperBound = utf16.distance(from: extraStart, to: range.upperBound)

        let lowerEdge = caretEdges[lowerBound]
        let upperEdge = caretEdges[upperBound]

        return isRTL ? lowerEdge - upperEdge : upperEdge - lowerEdge
    }

    public func nearestCharacterIndex(at distance: CGFloat) -> String.Index {
        let extraStart = utf16.index(startIndex, offsetBy: -startExtraLength)

        var leadingCharIndex: String.Index?
        var trailingCharIndex: String.Index?

        var leadingCaretEdge: CGFloat = 0.0
        var trailingCaretEdge: CGFloat = 0.0

        var index = isRTL ? endIndex : startIndex
        let next = isRTL ? -1 : 1

        while index <= endIndex && index >= startIndex {
            let caretEdge = caretEdges[utf16.distance(from: extraStart, to: index)]

            if caretEdge <= distance {
                leadingCharIndex = index
                leadingCaretEdge = caretEdge
            } else {
                trailingCharIndex = index
                trailingCaretEdge = caretEdge
                break
            }

            index = utf16.index(index, offsetBy: next)
        }

        if leadingCharIndex == nil {
            // No char is covered by the input distance.
            return startIndex
        }

        if trailingCharIndex == nil {
            // Whole run is covered by the input distance.
            return endIndex
        }

        if distance <= (leadingCaretEdge + trailingCaretEdge) / 2.0 {
            // Input distance is closer to first edge.
            return leadingCharIndex!
        }

        // Input distance is closer to second edge.
        return trailingCharIndex!
    }

    public func computeBoundingBox(forGlyphRange range: Range<Int>, using renderer: Renderer) -> CGRect {
        renderer.typeface = typeface
        renderer.typeSize = typeSize
        renderer.writingDirection = writingDirection

        return renderer.computeBoundingBox(glyphIDs: glyphIDs[range],
                                           offsets: glyphOffsets[range],
                                           advances: glyphAdvances[range])
    }

    public func computeTypographicExtent(forGlyphRange range: Range<Int>) -> CGFloat {
        var extent: CGFloat = 0.0

        for i in range {
            extent += glyphAdvances[i]
        }

        return extent
    }

}
