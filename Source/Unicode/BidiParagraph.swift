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

import Foundation
import SheenBidi

/// A `BidiParagraph` object represents a single paragraph of text processed with rules X1-I2 of
/// Unicode Bidirectional Algorithm. It contains the resolved embedding levels of all the characters
/// of a paragraph and provides the facility to query them or iterate over their runs.
public class BidiParagraph {
    let buffer: BidiBuffer
    let paragraph: SBParagraphRef

    init(buffer: BidiBuffer, paragraph: SBParagraphRef) {
        self.buffer = buffer
        self.paragraph = paragraph
    }

    deinit {
        SBParagraphRelease(paragraph)
    }

    public var codeUnitRange: Range<Int> {
        let offset = Int(SBParagraphGetOffset(paragraph))
        let length = Int(SBParagraphGetLength(paragraph))

        return Range(uncheckedBounds: (offset, offset + length))
    }

    var stringRange: Range<String.Index> {
        return buffer.string.characterRange(forUTF16Range: codeUnitRange)
    }

    /// The index to the first character of this paragraph in source string.
    public var startIndex: String.Index {
        let offset = Int(SBParagraphGetOffset(paragraph))

        return buffer.string.characterIndex(forUTF16Index: offset)
    }

    /// The index after the last character of this paragraph in source string.
    public var endIndex: String.Index {
        let offset = Int(SBParagraphGetOffset(paragraph))
        let length = Int(SBParagraphGetLength(paragraph))

        return buffer.string.characterIndex(forUTF16Index: offset + length)
    }

    /// The base level of this paragraph.
    public var baseLevel: UInt8 {
        return UInt8(SBParagraphGetBaseLevel(paragraph))
    }

    /// The collection containing the levels of all characters in this paragraph.
    public var embeddingLevels: EmbeddingLevels {
        return EmbeddingLevels(self)
    }

    /// The sequence of logically ordered runs in this paragraph.
    public var logicalRuns: RunSequence {
        return RunSequence(self)
    }

    public func makeLine(codeUnitRange: Range<Int>) -> BidiLine? {
        let clampedRange = codeUnitRange.clamped(to: self.codeUnitRange)
        if clampedRange.isEmpty {
            return nil
        }

        let lineOffset = SBUInteger(clampedRange.lowerBound)
        let lineLength = SBUInteger(clampedRange.count)
        let bidiLine = SBParagraphCreateLine(paragraph, lineOffset, lineLength)

        return BidiLine(buffer: buffer, line: bidiLine!)
    }

    /// Creates a line object of specified range by applying Rules L1-L2 of Unicode Bidirectional
    /// Algorithm.
    ///
    /// - Parameter characterRange: The range of the line in source string.
    /// - Returns: A line object processed with Rules L1-L2 of Unicode Bidirectional Algorithm.
    public func makeLine(characterRange: Range<String.Index>) -> BidiLine? {
        let codeUnitRange: Range<Int> = buffer.string.utf16Range(forCharacterRange: characterRange)

        return makeLine(codeUnitRange: codeUnitRange)
    }
}

// MARK: - EmbeddingLevels

extension BidiParagraph {
    /// A collection of the embedding levels of a paragraph, represented by UTF-16 code unit indices.
    public struct EmbeddingLevels: RandomAccessCollection {
        private let owner: BidiParagraph
        private let pointer: UnsafePointer<SBLevel>!

        init(_ owner: BidiParagraph) {
            self.owner = owner
            self.pointer = SBParagraphGetLevelsPtr(owner.paragraph)
            self.count = Int(SBParagraphGetLength(owner.paragraph))
        }

        /// The number of elements in the collection.
        public let count: Int

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return count
        }

        public subscript(index: String.Index) -> UInt8 {
            let paragraphRange = owner.codeUnitRange
            let codeUnitIndex = owner.buffer.string.utf16Index(forCharacterAt: index)
            precondition(paragraphRange.contains(codeUnitIndex), String.indexOutOfRange)

            return pointer[codeUnitIndex - paragraphRange.lowerBound]
        }

        /// Accesses the embedding level at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> UInt8 {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            return pointer[index]
        }
    }
}

// MARK: - RunSequence

extension BidiParagraph {
    /// A sequence of bidirectional runs in a paragraph.
    public struct RunSequence: Sequence {
        private let owner: BidiParagraph

        init(_ owner: BidiParagraph) {
            self.owner = owner
        }

        /// Returns an iterator over the elements of this sequence.
        public func makeIterator() -> RunIterator {
            return RunIterator(owner)
        }
    }

    /// An iterator over the bidirectional runs.
    public struct RunIterator: IteratorProtocol {
        private let owner: BidiParagraph
        private var levelIndex: Int

        init(_ owner: BidiParagraph) {
            self.owner = owner
            self.levelIndex = 0
        }

        /// Advances to the next bidirectional run and returns it, or `nil` if no next run exists.
        public mutating func next() -> BidiRun? {
            let bidiParagraph = owner.paragraph
            let paragraphOffset = SBParagraphGetOffset(bidiParagraph)
            let paragraphLength = SBParagraphGetLength(bidiParagraph)

            if levelIndex < paragraphLength {
                let levelsPtr = SBParagraphGetLevelsPtr(bidiParagraph)!
                let currentLevel = levelsPtr[levelIndex]
                var nextIndex = levelIndex + 1

                while nextIndex < paragraphLength {
                    if levelsPtr[nextIndex] != currentLevel {
                        break
                    }

                    nextIndex += 1
                }

                let runOffset = Int(paragraphOffset) + levelIndex
                let runLength = nextIndex - levelIndex
                let runRange = Range(uncheckedBounds: (runOffset, runOffset + runLength))

                levelIndex = nextIndex

                return BidiRun(string: owner.buffer.string,
                               codeUnitRange: runRange,
                               embeddingLevel: currentLevel)
            }

            return nil
        }
    }
}
