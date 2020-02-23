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

struct BreakResolver {
    let string: String
    let paragraphs: [BidiParagraph]
    let runs: [IntrinsicRun]
    let breaks: BreakClassifier

    private func findForwardBreak<S>(for extent: CGFloat, in sequence: S, from startIndex: Int) -> Int
        where S: Sequence,
              S.Element == StringBreak {
        var forwardIndex = startIndex
        var measurement: CGFloat = 0.0

        for stringBreak in sequence {
            let endIndex = stringBreak.codeUnitIndex
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

    private func findBackwardBreak<S>(for extent: CGFloat, in sequence: S, from endIndex: Int) -> Int
        where S: Sequence,
              S.Element == StringBreak {
        var backwardIndex = endIndex
        var measurement: CGFloat = 0.0

        for stringBreak in sequence {
            let startIndex = stringBreak.codeUnitIndex
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

    func findForwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        let paragraph = paragraphs.paragraph(forCodeUnitAt: codeUnitRange.lowerBound)
        let maxIndex = min(codeUnitRange.upperBound, paragraph.codeUnitRange.upperBound)
        let clampedRange = codeUnitRange.lowerBound ..< maxIndex

        switch breakMode {
        case .character:
            let sequence = breaks.forwardGraphemeBreaks(forCodeUnitRange: clampedRange)
            return findForwardBreak(for: extent, in: sequence, from: codeUnitRange.lowerBound)
        case .line:
            let sequence = breaks.forwardLineBreaks(forCodeUnitRange: clampedRange)
            return findForwardBreak(for: extent, in: sequence, from: codeUnitRange.lowerBound)
        }
    }

    func findForwardBreak(for extent: CGFloat, in characterRange: Range<String.Index>, with breakMode: BreakMode) -> String.Index {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = findForwardBreak(for: extent, in: codeUnitRange, with: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }

    func findBackwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        let paragraph = paragraphs.paragraph(forCodeUnitAt: codeUnitRange.lowerBound)
        let minIndex = min(codeUnitRange.lowerBound, paragraph.codeUnitRange.lowerBound)
        let clampedRange = minIndex ..< codeUnitRange.upperBound

        switch breakMode {
        case .character:
            let sequence = breaks.backwardGraphemeBreaks(forCodeUnitRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, from: codeUnitRange.upperBound)
        case .line:
            let sequence = breaks.backwardLineBreaks(forCodeUnitRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, from: codeUnitRange.upperBound)
        }
    }

    func findBackwardBreak(for extent: CGFloat, in characterRange: Range<String.Index>, with breakMode: BreakMode) -> String.Index {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = findBackwardBreak(for: extent, in: codeUnitRange, with: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }

    private func suggestForwardCharacterBreak(for extent: CGFloat, in codeUnitRange: Range<Int>) -> Int {
        let breakIndex = findForwardBreak(for: extent, in: codeUnitRange, with: .character)

        // Take at least one character (grapheme) if extent is too small.
        if breakIndex == codeUnitRange.lowerBound {
            return min(codeUnitRange.upperBound, breakIndex + 1)
        }

        return breakIndex
    }

    private func suggestBackwardCharacterBreak(for extent: CGFloat, in codeUnitRange: Range<Int>) -> Int {
        let breakIndex = findBackwardBreak(for: extent, in: codeUnitRange, with: .character)

        // Take at least one character (grapheme) if extent is too small.
        if breakIndex == codeUnitRange.upperBound {
            return max(codeUnitRange.lowerBound, breakIndex - 1)
        }

        return breakIndex
    }

    private func suggestForwardLineBreak(for extent: CGFloat, in codeUnitRange: Range<Int>) -> Int {
        let breakIndex = findForwardBreak(for: extent, in: codeUnitRange, with: .line)

        // Fallback to character break if no line break occurs in desired extent.
        if breakIndex == codeUnitRange.lowerBound {
            return suggestForwardCharacterBreak(for: extent, in: codeUnitRange)
        }

        return breakIndex
    }

    private func suggestBackwardLineBreak(for extent: CGFloat, in codeUnitRange: Range<Int>) -> Int {
        let breakIndex = findBackwardBreak(for: extent, in: codeUnitRange, with: .line)

        // Fallback to character break if no line break occurs in desired extent.
        if breakIndex == codeUnitRange.upperBound {
            return suggestBackwardCharacterBreak(for: extent, in: codeUnitRange)
        }

        return breakIndex
    }

    func suggestForwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        switch breakMode {
        case .character:
            return suggestForwardCharacterBreak(for: extent, in: codeUnitRange)
        case .line:
            return suggestForwardLineBreak(for: extent, in: codeUnitRange)
        }
    }

    func suggestForwardBreak(for extent: CGFloat, in characterRange: Range<String.Index>, with breakMode: BreakMode) -> String.Index {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = suggestForwardBreak(for: extent, in: codeUnitRange, with: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }

    func suggestBackwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        switch breakMode {
        case .character:
            return suggestBackwardCharacterBreak(for: extent, in: codeUnitRange)
        case .line:
            return suggestBackwardLineBreak(for: extent, in: codeUnitRange)
        }
    }

    func suggestBackwardBreak(for extent: CGFloat, in characterRange: Range<String.Index>, with breakMode: BreakMode) -> String.Index {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = suggestBackwardBreak(for: extent, in: codeUnitRange, with: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }
}
