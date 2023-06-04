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

import Foundation
import CoreGraphics

final class IntrinsicRun: TextRun {
    let string: String
    let codeUnitRange: Range<Int>
    let isBackward: Bool
    let bidiLevel: UInt8
    let writingDirection: WritingDirection
    let typeface: Typeface
    let typeSize: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let glyphIDs: GlyphIDs
    let glyphOffsets: GlyphOffsets
    let glyphAdvances: GlyphAdvances
    let clusterMap: ClusterMap
    let caretEdges: CaretEdges

    init(string: String, codeUnitRange: Range<Int>, isBackward: Bool,
         bidiLevel: UInt8, writingDirection: WritingDirection,
         typeface: Typeface, typeSize: CGFloat,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         glyphIDs: GlyphIDs, glyphOffsets: GlyphOffsets, glyphAdvances: GlyphAdvances,
         clusterMap: ClusterMap, caretEdges: CaretEdges) {
        self.string = string
        self.codeUnitRange = codeUnitRange
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

    var attributes: [NSAttributedString.Key: Any] { [:] }

    var startExtraLength: Int { 0 }
    var endExtraLength: Int { 0 }

    var glyphCount: Int { glyphIDs.count }

    func clusterStart(forCodeUnitAt index: Int) -> Int {
        let runStart = codeUnitRange.lowerBound
        let mappingIndex = index - runStart
        let common = clusterMap[mappingIndex]

        for i in stride(from: mappingIndex - 1, through: 0, by: -1) {
            if clusterMap[i] != common {
                return (i + 1) + runStart
            }
        }

        return runStart
    }

    func clusterEnd(forCodeUnitAt index: Int) -> Int {
        let runStart = codeUnitRange.lowerBound
        let mappingIndex = index - runStart
        let common = clusterMap[mappingIndex]
        let length = clusterMap.count

        for i in stride(from: mappingIndex + 1, to: length, by: 1) {
            if clusterMap[i] != common {
                return i + runStart
            }
        }

        return length + runStart
    }

    private func forwardGlyphIndex(for mappingIndex: Int) -> Int {
        let common = clusterMap[mappingIndex]
        let length = clusterMap.count

        for i in stride(from: mappingIndex + 1, to: length, by: 1) {
            let mapping = clusterMap[i]
            if mapping != common {
                return mapping - 1
            }
        }

        return glyphCount - 1
    }

    private func backwardGlyphIndex(for mappingIndex: Int) -> Int {
        let common = clusterMap[mappingIndex]

        for i in stride(from: mappingIndex - 1, through: 0, by: -1) {
            let mapping = clusterMap[i]
            if mapping != common {
                return mapping - 1
            }
        }

        return glyphCount - 1
    }

    func glyphRange(forCodeUnitRange range: Range<Int>) -> Range<Int> {
        let runStart = codeUnitRange.lowerBound
        let firstIndex = range.lowerBound - runStart
        let lastIndex = range.upperBound - 1 - runStart

        if isBackward {
            return clusterMap[lastIndex] ..< backwardGlyphIndex(for: firstIndex) + 1
        }

        return clusterMap[firstIndex] ..< forwardGlyphIndex(for: lastIndex) + 1
    }

    func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        let runStart = codeUnitRange.lowerBound
        let mappingIndex = index - runStart

        if (isBackward) {
            return backwardGlyphIndex(for: mappingIndex)
        }

        return clusterMap[mappingIndex]
    }

    func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        let runStart = codeUnitRange.lowerBound
        let mappingIndex = index - runStart

        if (isBackward) {
            return clusterMap[mappingIndex]
        }

        return forwardGlyphIndex(for: mappingIndex)
    }

    func clusterRange(forUTF16Range range: Range<Int>) -> Range<Int> {
        let runStart = codeUnitRange.lowerBound
        let lowerBound = range.lowerBound - runStart
        let upperBound = range.upperBound - runStart - 1

        let clusterStart = Clusters.actualClusterStart(in: clusterMap, for: lowerBound)
        let clusterEnd = Clusters.actualClusterEnd(in: clusterMap, for: upperBound)

        return (clusterStart + runStart) ..< (clusterEnd + runStart)
    }

    func draw(with renderer: Renderer, in context: CGContext) {
        fatalError()
    }
}
