//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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
        var runArray: [GlyphRun] = []

        paragraphs.forEachLineRun(inCharacterRange: range) { (bidiRun) in
            appendVisualRuns(from: bidiRun.startIndex, to: bidiRun.endIndex, in: &runArray)
        }

        return makeComposedLine(text: text.string,
                                range: range,
                                visualRuns: runArray,
                                paragraphLevel: paragraphs.baseLevel(forCharacterAt: range.lowerBound))
    }

    func makeCompactLine(range: Range<String.Index>, extent: CGFloat,
                         breaks: BreakResolver, mode: BreakMode, place: TruncationPlace,
                         token: ComposedLine) -> ComposedLine {
        let tokenlessWidth = extent - token.width;

        switch (place) {
        case .start:
            return makeStartTruncatedLine(range: range, tokenlessWidth: tokenlessWidth,
                                          breaks: breaks, mode: mode, token: token)
        case .middle:
            return makeMiddleTruncatedLine(range: range, tokenlessWidth: tokenlessWidth,
                                           breaks: breaks, mode: mode, token: token)
        case .end:
            return makeEndTruncatedLine(range: range, tokenlessWidth: tokenlessWidth,
                                        breaks: breaks, mode: mode, token: token)
        }
    }

    private struct TruncationHandler {
        let range: Range<String.Index>
        let skipStart: String.Index
        let skipEnd: String.Index

        var leadingTokenIndex = -1
        var trailingTokenIndex = -1

        init(range: Range<String.Index>, skipStart: String.Index, skipEnd: String.Index) {
            self.range = range
            self.skipStart = skipStart
            self.skipEnd = skipEnd
        }

        mutating func appendAllRuns(using resolver: LineResolver, in runArray: inout [GlyphRun]) {
            resolver.paragraphs.forEachLineRun(inCharacterRange: range) { (bidiRun) in
                let visualStart = bidiRun.startIndex
                let visualEnd = bidiRun.endIndex

                if bidiRun.isRightToLeft {
                    // Handle second part of characters.
                    if visualEnd >= skipEnd {
                        resolver.appendVisualRuns(from: max(visualStart, skipEnd), to: visualEnd, in: &runArray)

                        if visualStart < skipEnd {
                            trailingTokenIndex = runArray.count
                        }
                    }

                    // Handle first part of characters.
                    if visualStart <= skipStart {
                        if visualEnd > skipStart {
                            leadingTokenIndex = runArray.count
                        }

                        resolver.appendVisualRuns(from: visualStart, to: min(visualEnd, skipStart), in: &runArray)
                    }
                } else {
                    // Handle first part of characters.
                    if visualStart <= skipStart {
                        resolver.appendVisualRuns(from: visualStart, to: min(visualEnd, skipStart), in: &runArray)

                        if visualEnd > skipStart {
                            leadingTokenIndex = runArray.count
                        }
                    }

                    // Handle second part of characters.
                    if visualEnd >= skipEnd {
                        if visualStart < skipEnd {
                            trailingTokenIndex = runArray.count
                        }

                        resolver.appendVisualRuns(from: max(visualStart, skipEnd), to: visualEnd, in: &runArray)
                    }
                }
            }
        }
    }

    private func makeStartTruncatedLine(range: Range<String.Index>,
                                        tokenlessWidth: CGFloat,
                                        breaks: BreakResolver,
                                        mode: BreakMode,
                                        token: ComposedLine) -> ComposedLine {
        let truncatedStart = breaks.suggestBackwardBreak(for: tokenlessWidth, in: range, with: mode)
        if truncatedStart > range.lowerBound {
            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if truncatedStart < range.upperBound {
                var truncationHandler = TruncationHandler(range: range,
                                                          skipStart: range.lowerBound,
                                                          skipEnd: truncatedStart)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.trailingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(text: text.string,
                                    range: truncatedStart ..< range.upperBound,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCharacterAt: truncatedStart))
        }

        return makeSimpleLine(range: truncatedStart ..< range.upperBound)
    }

    private func makeMiddleTruncatedLine(range: Range<String.Index>,
                                         tokenlessWidth: CGFloat,
                                         breaks: BreakResolver,
                                         mode: BreakMode,
                                         token: ComposedLine) -> ComposedLine {
        let halfWidth = tokenlessWidth / 2.0
        var firstMidEnd = breaks.suggestForwardBreak(for: halfWidth, in: range, with: mode)
        var secondMidStart = breaks.suggestBackwardBreak(for: halfWidth, in: range, with: mode)

        if firstMidEnd < secondMidStart {
            // Exclude inner whitespaces as truncation token replaces them.
            firstMidEnd = text.string.trailingWhitespaceStart(in: range.lowerBound ..< firstMidEnd)
            secondMidStart = text.string.leadingWhitespaceEnd(in: secondMidStart ..< range.upperBound)

            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if range.lowerBound < firstMidEnd || secondMidStart < range.upperBound {
                var truncationHandler = TruncationHandler(range: range,
                                                          skipStart: firstMidEnd,
                                                          skipEnd: secondMidStart)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.leadingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(text: text.string,
                                    range: range,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCharacterAt: range.lowerBound))
        }

        return makeSimpleLine(range: range)
    }

    private func makeEndTruncatedLine(range: Range<String.Index>,
                                      tokenlessWidth: CGFloat,
                                      breaks: BreakResolver,
                                      mode: BreakMode,
                                      token: ComposedLine) -> ComposedLine {
        var truncatedEnd = breaks.suggestForwardBreak(for: tokenlessWidth, in: range, with: mode)
        if truncatedEnd < range.upperBound {
            // Exclude trailing whitespaces as truncation token replaces them.
            truncatedEnd = text.string.trailingWhitespaceStart(in: range.lowerBound ..< truncatedEnd)

            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if range.lowerBound < truncatedEnd {
                var truncationHandler = TruncationHandler(range: range,
                                                          skipStart: truncatedEnd,
                                                          skipEnd: range.upperBound)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.leadingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(text: text.string,
                                    range: range.lowerBound ..< truncatedEnd,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCharacterAt: range.lowerBound))
        }

        return makeSimpleLine(range: range.lowerBound ..< truncatedEnd)
    }

    private func appendTokenRuns(_ token: ComposedLine, in runArray: inout [GlyphRun], at index: Int) {
        var insertIndex = index

        for truncationRun in token.visualRuns {
            let modifiedRun = GlyphRun(truncationRun)
            runArray.insert(modifiedRun, at: insertIndex)

            insertIndex += 1
        }
    }

    private func appendVisualRuns(from start: String.Index, to end: String.Index, in runArray: inout [GlyphRun]) {
        guard start < end else { return }

        // ASSUMPTIONS:
        //      - Visual range may fall in one or more glyph runs.
        //      - Consecutive intrinsic runs may have same bidi level.

        var insertIndex = runArray.count
        var previousRun: IntrinsicRun?

        var visualStart = start
        let visualEnd = end

        repeat {
            let runIndex = runs.binarySearchIndex(ofCharacterAt: visualStart)

            let intrinsicRun = runs[runIndex]
            let feasibleStart = max(intrinsicRun.startIndex, visualStart)
            let feasibleEnd = min(intrinsicRun.endIndex, visualEnd)

            let bidiLevel = intrinsicRun.bidiLevel
            let isForwardRun = (bidiLevel & 1) == 0

            if let previousRun = previousRun {
                if bidiLevel != previousRun.bidiLevel || isForwardRun {
                    insertIndex = runArray.count
                }
            }

            let string = text.string
            let chunkRange: NSRange = string.utf16Range(forCharacterRange: feasibleStart ..< feasibleEnd)

            let attrString = text as CFAttributedString
            let effectiveRange = CFRange(location: chunkRange.location, length: chunkRange.length)
            var spanRange = CFRange(location: chunkRange.location, length: 0)

            while spanRange.location < chunkRange.upperBound {
                defer { spanRange.location += spanRange.length }

                let spanAttributes = CFAttributedStringGetAttributesAndLongestEffectiveRange(attrString, spanRange.location, effectiveRange, &spanRange);
                var allAttributes = defaultAttributes

                if let dictionary = spanAttributes {
                    for (key, value) in dictionary as NSDictionary {
                        guard let stringKey = key as? String else {
                            continue
                        }

                        allAttributes[NSAttributedString.Key(stringKey)] = value
                    }
                }

                let utf16Range = NSRange(location: spanRange.location, length: spanRange.length)
                let runRange = string.characterRange(forUTF16Range: utf16Range)
                let glyphRun = makeGlyphRun(intrinsicRun: intrinsicRun,
                                            range: runRange,
                                            attributes: allAttributes)
                runArray.insert(glyphRun, at: insertIndex)

                if isForwardRun {
                    insertIndex += 1
                }
            }

            previousRun = intrinsicRun
            visualStart = feasibleEnd
        } while visualStart < visualEnd
    }
}
