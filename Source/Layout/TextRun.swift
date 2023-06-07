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

protocol TextRun {
    typealias GlyphIDs = PrimitiveCollection<GlyphID>
    typealias GlyphOffsets = PrimitiveCollection<CGPoint>
    typealias GlyphAdvances = PrimitiveCollection<CGFloat>

    typealias ClusterMap = PrimitiveCollection<Int>
    typealias CaretEdges = PrimitiveCollection<CGFloat>

    var string: String { get }
    var codeUnitRange: Range<Int> { get }

    var isBackward: Bool { get }
    var bidiLevel: UInt8 { get }
    var attributes: [NSAttributedString.Key: Any] { get }

    var startExtraLength: Int { get }
    var endExtraLength: Int { get }

    var typeface: Typeface { get }
    var typeSize: CGFloat { get }
    var writingDirection: WritingDirection { get }

    var glyphIDs: GlyphIDs { get }
    var glyphOffsets: GlyphOffsets { get }
    var glyphAdvances: GlyphAdvances { get }

    var clusterMap: ClusterMap { get }
    var caretEdges: CaretEdges { get }

    var ascent: CGFloat { get }
    var descent: CGFloat { get }
    var leading: CGFloat { get }

    var width: CGFloat { get }
    var height: CGFloat { get }

    func clusterStart(forCodeUnitAt index: Int) -> Int
    func clusterEnd(forCodeUnitAt index: Int) -> Int

    func glyphRange(forCodeUnitRange range: Range<Int>) -> Range<Int>
    func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int
    func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int

    func caretBoundary(forCodeUnitRange range: Range<Int>) -> CGFloat
    func caretEdge(forCodeUnitAt index: Int) -> CGFloat

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat
    func indexOfCodeUnit(at distance: CGFloat) -> Int

    func computeBoundingBox(forGlyphRange glyphRange: Range<Int>, with renderer: Renderer) -> CGRect

    func draw(with renderer: Renderer, in context: CGContext)
}

// MARK: - Default Implementations

extension TextRun {
    var width: CGFloat {
        return distance(forCodeUnitRange: codeUnitRange)
    }

    var height: CGFloat {
        return ascent + descent + leading
    }

    func caretBoundary(forCodeUnitRange range: Range<Int>) -> CGFloat {
        let offset = codeUnitRange.lowerBound
        let firstIndex = range.lowerBound - offset
        let lastIndex = range.upperBound - offset

        let caretUtils = CaretUtils(caretEdges: caretEdges, isRTL: isRTL)
        return caretUtils.leftMargin(inRange: firstIndex ... lastIndex)
    }

    func caretEdge(forCodeUnitAt index: Int) -> CGFloat {
        return caretEdge(forCodeUnitAt: index, caretBoundary: .zero)
    }

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat {
        let offset = codeUnitRange.lowerBound
        let firstIndex = range.lowerBound - offset
        let lastIndex = range.upperBound - offset

        let caretUtils = CaretUtils(caretEdges: caretEdges, isRTL: isRTL)
        return caretUtils.distance(forRange: firstIndex ... lastIndex)
    }

    func indexOfCodeUnit(at distance: CGFloat) -> Int {
        indexOfCodeUnit(at: distance, inCodeUnitRange: codeUnitRange)
    }

    func indexOfCodeUnit(at distance: CGFloat, inCodeUnitRange range: Range<Int>) -> Int {
        let offset = codeUnitRange.lowerBound
        let firstIndex = range.lowerBound - offset
        let lastIndex = range.upperBound - offset

        let caretUtils = CaretUtils(caretEdges: caretEdges, isRTL: isRTL)
        let elementIndex = caretUtils.indexOfElement(at: distance,inRange: firstIndex ... lastIndex)

        return elementIndex + codeUnitRange.lowerBound
    }

    func computeBoundingBox(forGlyphRange glyphRange: Range<Int>, with renderer: Renderer) -> CGRect {
        renderer.typeface = typeface
        renderer.typeSize = typeSize
        renderer.writingDirection = writingDirection

        return renderer.computeBoundingBox(
            forGlyphs: glyphIDs[glyphRange],
            offsets: glyphOffsets[glyphRange],
            advances: glyphAdvances[glyphRange]
        )
    }
}

// MARK: - Helper Properties and Methods

extension TextRun {
    var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    var isRTL: Bool {
        return bidiLevel & 1 == 1
    }

    func clusterStart(forCharacterAt index: String.Index) -> String.Index {
        let inputIndex = string.utf16Index(forCharacterAt: index)
        let actualIndex = clusterStart(forCodeUnitAt: inputIndex)

        return string.characterIndex(forUTF16Index: actualIndex)
    }

    func clusterEnd(forCharacterAt index: String.Index) -> String.Index {
        let inputIndex = string.utf16Index(forCharacterAt: index)
        let actualIndex = clusterEnd(forCodeUnitAt: inputIndex)

        return string.characterIndex(forUTF16Index: actualIndex)
    }

    func leadingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        return leadingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    func trailingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        return trailingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    func caretEdge(forCodeUnitAt index: Int, caretBoundary: CGFloat) -> CGFloat {
        let actualStart = clusterStart(forCodeUnitAt: codeUnitRange.lowerBound)
        return caretEdges[index - actualStart] - caretBoundary
    }

    func caretBoundary(forCharacterRange range: Range<String.Index>) -> CGFloat {
        return caretBoundary(forCodeUnitRange: string.utf16Range(forCharacterRange: range))
    }

    func caretEdge(forCharacterAt index: String.Index) -> CGFloat {
        return caretEdge(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    func distance(forCharacterRange range: Range<String.Index>) -> CGFloat {
        return distance(forCodeUnitRange: string.utf16Range(forCharacterRange: range))
    }

    func indexOfCharacter(at distance: CGFloat) -> String.Index {
        let codeUnitIndex = indexOfCodeUnit(at: distance)
        return string.characterIndex(forUTF16Index: codeUnitIndex)
    }
}
