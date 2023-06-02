//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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

struct ShapeResolver {
    let text: NSAttributedString
    let defaultAttributes: [NSAttributedString.Key: Any]

    private let string: String

    init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        self.text = text
        self.defaultAttributes = defaultAttributes
        self.string = text.string
    }

    func makeParagraphsAndRuns() -> (paragraphs: [BidiParagraph], runs: [IntrinsicRun]) {
        var paragraphs: [BidiParagraph] = []
        var runs: [IntrinsicRun] = []

        let bidiAlgorithm = BidiAlgorithm(string: string)
        let scriptClassifier = ScriptClassifier(string: string)
        let shapingEngine = ShapingEngine()

        var runLocator = ShapingRunLocator(text: text, defaultAttributes: defaultAttributes)
        var chunkRange = string.startIndex ..< string.endIndex

        while !chunkRange.isEmpty {
            guard let bidiParagraph = bidiAlgorithm?.makeParagraph(characterRange: chunkRange, direction: .defaultLeftToRight) else {
                return ([], [])
            }

            for bidiRun in bidiParagraph.logicalRuns {
                for scriptRun in scriptClassifier.scriptRuns(forCharacterRange: bidiRun.startIndex ..< bidiRun.endIndex) {
                    let scriptTag = scriptRun.script.openTypeTag
                    let writingDirection = ShapingEngine.defaultDirectionForScript(scriptTag)

                    let isRTL = bidiRun.isRightToLeft
                    let isBackward = (isRTL && writingDirection == .leftToRight)
                                  || (!isRTL && writingDirection == .rightToLeft)
                    let shapingOrder: ShapingOrder = (isBackward ? .backward : .forward)

                    runLocator.reset(for: scriptRun.codeUnitRange)

                    shapingEngine.scriptTag = scriptTag
                    shapingEngine.writingDirection = writingDirection
                    shapingEngine.shapingOrder = shapingOrder

                    resolveTypefaces(runs: &runs, runLocator: &runLocator,
                                     shapingEngine: shapingEngine, bidiLevel: bidiRun.embeddingLevel)
                }
            }
            paragraphs.append(bidiParagraph)

            chunkRange = bidiParagraph.endIndex ..< string.endIndex
        }

        return (paragraphs, runs)
    }

    func resolveTypefaces(runs: inout [IntrinsicRun], runLocator: inout ShapingRunLocator,
                          shapingEngine: ShapingEngine, bidiLevel: UInt8) {
        while let shapingRun = runLocator.next() {
            guard let typeface = shapingRun.typeface else {
                fatalError("Typeface is not specified")
            }

            shapingEngine.typeface = typeface
            shapingEngine.typeSize = shapingRun.typeSize

            let shapingResult = shapingEngine.shape(string: string, codeUnitRange: shapingRun.codeUnitRange)

            let typeSize = shapingRun.typeSize
            let sizeByEm = typeSize / CGFloat(typeface.unitsPerEm)
            let sizeScale = sizeByEm * shapingRun.scaleY
            let ascent = CGFloat(typeface.ascent) * sizeScale
            let descent = CGFloat(typeface.descent) * sizeScale
            let leading = CGFloat(typeface.leading) * sizeScale

            let glyphIDs = Array(shapingResult.glyphIDs)
            var glyphOffsets = Array(shapingResult.glyphOffsets)
            var glyphAdvances = Array(shapingResult.glyphAdvances)
            let clusterMap = Array(shapingResult.clusterMap)
            let caretEdges = shapingResult.makeCaretEdges(caretStops: nil)

            if shapingRun.scaleX != 1.0 || shapingRun.scaleY != 1.0 {
                for i in 0 ..< glyphOffsets.count {
                    glyphOffsets[i].x *= shapingRun.scaleX
                    glyphOffsets[i].y *= shapingRun.scaleY
                }

                for i in 0 ..< glyphAdvances.count {
                    glyphAdvances[i] *= shapingRun.scaleX
                }
            }

            let baselineOffset = shapingRun.baselineOffset
            if baselineOffset != .zero {
                for i in 0 ..< glyphOffsets.count {
                    glyphOffsets[i].y += baselineOffset
                }
            }

            let intrinsicRun = IntrinsicRun(
                string: string,
                codeUnitRange: shapingRun.codeUnitRange,
                isBackward: shapingResult.isBackward,
                bidiLevel: bidiLevel,
                writingDirection: shapingEngine.writingDirection,
                typeface: typeface,
                typeSize: typeSize,
                ascent: ascent,
                descent: descent,
                leading: leading,
                glyphIDs: PrimitiveCollection(glyphIDs),
                glyphOffsets: PrimitiveCollection(glyphOffsets),
                glyphAdvances: PrimitiveCollection(glyphAdvances),
                clusterMap: PrimitiveCollection(clusterMap),
                caretEdges: PrimitiveCollection(caretEdges)
            )

            runs.append(intrinsicRun)
        }
    }
}
