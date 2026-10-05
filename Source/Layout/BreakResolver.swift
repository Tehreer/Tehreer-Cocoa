//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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
    let runs: [TextRun]
    let blocks: [ReplacementRun]
    let breaks: BreakClassifier

    /// The block with the smallest start index that is in `codeUnitRange`: the leftmost block in
    /// the range, which is what the forward search wants.
    private func findBlockForward(in codeUnitRange: Range<Int>) -> ReplacementRun? {
        guard !blocks.isEmpty else { return nil }

        let index = firstBlockIndex(startingAtOrAfter: codeUnitRange.lowerBound)
        guard index < blocks.count else { return nil }

        let block = blocks[index]
        return block.codeUnitRange.lowerBound < codeUnitRange.upperBound ? block : nil
    }

    /// The block nearest the end of `codeUnitRange` among those that start in it: the rightmost
    /// block in the range, which is what the backward search wants.
    private func findBlockBackward(in codeUnitRange: Range<Int>) -> ReplacementRun? {
        guard !blocks.isEmpty else { return nil }

        let index = firstBlockIndex(startingAtOrAfter: codeUnitRange.upperBound) - 1
        guard index >= 0 else { return nil }

        let block = blocks[index]
        return block.codeUnitRange.lowerBound >= codeUnitRange.lowerBound ? block : nil
    }

    private func firstBlockIndex(startingAtOrAfter codeUnitIndex: Int) -> Int {
        var low = 0
        var high = blocks.count

        while low < high {
            let mid = (low + high) >> 1

            if blocks[mid].codeUnitRange.lowerBound < codeUnitIndex {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }

    private func isWhitespace(at index: Int) -> Bool {
        let utf16 = string.utf16
        let unit = utf16[utf16.index(utf16.startIndex, offsetBy: index)]

        return UnicodeScalar(unit)?.properties.isWhitespace ?? false
    }

    private func isNewline(at index: Int) -> Bool {
        let utf16 = string.utf16
        return utf16[utf16.index(utf16.startIndex, offsetBy: index)] == 0x0A
    }

    /// A block that opens its line (nothing comes before it) keeps that line through the
    /// whitespace that follows it, up to and including a newline that ends it, bounded by
    /// `endIndex`, the end of the whole range the break was asked for.
    private func keepBlockLine(_ block: ReplacementRun, until endIndex: Int) -> Int {
        var lineEnd = block.codeUnitRange.upperBound

        while lineEnd < endIndex && isWhitespace(at: lineEnd) {
            lineEnd += 1

            if isNewline(at: lineEnd - 1) {
                break
            }
        }

        return lineEnd
    }

    /// The mirror of `keepBlockLine`: a block that closes its line (nothing comes after it, on
    /// this line) keeps that line through the whitespace that precedes it, up to and including a
    /// newline that starts it, bounded by `startIndex`, the start of the whole range the break
    /// was asked for.
    private func keepBlockLineBackward(_ block: ReplacementRun, from startIndex: Int) -> Int {
        var lineStart = block.codeUnitRange.lowerBound

        while lineStart > startIndex && isWhitespace(at: lineStart - 1) {
            lineStart -= 1

            if isNewline(at: lineStart) {
                break
            }
        }

        return lineStart
    }

    /// A block run (a view that has a line of its own) that turns up while measuring for a break
    /// candidate settles the break right away, from its own position, instead of the extent
    /// accumulated so far: extent comparisons never get a say over a block.
    ///
    /// `startIndex` and `limitIndex` are the whole range this break search was asked for, not the
    /// current candidate step.
    private func findForwardBreak<S>(for extent: CGFloat, in sequence: S, from startIndex: Int, until limitIndex: Int) -> Int
        where S: Sequence,
              S.Element == StringBreak {
        var forwardIndex = startIndex
        var measurement: CGFloat = 0.0

        for stringBreak in sequence {
            let endIndex = stringBreak.codeUnitIndex
            let segmentRange = forwardIndex ..< endIndex

            if let block = findBlockForward(in: segmentRange) {
                // A block that is not the very first thing on the line ends the line right
                // before it, whatever text has been accepted so far; the block gets a line of
                // its own later. A block that is the first thing is the line, its own line
                // stretching through the whitespace that follows it.
                if block.codeUnitRange.lowerBound > startIndex {
                    return block.codeUnitRange.lowerBound
                }

                return keepBlockLine(block, until: limitIndex)
            }

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

    /// The mirror of `findForwardBreak`'s block handling. Unlike the forward search, which only
    /// ever treats the very first thing on the whole line specially, the backward search
    /// re-checks adjacency on every step, because the boundary it is testing against moves
    /// leftward as candidates are accepted, one at a time.
    private func findBackwardBreak<S>(for extent: CGFloat, in sequence: S, from endIndex: Int, until limitIndex: Int) -> Int
        where S: Sequence,
              S.Element == StringBreak {
        var backwardIndex = endIndex
        var measurement: CGFloat = 0.0

        for stringBreak in sequence {
            let startIndex = stringBreak.codeUnitIndex
            let segmentRange = startIndex ..< backwardIndex

            if let block = findBlockBackward(in: segmentRange) {
                // A block that is not the nearest thing to the boundary already reached leaves
                // everything from it onward for this line, and nothing from it or before it; a
                // block that is the nearest thing is part of the line, together with the
                // whitespace that precedes it.
                if block.codeUnitRange.upperBound < backwardIndex {
                    return block.codeUnitRange.upperBound
                }

                return keepBlockLineBackward(block, from: limitIndex)
            }

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
            return findForwardBreak(for: extent, in: sequence, from: codeUnitRange.lowerBound, until: codeUnitRange.upperBound)
        case .line:
            let sequence = breaks.forwardLineBreaks(forCodeUnitRange: clampedRange)
            return findForwardBreak(for: extent, in: sequence, from: codeUnitRange.lowerBound, until: codeUnitRange.upperBound)
        }
    }

    func findBackwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        let paragraph = paragraphs.paragraph(forCodeUnitAt: codeUnitRange.upperBound - 1)
        let minIndex = min(codeUnitRange.lowerBound, paragraph.codeUnitRange.lowerBound)
        let clampedRange = minIndex ..< codeUnitRange.upperBound

        switch breakMode {
        case .character:
            let sequence = breaks.backwardGraphemeBreaks(forCodeUnitRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, from: codeUnitRange.upperBound, until: codeUnitRange.lowerBound)
        case .line:
            let sequence = breaks.backwardLineBreaks(forCodeUnitRange: clampedRange)
            return findBackwardBreak(for: extent, in: sequence, from: codeUnitRange.upperBound, until: codeUnitRange.lowerBound)
        }
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

    func suggestBackwardBreak(for extent: CGFloat, in codeUnitRange: Range<Int>, with breakMode: BreakMode) -> Int {
        switch breakMode {
        case .character:
            return suggestBackwardCharacterBreak(for: extent, in: codeUnitRange)
        case .line:
            return suggestBackwardLineBreak(for: extent, in: codeUnitRange)
        }
    }
}
