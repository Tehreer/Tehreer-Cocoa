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

private func makeScriptsBuffer(string: String) -> UnsafeBufferPointer<SBScript> {
    let stringBuffer = BidiBuffer(string)
    let utf16Length = stringBuffer.length

    var codepointSequence = SBCodepointSequence(
        stringEncoding: SBStringEncoding(SBStringEncodingUTF16),
        stringBuffer: UnsafeMutableRawPointer(mutating: stringBuffer.data),
        stringLength: SBUInteger(utf16Length))

    let scriptLocator = SBScriptLocatorCreate()
    defer { SBScriptLocatorRelease(scriptLocator) }

    let scriptAgent: UnsafePointer<SBScriptAgent>! = SBScriptLocatorGetAgent(scriptLocator)
    let scriptsBuffer = UnsafeMutableBufferPointer<SBScript>.allocate(capacity: utf16Length)

    SBScriptLocatorLoadCodepoints(scriptLocator, &codepointSequence)

    while SBScriptLocatorMoveNext(scriptLocator) != 0 {
        let startIndex = Int(scriptAgent.pointee.offset)
        let endIndex = startIndex + Int(scriptAgent.pointee.length)

        for index in startIndex ..< endIndex {
            scriptsBuffer[index] = scriptAgent.pointee.script
        }
    }

    return UnsafeBufferPointer(scriptsBuffer)
}

public class ScriptClassifier {
    public let string: String
    private let scriptsBuffer: UnsafeBufferPointer<SBScript>

    public init(string: String) {
        self.string = string
        self.scriptsBuffer = makeScriptsBuffer(string: string)
    }

    deinit {
        scriptsBuffer.deallocate()
    }

    public var characterScripts: CharacterScripts {
        return CharacterScripts(self)
    }

    public func scriptRuns(forCharacterRange characterRange: Range<String.Index>) -> RunSequence {
        return RunSequence(self, range: string.utf16Range(forCharacterRange: range))
    }
}

// MARK: - CharacterScripts

extension ScriptClassifier {
    public struct CharacterScripts: RandomAccessCollection {
        private let owner: ScriptClassifier

        init(_ owner: ScriptClassifier) {
            self.owner = owner
        }

        public var startIndex: Int {
            return 0
        }

        public var endIndex: Int {
            return owner.scriptsBuffer.count
        }

        public subscript(position: Int) -> Script {
            precondition(position >= 0 && position < count, String.indexOutOfRange)

            return Script(rawValue: Int(owner.scriptsBuffer[position]))!
        }
    }
}

// MARK: - RunSequence

extension ScriptClassifier {
    public struct RunSequence: Sequence {
        private let iterator: RunIterator

        init(_ owner: ScriptClassifier, range: Range<Int>) {
            self.iterator = RunIterator(owner, range: range)
        }

        public func makeIterator() -> RunIterator {
            return iterator
        }
    }

    public struct RunIterator: IteratorProtocol {
        private let owner: ScriptClassifier
        private var currentIndex: Int
        private let endIndex: Int

        init(_ owner: ScriptClassifier, range: Range<Int>) {
            self.owner = owner
            self.currentIndex = range.lowerBound
            self.endIndex = range.upperBound
        }

        public mutating func next() -> ScriptRun? {
            if currentIndex < endIndex {
                let startIndex = currentIndex
                let currentScript = owner.scriptsBuffer[startIndex]

                currentIndex += 1

                while currentIndex < endIndex {
                    if owner.scriptsBuffer[currentIndex] != currentScript {
                        break
                    }

                    currentIndex += 1
                }

                let range = owner.string.characterRange(forUTF16Range: startIndex ..< currentIndex)

                return ScriptRun(startIndex: range.lowerBound,
                                 endIndex: range.upperBound,
                                 script: Script(rawValue: Int(currentScript))!)
            }

            return nil
        }
    }
}
