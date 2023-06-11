//
// Copyright (C) 2023 Muhammad Tayyab Akram
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

final class IntrinsicRunSlice: TextRun {
    private let intrinsicRun: IntrinsicRun
    private let glyphRange: Range<Int>
    private let caretBoundary: CGFloat

    let codeUnitRange: Range<Int>
    let attributes: [NSAttributedString.Key: Any]

    init(intrinsicRun: IntrinsicRun,
         codeUnitRange: Range<Int>,
         attributes: [NSAttributedString.Key: Any]
    ) {
        self.intrinsicRun = intrinsicRun
        self.glyphRange = intrinsicRun.glyphRange(forCodeUnitRange: codeUnitRange)
        self.caretBoundary = intrinsicRun.caretBoundary(forCodeUnitRange: codeUnitRange)
        self.codeUnitRange = codeUnitRange
        self.attributes = attributes
    }

    var string: String {
        return intrinsicRun.string
    }

    var isBackward: Bool {
        return intrinsicRun.isBackward
    }

    var bidiLevel: UInt8 {
        return intrinsicRun.bidiLevel
    }

    var startExtraLength: Int {
        let runStart = codeUnitRange.lowerBound
        return runStart - intrinsicRun.clusterStart(forCodeUnitAt: runStart)
    }

    var endExtraLength: Int {
        let runEnd = codeUnitRange.upperBound
        return intrinsicRun.clusterEnd(forCodeUnitAt: runEnd - 1) - runEnd
    }

    var typeface: Typeface {
        return intrinsicRun.typeface
    }

    var typeSize: CGFloat {
        return intrinsicRun.typeSize
    }

    var writingDirection: WritingDirection {
        return intrinsicRun.writingDirection
    }

    var glyphIDs: GlyphIDs {
        return intrinsicRun.glyphIDs[glyphRange]
    }

    var glyphOffsets: GlyphOffsets {
        return intrinsicRun.glyphOffsets[glyphRange]
    }

    var glyphAdvances: GlyphAdvances {
        return intrinsicRun.glyphAdvances[glyphRange]
    }

    final class ClusterMapSlice: IntrinsicCollection<Int> {
        let base: IntrinsicCollection<Int>
        let offset: Int
        let size: Int
        let difference: Int

        init(base: IntrinsicCollection<Int>,
             offset: Int,
             size: Int,
             difference: Int
        ) {
            self.base = base
            self.offset = offset
            self.size = size
            self.difference = difference
        }

        override var count: Int {
            return size
        }

        override func item(at index: Int) -> Int {
            return base.item(at: index + offset) - difference
        }
    }

    var clusterMap: ClusterMap {
        let actualStart = codeUnitRange.lowerBound - startExtraLength
        let actualEnd = codeUnitRange.upperBound + endExtraLength

        let offset = actualStart - intrinsicRun.codeUnitRange.lowerBound
        let size = actualEnd - actualStart

        let baseMap = intrinsicRun.clusterMap.base
        let mapSlice = ClusterMapSlice(
            base: baseMap,
            offset: offset,
            size: size,
            difference: glyphRange.lowerBound
        )

        return PrimitiveCollection(mapSlice)
    }

    final class CaretEdgesSlice: IntrinsicCollection<CGFloat> {
        let base: IntrinsicCollection<CGFloat>
        let offset: Int
        let size: Int
        let boundary: CGFloat

        init(base: IntrinsicCollection<CGFloat>,
             offset: Int,
             size: Int,
             boundary: CGFloat
        ) {
            self.base = base
            self.offset = offset
            self.size = size
            self.boundary = boundary
        }

        override var count: Int {
            return size
        }

        override func item(at index: Int) -> CGFloat {
            return base.item(at: index + offset) - boundary
        }
    }

    var caretEdges: CaretEdges {
        let actualStart = codeUnitRange.lowerBound - startExtraLength
        let actualEnd = codeUnitRange.upperBound + endExtraLength

        let offset = actualStart - intrinsicRun.codeUnitRange.lowerBound
        let size = actualEnd - actualStart + 1

        let baseEdges = intrinsicRun.caretEdges.base
        let edgesSlice = CaretEdgesSlice(
            base: baseEdges,
            offset: offset,
            size: size,
            boundary: caretBoundary
        )

        return PrimitiveCollection(edgesSlice)
    }

    var ascent: CGFloat {
        return intrinsicRun.ascent
    }

    var descent: CGFloat {
        return intrinsicRun.descent
    }

    var leading: CGFloat {
        return intrinsicRun.leading
    }

    var width: CGFloat {
        return intrinsicRun.distance(forCodeUnitRange: codeUnitRange)
    }

    var height: CGFloat {
        return intrinsicRun.height
    }

    func clusterStart(forCodeUnitAt index: Int) -> Int {
        return intrinsicRun.clusterStart(forCodeUnitAt: index)
    }

    func clusterEnd(forCodeUnitAt index: Int) -> Int {
        return intrinsicRun.clusterEnd(forCodeUnitAt: index)
    }

    func glyphRange(forCodeUnitRange range: Range<Int>) -> Range<Int> {
        let actualRange = intrinsicRun.glyphRange(forCodeUnitRange: range)
        let sliceOffset = glyphRange.lowerBound

        return (actualRange.lowerBound - sliceOffset) ..< (actualRange.upperBound - sliceOffset)
    }

    func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return intrinsicRun.leadingGlyphIndex(forCodeUnitAt: index) - glyphRange.lowerBound
    }

    func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return intrinsicRun.trailingGlyphIndex(forCodeUnitAt: index) - glyphRange.lowerBound
    }

    func caretEdge(forCodeUnitAt index: Int) -> CGFloat {
        return intrinsicRun.caretEdge(forCodeUnitAt: index) - caretBoundary
    }

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat {
        return intrinsicRun.distance(forCodeUnitRange: range)
    }

    func indexOfCodeUnit(at distance: CGFloat) -> Int {
        return intrinsicRun.indexOfCodeUnit(at: distance, inCodeUnitRange: codeUnitRange)
    }

    func computeBoundingBox(forGlyphRange range: Range<Int>, with renderer: Renderer) -> CGRect {
        let actualStart = range.lowerBound + glyphRange.lowerBound
        let actualEnd = range.upperBound + glyphRange.lowerBound

        return intrinsicRun.computeBoundingBox(forGlyphRange: actualStart ..< actualEnd, with: renderer)
    }

    func draw(with renderer: Renderer, in context: CGContext) {
        let drawing = DefaultTextRunDrawing(textRun: self)
        return drawing.draw(with: renderer, in: context)
    }
}
