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

final class JustifiedRun: TextRun {
    private let textRun: TextRun
    private let justifiedAdvances: GlyphAdvances
    private let justifiedCaretEdges: CaretEdges

    init(textRun: TextRun, justifiedAdvances: GlyphAdvances) {
        let isRTL = textRun.bidiLevel & 1 == 1

        let caretEdgesBuilder = CaretEdgesBuilder(
            isBackward: textRun.isBackward,
            isRTL: isRTL,
            glyphAdvances: justifiedAdvances,
            clusterMap: textRun.clusterMap,
            caretStops: nil
        )
        let caretEdgesArray = caretEdgesBuilder.build()

        let runRange = textRun.codeUnitRange
        let firstIndex = textRun.startExtraLength
        let lastIndex = firstIndex + runRange.count

        let caretUtils = CaretUtils(caretEdges: caretEdgesArray, isRTL: isRTL)
        let caretBoundary = caretUtils.leftMargin(inRange: firstIndex ... lastIndex)
        let intrinsicCaretEdges = IntrinsicCaretEdges(
            base: caretEdgesArray,
            boundary: caretBoundary
        )

        self.textRun = textRun
        self.justifiedAdvances = justifiedAdvances
        self.justifiedCaretEdges = PrimitiveCollection(intrinsicCaretEdges)
    }

    var string: String {
        return textRun.string
    }

    var codeUnitRange: Range<Int> {
        return textRun.codeUnitRange
    }

    var isBackward: Bool {
        return textRun.isBackward
    }

    var bidiLevel: UInt8 {
        return textRun.bidiLevel
    }

    var attributes: [NSAttributedString.Key : Any] {
        return textRun.attributes
    }

    var startExtraLength: Int {
        return textRun.startExtraLength
    }

    var endExtraLength: Int {
        return textRun.endExtraLength
    }

    var typeface: Typeface {
        return textRun.typeface
    }

    var typeSize: CGFloat {
        return textRun.typeSize
    }

    var writingDirection: WritingDirection {
        return textRun.writingDirection
    }

    var glyphIDs: GlyphIDs {
        return textRun.glyphIDs
    }

    var glyphOffsets: GlyphOffsets {
        return textRun.glyphOffsets
    }

    var glyphAdvances: GlyphAdvances {
        return justifiedAdvances
    }

    var clusterMap: ClusterMap {
        return textRun.clusterMap
    }

    final class IntrinsicCaretEdges: IntrinsicCollection<CGFloat> {
        let base: [CGFloat]
        let boundary: CGFloat

        init(base: [CGFloat], boundary: CGFloat) {
            self.base = base
            self.boundary = boundary
        }

        override var count: Int {
            return base.count
        }

        override func item(at index: Int) -> CGFloat {
            return base[index] - boundary
        }
    }

    var caretEdges: CaretEdges {
        return justifiedCaretEdges
    }

    var ascent: CGFloat {
        return textRun.ascent
    }

    var descent: CGFloat {
        return textRun.descent
    }

    var leading: CGFloat {
        return textRun.leading
    }

    var height: CGFloat {
        return textRun.height
    }

    func clusterStart(forCodeUnitAt index: Int) -> Int {
        return textRun.clusterStart(forCodeUnitAt: index)
    }

    func clusterEnd(forCodeUnitAt index: Int) -> Int {
        return textRun.clusterEnd(forCodeUnitAt: index)
    }

    func glyphRange(forCodeUnitRange range: Range<Int>) -> Range<Int> {
        return textRun.glyphRange(forCodeUnitRange: range)
    }

    func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return textRun.leadingGlyphIndex(forCodeUnitAt: index)
    }

    func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return textRun.trailingGlyphIndex(forCodeUnitAt: index)
    }

    func draw(with renderer: Renderer, in context: CGContext) {
        let drawing = DefaultTextRunDrawing(textRun: self)
        return drawing.draw(with: renderer, in: context)
    }
}
