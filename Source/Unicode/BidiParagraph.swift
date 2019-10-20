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

    var stringRange: Range<String.Index> {
        let paragraphOffset = SBParagraphGetOffset(paragraph)
        let paragraphLength = SBParagraphGetLength(paragraph)
        let utf16Range = NSRange(location: Int(paragraphOffset), length: Int(paragraphLength))

        return buffer.string.characterRange(forUTF16Range: utf16Range)
    }

    public var startIndex: String.Index {
        return stringRange.lowerBound
    }

    public var endIndex: String.Index {
        return stringRange.upperBound
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

    /// Creates a line object of specified range by applying Rules L1-L2 of Unicode Bidirectional
    /// Algorithm.
    ///
    /// - Parameter range: The range of the line in source text.
    /// - Returns: A line object processed with Rules L1-L2 of Unicode Bidirectional Algorithm.
    public func makeLine(range: Range<String.Index>) -> BidiLine? {
        let clampedRange = range.clamped(to: stringRange)
        if clampedRange.isEmpty {
            return nil
        }

        let utf16Range: NSRange = buffer.string.utf16Range(forCharacterRange: clampedRange)
        let lineOffset = SBUInteger(utf16Range.location)
        let lineLength = SBUInteger(utf16Range.length)
        let bidiLine = SBParagraphCreateLine(paragraph, lineOffset, lineLength)

        return BidiLine(buffer: buffer, line: bidiLine!)
    }
}

extension BidiParagraph {
    public struct EmbeddingLevels: RandomAccessCollection {
        private let owner: BidiParagraph
        private let pointer: UnsafePointer<SBLevel>!
        public let count: Int

        init(_ owner: BidiParagraph) {
            self.owner = owner
            self.pointer = SBParagraphGetLevelsPtr(owner.paragraph)
            self.count = Int(SBParagraphGetLength(owner.paragraph))
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return count
        }

        public subscript(position: Int) -> UInt8 {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            return pointer[position]
        }
    }
}

extension BidiParagraph {
    public struct RunSequence: Sequence {
        public typealias Element = BidiRun
        public typealias Iterator = RunIterator

        private let owner: BidiParagraph

        init(_ owner: BidiParagraph) {
            self.owner = owner
        }

        public func makeIterator() -> RunIterator {
            return RunIterator(owner)
        }
    }

    public struct RunIterator: IteratorProtocol {
        public typealias Element = BidiRun

        private let owner: BidiParagraph
        private var levelIndex: Int

        init(_ owner: BidiParagraph) {
            self.owner = owner
            self.levelIndex = 0
        }

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

                levelIndex = nextIndex

                let string = owner.buffer.string
                let utf16Range = NSRange(location: runOffset, length: runLength)
                let runRange = string.characterRange(forUTF16Range: utf16Range)

                return BidiRun(startIndex: runRange.lowerBound,
                               endIndex: runRange.upperBound,
                               embeddingLevel: currentLevel)
            }

            return nil
        }
    }
}
