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
import UIKit

extension TextContainer {
    func selectionRects(forCodeUnitRange codeUnitRange: Range<Int>) -> [CGRect] {
        guard let textFrame = textFrame else {
            return []
        }

        let frameRange = textFrame.codeUnitRange
        let rangeStart = max(codeUnitRange.lowerBound, frameRange.lowerBound)
        let rangeEnd = min(codeUnitRange.upperBound, frameRange.upperBound)
        guard rangeStart < rangeEnd else {
            return []
        }

        let firstIndex = textFrame.indexOfLine(forCodeUnitAt: rangeStart)
        let lastIndex = textFrame.indexOfLine(forCodeUnitAt: rangeEnd - 1)
        guard firstIndex >= 0 && lastIndex >= firstIndex else {
            return []
        }

        let frameWidth = textFrame.width
        var rects: [CGRect] = []

        for index in firstIndex ... lastIndex {
            let textLine = textFrame.lines[index]
            let isRTL = (textLine.paragraphLevel & 1) == 1

            var left = CGFloat.infinity
            var right = -CGFloat.infinity

            func include(_ from: CGFloat, _ to: CGFloat) {
                left = min(left, max(from, 0.0))
                right = max(right, min(to, frameWidth))
            }

            let segmentStart = max(rangeStart, textLine.codeUnitRange.lowerBound)
            let segmentEnd = min(rangeEnd, textLine.codeUnitRange.upperBound)

            if segmentStart < segmentEnd {
                let edges = textLine.visualEdges(forCodeUnitRange: segmentStart ..< segmentEnd)

                for i in stride(from: 0, to: edges.count, by: 2) {
                    include(edges[i] + textLine.left, edges[i + 1] + textLine.left)
                }
            }

            if firstIndex != lastIndex {
                switch index {
                case firstIndex:
                    // The padding that follows the text of the first line...
                    if isRTL {
                        include(0.0, textLine.left)
                    } else {
                        include(textLine.right, frameWidth)
                    }
                case lastIndex:
                    // ...and the padding that leads to the text of the last one.
                    if isRTL {
                        include(textLine.right, frameWidth)
                    } else {
                        include(0.0, textLine.left)
                    }
                default:
                    // Every line in between is covered entirely.
                    include(0.0, frameWidth)
                }
            }

            if left < right {
                rects.append(CGRect(x: left, y: textLine.top, width: right - left, height: textLine.height))
            }
        }

        return rects
    }

    func selectionRects(forCharacterRange characterRange: Range<String.Index>) -> [CGRect] {
        guard let textFrame = textFrame else {
            return []
        }

        return selectionRects(forCodeUnitRange: textFrame.string.utf16Range(forCharacterRange: characterRange))
    }

    func rects(for replacement: TextReplacement) -> [CGRect] {
        guard let textFrame = textFrame else {
            return []
        }

        var rects: [CGRect] = []

        for textLine in textFrame.lines {
            for glyphRun in textLine.visualRuns {
                guard let replacementRun = glyphRun.textRun as? ReplacementRun,
                      replacementRun.replacement === replacement else {
                    continue
                }

                let runRect = CGRect(
                    x: textLine.origin.x + glyphRun.origin.x,
                    y: textLine.origin.y - glyphRun.ascent,
                    width: glyphRun.width,
                    height: glyphRun.height
                )

                if let attachment = replacement as? ViewAttachment {
                    rects.append(attachment.viewFrame(in: runRect, frameWidth: textFrame.width))
                } else {
                    rects.append(runRect)
                }
            }
        }

        return rects
    }

    func boundingRect(for replacement: TextReplacement) -> CGRect? {
        return rects(for: replacement).reduce(nil) { (union: CGRect?, rect) in
            union?.union(rect) ?? rect
        }
    }
}
