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

func makeGlyphRun(intrinsicRun: IntrinsicRun,
                  range: Range<String.Index>,
                  attributes: [NSAttributedString.Key: Any]) -> GlyphRun {
    let string = intrinsicRun.string
    let runOffset = string.utf16Index(forCharacterAt: intrinsicRun.startIndex)

    let utf16Range: Range<Int> = string.utf16Range(forCharacterRange: range)
    let clusterRange = intrinsicRun.clusterRange(forUTF16Range: utf16Range)
    let glyphRange = intrinsicRun.glyphRange(forUTF16Range: utf16Range)

    let startExtraLength = utf16Range.lowerBound - clusterRange.lowerBound
    let endExtraLength = clusterRange.upperBound - utf16Range.upperBound

    let chunkOffset = clusterRange.lowerBound - runOffset
    let chunkLength = clusterRange.count
    let chunkRange = chunkOffset ..< (chunkOffset + chunkLength)

    let clusterMap = IntrinsicWrapCollection(base: intrinsicRun.clusterMap)
        .map({ $0 - glyphRange.lowerBound })

    let caretEdges = CaretEdgeCollection(
        allEdges: intrinsicRun.caretEdges,
        chunkOffset: chunkOffset,
        chunkLength: chunkLength,
        startExtra: startExtraLength,
        endExtra: endExtraLength,
        isRTL: intrinsicRun.isRTL)

    return GlyphRun(
        string: string,
        startIndex: range.lowerBound,
        endIndex: range.upperBound,
        startExtraLength: startExtraLength,
        endExtraLength: endExtraLength,
        attributes: attributes,
        isBackward: intrinsicRun.isBackward,
        bidiLevel: intrinsicRun.bidiLevel,
        writingDirection: intrinsicRun.writingDirection,
        typeface: intrinsicRun.typeface,
        typeSize: intrinsicRun.typeSize,
        ascent: intrinsicRun.ascent,
        descent: intrinsicRun.descent,
        leading: intrinsicRun.leading,
        glyphIDs: PrimitiveCollection(intrinsicRun.glyphIDs, range: glyphRange),
        glyphOffsets: PrimitiveCollection(intrinsicRun.glyphOffsets, range: glyphRange),
        glyphAdvances: PrimitiveCollection(intrinsicRun.glyphAdvances, range: glyphRange),
        clusterMap: PrimitiveCollection(clusterMap, range: chunkRange),
        caretEdges: PrimitiveCollection(caretEdges))
}

func makeComposedLine(text: String, range: Range<String.Index>,
                      visualRuns: [GlyphRun],
                      paragraphLevel: UInt8) -> ComposedLine {
    var lineAscent: CGFloat = 0.0
    var lineDescent: CGFloat = 0.0
    var lineLeading: CGFloat = 0.0
    var lineExtent: CGFloat = 0.0

    let trailingWhitespaceStart = text.trailingWhitespaceStart(in: range)
    var trailingWhitespaceExtent: CGFloat = 0.0

    for glyphRun in visualRuns {
        glyphRun.origin.x = lineExtent

        let wsStart = max(glyphRun.startIndex, trailingWhitespaceStart)
        let wsEnd = min(glyphRun.endIndex, range.upperBound)

        if wsStart < wsEnd {
            trailingWhitespaceExtent = glyphRun.distance(forCharacterRange: wsStart ..< wsEnd)
        }

        lineAscent = max(lineAscent, glyphRun.ascent)
        lineDescent = max(lineDescent, glyphRun.descent)
        lineLeading = max(lineLeading, glyphRun.leading)
        lineExtent += glyphRun.width
    }

    return ComposedLine(
        startIndex: range.lowerBound,
        endIndex: range.upperBound,
        paragraphLevel: paragraphLevel,
        ascent: lineAscent,
        descent: lineDescent,
        leading: lineLeading,
        extent: lineExtent,
        trailingWhitespaceExtent: trailingWhitespaceExtent,
        visualRuns: visualRuns)
}

struct LineResolver {
    private var text: NSAttributedString
    private var defaultAttributes: [NSAttributedString.Key: Any]
    private var paragraphs: [BidiParagraph]
    private var runs: [IntrinsicRun]

    init(text: NSAttributedString,
         defaultAttributes: [NSAttributedString.Key: Any],
         paragraphs: [BidiParagraph],
         runs: [IntrinsicRun]) {
        self.text = text
        self.defaultAttributes = defaultAttributes
        self.paragraphs = paragraphs
        self.runs = runs
    }

    func makeSimpleLine(range: Range<String.Index>) -> ComposedLine {
        var lineRuns: [GlyphRun] = []

        paragraphs.forEachLineRun(inCharacterRange: range) { (bidiRun) in
            appendVisualRuns(forCharacterRange: bidiRun.startIndex ..< bidiRun.endIndex, visualRuns: &lineRuns)
        }

        return makeComposedLine(text: text.string,
                                range: range,
                                visualRuns: lineRuns,
                                paragraphLevel: paragraphs.paragraph(forCharacterAt: range.lowerBound).baseLevel)
    }

    func appendVisualRuns(forCharacterRange range: Range<String.Index>, visualRuns: inout [GlyphRun]) {
        // ASSUMPTIONS:
        //      - Visual range may fall in one or more glyph runs.
        //      - Consecutive intrinsic runs may have same bidi level.

        var insertIndex = visualRuns.count
        var previousRun: IntrinsicRun?

        var visualStart = range.lowerBound
        let visualEnd = range.upperBound

        repeat {
            let runIndex = runs.binarySearchIndex(ofCharacterAt: visualStart)

            let intrinsicRun = runs[runIndex]
            let feasibleStart = max(intrinsicRun.startIndex, visualStart)
            let feasibleEnd = min(intrinsicRun.endIndex, visualEnd)

            let bidiLevel = intrinsicRun.bidiLevel
            let isForwardRun = (bidiLevel & 1) == 0

            if let previousRun = previousRun {
                if bidiLevel != previousRun.bidiLevel || isForwardRun {
                    insertIndex = runs.count
                }
            }

            let string = text.string
            let chunkRange: NSRange = string.utf16Range(forCharacterRange: feasibleStart ..< feasibleEnd)

            text.enumerateAttributes(in: chunkRange, options: []) { (attributes, spanRange, stop) in
                var allAttributes = defaultAttributes
                attributes.forEach({ allAttributes[$0] = $1 })

                let glyphRun = makeGlyphRun(intrinsicRun: intrinsicRun,
                                            range: string.characterRange(forUTF16Range: spanRange),
                                            attributes: allAttributes)
                visualRuns.insert(glyphRun, at: insertIndex)

                if isForwardRun {
                    insertIndex += 1
                }
            }

            previousRun = intrinsicRun
            visualStart = feasibleEnd
        } while visualStart < visualEnd
    }
}
