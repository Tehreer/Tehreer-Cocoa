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

/// A `BidiLine` object represents a single line processed with rules L1-L2 of Unicode Bidirectional
/// Algorithm. Instead of reordering the characters as stated by rule L2, it allows to query and
/// iterate over reordered level runs. The caller is responsible to reorder the characters manually,
/// if required.
public class BidiLine {
    let buffer: BidiBuffer
    let line: SBLineRef

    init(buffer: BidiBuffer, line: SBLineRef) {
        self.buffer = buffer
        self.line = line
    }

    deinit {
        SBLineRelease(line)
    }

    public var codeUnitRange: Range<Int> {
        let offset = Int(SBLineGetOffset(line))
        let length = Int(SBLineGetLength(line))

        return Range(uncheckedBounds: (offset, offset + length))
    }

    /// The index to the first character of this line in source string.
    public var startIndex: String.Index {
        let offset = Int(SBLineGetOffset(line))

        return buffer.string.characterIndex(forUTF16Index: offset)
    }

    /// The index after the last character of this line in source string.
    public var endIndex: String.Index {
        let offset = Int(SBLineGetOffset(line))
        let length = Int(SBLineGetLength(line))

        return buffer.string.characterIndex(forUTF16Index: offset + length)
    }

    /// The collection of visually ordered runs in this line.
    public var visualRuns: VisualRuns {
        return VisualRuns(self)
    }

    /// The sequence of mirroring pairs in this line. You can use it to implement Rule L4 of Unicode
    /// Bidirectional Algorithm.
    public var mirroringPairs: MirrorSequence {
        return MirrorSequence(self)
    }
}

// MARK: - VisualRuns

extension BidiLine {
    /// A collection of visually ordered runs in a line.
    public struct VisualRuns: RandomAccessCollection {
        private let owner: BidiLine
        private let pointer: UnsafePointer<SBRun>!

        init(_ owner: BidiLine) {
            self.owner = owner
            self.pointer = SBLineGetRunsPtr(owner.line)
            self.count = Int(SBLineGetRunCount(owner.line))
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

        /// Accesses the bidirectional run at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> BidiRun {
            precondition(index >= 0 && index < count, String.indexOutOfRange)

            let runPtr = pointer[index]
            let runOffset = Int(runPtr.offset)
            let runLength = Int(runPtr.length)
            let runRange = Range(uncheckedBounds: (runOffset, runOffset + runLength))

            return BidiRun(string: owner.buffer.string,
                           codeUnitRange: runRange,
                           embeddingLevel: UInt8(runPtr.level))
        }
    }
}

// MARK: - MirrorSequence

extension BidiLine {
    /// A sequence of mirrored characters in a line.
    public struct MirrorSequence: Sequence {
        private let owner: BidiLine

        init(_ owner: BidiLine) {
            self.owner = owner
        }

        /// Returns an iterator over the elements of this sequence.
        public func makeIterator() -> MirrorIterator {
            return MirrorIterator(owner)
        }
    }

    /// An iterator over the mirrored characters.
    public class MirrorIterator: IteratorProtocol {
        private let owner: BidiLine
        private let locator: SBMirrorLocatorRef
        private let agent: UnsafePointer<SBMirrorAgent>

        init(_ owner: BidiLine) {
            self.owner = owner
            self.locator = SBMirrorLocatorCreate()
            self.agent = SBMirrorLocatorGetAgent(locator)

            let stringBuffer = UnsafeMutableRawPointer(mutating: owner.buffer.data)
            SBMirrorLocatorLoadLine(locator, owner.line, stringBuffer)
        }

        deinit {
            SBMirrorLocatorRelease(locator)
        }

        /// Advances to the next element and returns it, or `nil` if no next element exists.
        public func next() -> BidiPair? {
            if SBMirrorLocatorMoveNext(locator) != 0 {
                let bidiBuffer = owner.buffer

                var codepointSequence = SBCodepointSequence(
                    stringEncoding: SBStringEncoding(SBStringEncodingUTF16),
                    stringBuffer: UnsafeMutableRawPointer(mutating: bidiBuffer.data),
                    stringLength: SBUInteger(bidiBuffer.length))

                var index = agent.pointee.index
                let source = SBCodepointSequenceGetCodepointAt(&codepointSequence, &index)
                let mirror = agent.pointee.mirror

                return BidiPair(string: bidiBuffer.string,
                                codeUnitIndex: Int(agent.pointee.index),
                                actualCodePoint: UnicodeScalar(source)!,
                                pairingCodePoint: UnicodeScalar(mirror)!)
            }

            return nil
        }
    }
}
