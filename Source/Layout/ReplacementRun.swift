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

import CoreGraphics
import Foundation

final class ReplacementRun: TextRun {
    let string: String
    let codeUnitRange: Range<Int>
    let bidiLevel: UInt8
    let replacement: TextReplacement
    let typeface: Typeface
    let typeSize: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let extent: CGFloat
    let caretEdges: CaretEdges

    init(string: String, codeUnitRange: Range<Int>, bidiLevel: UInt8,
         replacement: TextReplacement,
         typeface: Typeface, typeSize: CGFloat,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         extent: CGFloat, caretEdges: CaretEdges) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.bidiLevel = bidiLevel
        self.replacement = replacement
        self.typeface = typeface
        self.typeSize = typeSize
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.extent = extent
        self.caretEdges = caretEdges
    }

    var isBackward: Bool {
        return false
    }

    var attributes: [NSAttributedString.Key: Any] {
        return [.replacement: replacement]
    }

    var startExtraLength: Int {
        return 0
    }

    var endExtraLength: Int {
        return 0
    }

    var writingDirection: WritingDirection {
        return .leftToRight
    }

    private var spaceGlyphID: GlyphID {
        return typeface.glyphID(forCodePoint: 0x20)
    }

    var glyphIDs: GlyphIDs {
        return PrimitiveCollection([spaceGlyphID])
    }

    var glyphOffsets: GlyphOffsets {
        return PrimitiveCollection([.zero])
    }

    var glyphAdvances: GlyphAdvances {
        return PrimitiveCollection([width])
    }

    var clusterMap: ClusterMap {
        let array = Array<Int>(repeating: 0, count: codeUnitRange.count)
        return PrimitiveCollection(array)
    }

    var width: CGFloat {
        return extent
    }

    var height: CGFloat {
        return ascent + descent + leading
    }

    func clusterStart(forCodeUnitAt index: Int) -> Int {
        return codeUnitRange.lowerBound
    }

    func clusterEnd(forCodeUnitAt index: Int) -> Int {
        return codeUnitRange.upperBound
    }

    func glyphRange(forCodeUnitRange range: Range<Int>) -> Range<Int> {
        return 0 ..< 1
    }

    func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return 0
    }

    func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        return 0
    }

    func caretEdge(forCodeUnitAt index: Int) -> CGFloat {
        return caretEdges[index - codeUnitRange.lowerBound]
    }

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat {
        let actualStart = codeUnitRange.lowerBound
        let firstIndex = range.lowerBound - actualStart
        let lastIndex = range.upperBound - actualStart

        let caretUtils = CaretUtils(caretEdges: caretEdges, isRTL: isRTL)
        return caretUtils.distance(forRange: firstIndex ... lastIndex)
    }

    func computeBoundingBox(
        forGlyphRange glyphRange: Range<Int>,
        with renderer: Renderer
    ) -> CGRect {
        return CGRect(x: .zero, y: .zero, width: width, height: height)
    }

    func draw(with renderer: Renderer, in context: CGContext) {
        replacement.draw(in: context)
    }
}

extension ReplacementRun {
    /// Whether this run is a view that has a line of its own.
    var isBlock: Bool {
        return (replacement as? ViewAttachment)?.isBlock == true
    }

    /// Returns the run that a frame `layoutWidth` wide has to use, which is this one unless the
    /// replacement decides its room when the frame is made, as a view attachment does. The run is
    /// not changed, as other frames of the same typesetter may be in use.
    func forFrame(layoutWidth: CGFloat) -> ReplacementRun {
        guard let attachment = replacement as? ViewAttachment else {
            return self
        }

        let room = attachment.computeRoom(layoutWidth: layoutWidth)
        let length = codeUnitRange.count

        var caretEdges = Array<CGFloat>(repeating: .zero, count: length + 1)

        if bidiLevel & 1 == 0 {
            caretEdges[length] = room.extent
        } else {
            caretEdges[0] = room.extent
        }

        return ReplacementRun(
            string: string,
            codeUnitRange: codeUnitRange,
            bidiLevel: bidiLevel,
            replacement: replacement,
            typeface: typeface,
            typeSize: typeSize,
            ascent: room.ascent,
            descent: room.descent,
            leading: .zero,
            extent: room.extent,
            caretEdges: PrimitiveCollection(caretEdges)
        )
    }
}
