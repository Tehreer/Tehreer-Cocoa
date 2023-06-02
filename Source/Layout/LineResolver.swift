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
                  codeUnitRange: Range<Int>,
                  attributes: [NSAttributedString.Key: Any]) -> GlyphRun {
    let string = intrinsicRun.string
    let runOffset = intrinsicRun.codeUnitRange.lowerBound
    let clusterRange = intrinsicRun.clusterRange(forUTF16Range: codeUnitRange)
    let glyphRange = intrinsicRun.glyphRange(forCodeUnitRange: codeUnitRange)

    let startExtraLength = codeUnitRange.lowerBound - clusterRange.lowerBound
    let endExtraLength = clusterRange.upperBound - codeUnitRange.upperBound

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
        codeUnitRange: codeUnitRange,
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

func makeComposedLine(string: String,
                      codeUnitRange: Range<Int>,
                      visualRuns: [GlyphRun],
                      paragraphLevel: UInt8) -> ComposedLine {
    var lineAscent: CGFloat = 0.0
    var lineDescent: CGFloat = 0.0
    var lineLeading: CGFloat = 0.0
    var lineExtent: CGFloat = 0.0

    let trailingWhitespaceStart = string.trailingWhitespaceStart(in: codeUnitRange)
    var trailingWhitespaceExtent: CGFloat = 0.0

    for glyphRun in visualRuns {
        glyphRun.origin.x = lineExtent

        let runRange = glyphRun.codeUnitRange
        let wsStart = max(runRange.lowerBound, trailingWhitespaceStart)
        let wsEnd = min(runRange.upperBound, codeUnitRange.upperBound)

        if wsStart < wsEnd {
            let wsRange = Range(uncheckedBounds: (wsStart, wsEnd))
            trailingWhitespaceExtent = glyphRun.distance(forCodeUnitRange: wsRange)
        }

        lineAscent = max(lineAscent, glyphRun.ascent)
        lineDescent = max(lineDescent, glyphRun.descent)
        lineLeading = max(lineLeading, glyphRun.leading)
        lineExtent += glyphRun.width
    }

    return ComposedLine(
        string: string,
        codeUnitRange: codeUnitRange,
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

    func makeSimpleLine(codeUnitRange: Range<Int>) -> ComposedLine {
        var lineRuns: [GlyphRun] = []

        paragraphs.forEachLineRun(in: codeUnitRange) { (bidiRun) in
            let runRange = bidiRun.codeUnitRange
            appendVisualRuns(from: runRange.lowerBound, to: runRange.upperBound, in: &lineRuns)
        }

        return makeComposedLine(string: text.string,
                                codeUnitRange: codeUnitRange,
                                visualRuns: lineRuns,
                                paragraphLevel: paragraphs.paragraph(forCodeUnitAt: codeUnitRange.lowerBound).baseLevel)
    }

    func makeCompactLine(codeUnitRange: Range<Int>, extent: CGFloat,
                         breaks: BreakResolver, mode: BreakMode, place: TruncationPlace,
                         token: ComposedLine) -> ComposedLine {
        let tokenlessWidth = extent - token.width;

        switch (place) {
        case .start:
            return makeStartTruncatedLine(codeUnitRange: codeUnitRange, tokenlessWidth: tokenlessWidth,
                                          breaks: breaks, mode: mode, token: token)
        case .middle:
            return makeMiddleTruncatedLine(codeUnitRange: codeUnitRange, tokenlessWidth: tokenlessWidth,
                                           breaks: breaks, mode: mode, token: token)
        case .end:
            return makeEndTruncatedLine(codeUnitRange: codeUnitRange, tokenlessWidth: tokenlessWidth,
                                        breaks: breaks, mode: mode, token: token)
        }
    }

    private struct TruncationHandler {
        let codeUnitRange: Range<Int>
        let skipStart: Int
        let skipEnd: Int

        var leadingTokenIndex = -1
        var trailingTokenIndex = -1

        init(codeUnitRange: Range<Int>, skipStart: Int, skipEnd: Int) {
            self.codeUnitRange = codeUnitRange
            self.skipStart = skipStart
            self.skipEnd = skipEnd
        }

        mutating func appendAllRuns(using resolver: LineResolver, in runArray: inout [GlyphRun]) {
            resolver.paragraphs.forEachLineRun(in: codeUnitRange) { (bidiRun) in
                let runRange = bidiRun.codeUnitRange
                let visualStart = runRange.lowerBound
                let visualEnd = runRange.upperBound

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

    private func makeStartTruncatedLine(codeUnitRange: Range<Int>,
                                        tokenlessWidth: CGFloat,
                                        breaks: BreakResolver,
                                        mode: BreakMode,
                                        token: ComposedLine) -> ComposedLine {
        let truncatedStart = breaks.suggestBackwardBreak(for: tokenlessWidth, in: codeUnitRange, with: mode)
        if truncatedStart > codeUnitRange.lowerBound {
            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if truncatedStart < codeUnitRange.upperBound {
                var truncationHandler = TruncationHandler(codeUnitRange: codeUnitRange,
                                                          skipStart: codeUnitRange.lowerBound,
                                                          skipEnd: truncatedStart)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.trailingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(string: text.string,
                                    codeUnitRange: truncatedStart ..< codeUnitRange.upperBound,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCodeUnitAt: truncatedStart))
        }

        return makeSimpleLine(codeUnitRange: truncatedStart ..< codeUnitRange.upperBound)
    }

    private func makeMiddleTruncatedLine(codeUnitRange: Range<Int>,
                                         tokenlessWidth: CGFloat,
                                         breaks: BreakResolver,
                                         mode: BreakMode,
                                         token: ComposedLine) -> ComposedLine {
        let halfWidth = tokenlessWidth / 2.0
        var firstMidEnd = breaks.suggestForwardBreak(for: halfWidth, in: codeUnitRange, with: mode)
        var secondMidStart = breaks.suggestBackwardBreak(for: halfWidth, in: codeUnitRange, with: mode)

        if firstMidEnd < secondMidStart {
            // Exclude inner whitespaces as truncation token replaces them.
            firstMidEnd = text.string.trailingWhitespaceStart(in: codeUnitRange.lowerBound ..< firstMidEnd)
            secondMidStart = text.string.leadingWhitespaceEnd(in: secondMidStart ..< codeUnitRange.upperBound)

            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if codeUnitRange.lowerBound < firstMidEnd || secondMidStart < codeUnitRange.upperBound {
                var truncationHandler = TruncationHandler(codeUnitRange: codeUnitRange,
                                                          skipStart: firstMidEnd,
                                                          skipEnd: secondMidStart)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.leadingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(string: text.string,
                                    codeUnitRange: codeUnitRange,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCodeUnitAt: codeUnitRange.lowerBound))
        }

        return makeSimpleLine(codeUnitRange: codeUnitRange)
    }

    private func makeEndTruncatedLine(codeUnitRange: Range<Int>,
                                      tokenlessWidth: CGFloat,
                                      breaks: BreakResolver,
                                      mode: BreakMode,
                                      token: ComposedLine) -> ComposedLine {
        var truncatedEnd = breaks.suggestForwardBreak(for: tokenlessWidth, in: codeUnitRange, with: mode)
        if truncatedEnd < codeUnitRange.upperBound {
            // Exclude trailing whitespaces as truncation token replaces them.
            truncatedEnd = text.string.trailingWhitespaceStart(in: codeUnitRange.lowerBound ..< truncatedEnd)

            var runArray: [GlyphRun] = []
            var tokenInsertIndex = 0

            if codeUnitRange.lowerBound < truncatedEnd {
                var truncationHandler = TruncationHandler(codeUnitRange: codeUnitRange,
                                                          skipStart: truncatedEnd,
                                                          skipEnd: codeUnitRange.upperBound)
                truncationHandler.appendAllRuns(using: self, in: &runArray)

                tokenInsertIndex = truncationHandler.leadingTokenIndex
            }
            appendTokenRuns(token, in: &runArray, at: tokenInsertIndex)

            return makeComposedLine(string: text.string,
                                    codeUnitRange: codeUnitRange.lowerBound ..< truncatedEnd,
                                    visualRuns: runArray,
                                    paragraphLevel: paragraphs.baseLevel(forCodeUnitAt: codeUnitRange.lowerBound))
        }

        return makeSimpleLine(codeUnitRange: codeUnitRange.lowerBound ..< truncatedEnd)
    }

    private func appendTokenRuns(_ token: ComposedLine, in runArray: inout [GlyphRun], at index: Int) {
        var insertIndex = index

        for truncationRun in token.visualRuns {
            let modifiedRun = GlyphRun(truncationRun)
            runArray.insert(modifiedRun, at: insertIndex)

            insertIndex += 1
        }
    }

    private func appendVisualRuns(from start: Int, to end: Int, in runArray: inout [GlyphRun]) {
        guard start < end else { return }

        // ASSUMPTIONS:
        //      - Visual range may fall in one or more glyph runs.
        //      - Consecutive intrinsic runs may have same bidi level.

        var insertIndex = runArray.count
        var previousRun: IntrinsicRun?

        var visualStart = start
        let visualEnd = end

        repeat {
            let runIndex = runs.binarySearchIndex(forCodeUnitAt: visualStart)

            let intrinsicRun = runs[runIndex]
            let runRange = intrinsicRun.codeUnitRange
            let feasibleStart = max(runRange.lowerBound, visualStart)
            let feasibleEnd = min(runRange.upperBound, visualEnd)

            let bidiLevel = intrinsicRun.bidiLevel
            let isForwardRun = (bidiLevel & 1) == 0

            if let previousRun = previousRun {
                if bidiLevel != previousRun.bidiLevel || isForwardRun {
                    insertIndex = runArray.count
                }
            }

            let string = text.string
            let attrString = text as CFAttributedString
            let effectiveRange = CFRange(location: feasibleStart, length: feasibleEnd - feasibleStart)
            var spanRange = CFRange(location: feasibleStart, length: 0)

            while spanRange.location < feasibleEnd {
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

                let codeUnitRange = spanRange.location ..< spanRange.location + spanRange.length
                let glyphRun = makeGlyphRun(intrinsicRun: intrinsicRun,
                                            codeUnitRange: codeUnitRange,
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
