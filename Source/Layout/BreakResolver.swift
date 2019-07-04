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

struct BreakResolver {
    let string: String
    let paragraphs: [BidiParagraph]
    let runs: [IntrinsicRun]
    let breaks: BreakClassifier

    private func findForwardBreak<S>(for extent: CGFloat, in sequence: S, with startIndex: String.Index) -> String.Index
        where S: Sequence,
              S.Element == String.Index {
        var forwardIndex = startIndex
        var measurement: CGFloat = 0.0

        for endIndex in sequence {
            let segmentRange = forwardIndex ..< endIndex

            measurement += runs.measureCharacters(in: segmentRange)
            if measurement > extent {
                let wsStart = string.trailingWhitespaceStart(in: segmentRange)
                let wsExtent = runs.measureCharacters(in: wsStart ..< endIndex)

                // Break if excluding whitespace extent helps.
                if (measurement - wsExtent) <= extent {
                    forwardIndex = endIndex
                }
                break
            }

            forwardIndex = endIndex
        }

        return forwardIndex
    }

    private func findBackwardBreak<S>(for extent: CGFloat, in sequence: S, with endIndex: String.Index) -> String.Index
        where S: Sequence,
              S.Element == String.Index {
        var backwardIndex = endIndex
        var measurement: CGFloat = 0.0

        for startIndex in sequence {
            let segmentRange = startIndex ..< backwardIndex
            measurement += runs.measureCharacters(in: segmentRange)

            if measurement > extent {
                let wsStart = string.trailingWhitespaceStart(in: segmentRange)
                let wsExtent = runs.measureCharacters(in: wsStart ..< backwardIndex)

                // Break if excluding whitespace extent helps.
                if (measurement - wsExtent) <= extent {
                    backwardIndex = startIndex
                }
                break
            }

            backwardIndex = startIndex
        }

        return backwardIndex
    }

    func findForwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let paragraph = paragraphs.paragraph(forCharacterAt: range.lowerBound)
        let clampedRange = range.lowerBound ..< min(range.upperBound, paragraph.endIndex)

        switch mode {
        case .character:
            let sequence = breaks.forwardGraphemeBreaks(forCharacterRange: clampedRange)
            return findForwardBreak(for: extent, in: sequence, with: range.lowerBound)
        case .line:
            let sequence = breaks.forwardLineBreaks(forCharacterRange: clampedRange)
            return findForwardBreak(for: extent, in: sequence, with: range.lowerBound)
        }
    }

    func findBackwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let paragraph = paragraphs.paragraph(forCharacterAt: range.lowerBound)
        let clampedRange = min(range.lowerBound, paragraph.startIndex) ..< range.upperBound

        switch mode {
        case .character:
            let sequence = breaks.backwardGraphemeBreaks(forCharacterRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, with: range.upperBound)
        case .line:
            let sequence = breaks.backwardLineBreaks(forCharacterRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, with: range.upperBound)
        }
    }

    private func suggestForwardCharacterBreak(for extent: CGFloat, in range: Range<String.Index>) -> String.Index {
        let breakIndex = findForwardBreak(for: extent, in: range, with: .character)

        // Take at least one character (grapheme) if extent is too small.
        if breakIndex == range.lowerBound {
            return min(range.upperBound, string.index(after: breakIndex))
        }

        return breakIndex
    }

    private func suggestBackwardCharacterBreak(for extent: CGFloat, in range: Range<String.Index>) -> String.Index {
        let breakIndex = findBackwardBreak(for: extent, in: range, with: .character)

        // Take at least one character (grapheme) if extent is too small.
        if breakIndex == range.upperBound {
            return max(range.lowerBound, string.index(before: breakIndex))
        }

        return breakIndex
    }

    private func suggestForwardLineBreak(for extent: CGFloat, in range: Range<String.Index>) -> String.Index {
        let breakIndex = findForwardBreak(for: extent, in: range, with: .line)

        // Fallback to character break if no line break occurs in desired extent.
        if breakIndex == range.lowerBound {
            return suggestForwardCharacterBreak(for: extent, in: range)
        }

        return breakIndex
    }

    private func suggestBackwardLineBreak(for extent: CGFloat, in range: Range<String.Index>) -> String.Index {
        let breakIndex = findBackwardBreak(for: extent, in: range, with: .line)

        // Fallback to character break if no line break occurs in desired extent.
        if breakIndex == range.upperBound {
            return suggestBackwardCharacterBreak(for: extent, in: range)
        }

        return breakIndex
    }

    func suggestForwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        switch mode {
        case .character:
            return suggestForwardCharacterBreak(for: extent, in: range)
        case .line:
            return suggestForwardLineBreak(for: extent, in: range)
        }
    }

    func suggestBackwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        switch mode {
        case .character:
            return suggestBackwardCharacterBreak(for: extent, in: range)
        case .line:
            return suggestBackwardLineBreak(for: extent, in: range)
        }
    }
}
