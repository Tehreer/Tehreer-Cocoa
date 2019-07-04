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

    var stringRange: Range<String.Index> {
        let lineOffset = SBLineGetOffset(line)
        let lineLength = SBLineGetLength(line)
        let utf16Range = NSRange(location: Int(lineOffset), length: Int(lineLength))

        return buffer.string.characterRange(forUTF16Range: utf16Range)
    }

    public var startIndex: String.Index {
        return stringRange.lowerBound
    }

    public var endIndex: String.Index {
        return stringRange.upperBound
    }

    /// The collection of visually ordered runs in this line.
    public var visualRuns: PrimitiveCollection<BidiRun> {
        return PrimitiveCollection(RunCollection(self))
    }

    /// The sequence of mirroring pairs in this line. You can use the iterable to  implement Rule L4
    /// of Unicode Bidirectional Algorithm.
    public var mirroringPairs: BidiPairSequence {
        return BidiPairSequence(self)
    }
}

fileprivate class RunCollection: IntrinsicCollection<BidiRun> {
    private let container: BidiLine
    private let length: Int

    init(_ container: BidiLine) {
        self.container = container

        let runCount = SBLineGetRunCount(container.line)
        length = Int(runCount)
    }

    override var count: Int {
        return length
    }

    override func item(at index: Int) -> BidiRun {
        let runPtr = SBLineGetRunsPtr(container.line)[index]
        let string = container.buffer.string
        let utf16Range = NSRange(location: Int(runPtr.offset), length: Int(runPtr.length))
        let runRange = string.characterRange(forUTF16Range: utf16Range)

        return BidiRun(startIndex: runRange.lowerBound,
                       endIndex: runRange.upperBound,
                       embeddingLevel: UInt8(runPtr.level))
    }
}

public class BidiPairIterator: IteratorProtocol {
    public typealias Element = BidiPair

    private let container: BidiLine
    private let locator: SBMirrorLocatorRef
    private let agent: UnsafePointer<SBMirrorAgent>

    init(_ container: BidiLine) {
        self.container = container
        self.locator = SBMirrorLocatorCreate()
        self.agent = SBMirrorLocatorGetAgent(locator)

        let stringBuffer = UnsafeMutableRawPointer(mutating: container.buffer.data)
        SBMirrorLocatorLoadLine(locator, container.line, stringBuffer)
    }

    deinit {
        SBMirrorLocatorRelease(locator)
    }

    public func next() -> BidiPair? {
        if SBMirrorLocatorMoveNext(locator) != 0 {
            let bidiBuffer = container.buffer
            let stringBuffer = UnsafeMutableRawPointer(mutating: bidiBuffer.data)
            let stringLength = SBUInteger(bidiBuffer.length)

            var codepointSequence = SBCodepointSequence(
                stringEncoding: SBStringEncoding(SBStringEncodingUTF16),
                stringBuffer: stringBuffer,
                stringLength: stringLength)

            var index = agent.pointee.index
            let source = SBCodepointSequenceGetCodepointAt(&codepointSequence, &index)
            let mirror = agent.pointee.mirror

            let string = bidiBuffer.string
            let utf16Index = Int(agent.pointee.index)

            return BidiPair(codeUnitIndex: string.characterIndex(forUTF16Index: utf16Index),
                            actualCodePoint: UnicodeScalar(source)!,
                            pairingCodePoint: UnicodeScalar(mirror)!)
        }

        return nil
    }
}

public struct BidiPairSequence: Sequence {
    public typealias Element = BidiPair
    public typealias Iterator = BidiPairIterator

    let container: BidiLine

    init(_ container: BidiLine) {
        self.container = container
    }

    public func makeIterator() -> Iterator {
        return BidiPairIterator(container)
    }
}
