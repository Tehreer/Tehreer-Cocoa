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

class IntrinsicRun {
    let string: String
    let startIndex: String.Index
    let endIndex: String.Index
    let isBackward: Bool
    let bidiLevel: UInt8
    let writingDirection: WritingDirection
    let typeface: Typeface
    let typeSize: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let glyphIDs: [UInt16]
    let glyphOffsets: [CGPoint]
    let glyphAdvances: [CGFloat]
    let clusterMap: [Int]
    let caretEdges: [CGFloat]

    init(string: String, startIndex: String.Index, endIndex: String.Index, isBackward: Bool,
         bidiLevel: UInt8, writingDirection: WritingDirection, typeface: Typeface,
         typeSize: CGFloat, ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         glyphIDs: [UInt16], glyphOffsets: [CGPoint], glyphAdvances: [CGFloat],
         clusterMap: [Int], caretEdges: [CGFloat]) {
        self.string = string
        self.startIndex = startIndex
        self.endIndex = endIndex
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

    var isRTL: Bool {
        return (bidiLevel & 1) == 1
    }

    var glyphCount: Int {
        return glyphIDs.count
    }

    func glyphRange(forUTF16Range range: Range<Int>) -> Range<Int> {
        return Clusters.glyphRange(in: clusterMap,
                                   for: range,
                                   isBackward: isBackward,
                                   glyphCount: glyphCount)
    }

    func clusterRange(forUTF16Range range: Range<Int>) -> Range<Int> {
        let clusterStart = Clusters.actualClusterStart(in: clusterMap, for: range.lowerBound)
        let clusterEnd = Clusters.actualClusterEnd(in: clusterMap, for: range.upperBound - 1)

        return clusterStart ..< clusterEnd
    }

    func measureCharacters(in range: Range<String.Index>) -> CGFloat {
        let collection = CaretEdgeCollection(allEdges: caretEdges)
        let utf16Range: Range<Int> = string.utf16Range(forCharacterRange: range)

        return collection.distance(of: utf16Range, isRTL: isRTL)
    }
}
