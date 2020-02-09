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

/// This class implements UAX #24 available at
/// [http://www.unicode.org/reports/tr24](http://www.unicode.org/reports/tr24).
public class ScriptClassifier {
    private let scriptsBuffer: UnsafeBufferPointer<SBScript>

    /// Creates a script classifier for the specified string.
    ///
    /// - Parameter string: The string whose script classification is desired.
    public init(string: String) {
        self.string = string
        self.scriptsBuffer = makeScriptsBuffer(string: string)
    }

    deinit {
        scriptsBuffer.deallocate()
    }

    /// The string that the script classifier was created for.
    public let string: String

    /// The resolved scripts of all characters in source string.
    public var characterScripts: CharacterScripts {
        return CharacterScripts(self)
    }

    /// Returns a sequence of resolved script runs within the specified UTF-16 range of source string.
    ///
    /// - Parameter codeUnitRange: The UTF-16 range in source string.
    /// - Returns: A sequence of script runs within the specified UTF-16 range of source string.
    public func scriptRuns(forCodeUnitRange codeUnitRange: Range<Int>) -> RunSequence {
        return RunSequence(self, range: codeUnitRange)
    }

    /// Returns a sequence of resolved script runs within the specified character range of source string.
    ///
    /// - Parameter characterRange: The character range in source string.
    /// - Returns: A sequence of script runs within the specified character range of source string.
    public func scriptRuns(forCharacterRange characterRange: Range<String.Index>) -> RunSequence {
        return scriptRuns(forCodeUnitRange: string.utf16Range(forCharacterRange: characterRange))
    }
}

// MARK: - CharacterScripts

extension ScriptClassifier {
    /// A collection of the scripts of a string, represented by UTF-16 code unit indices.
    public struct CharacterScripts: RandomAccessCollection {
        private let owner: ScriptClassifier

        init(_ owner: ScriptClassifier) {
            self.owner = owner
        }

        /// The index to the first element.
        public var startIndex: Int {
            return 0
        }

        /// The index after the last element.
        public var endIndex: Int {
            return owner.scriptsBuffer.count
        }

        /// Accesses the embedding level at the specified character index.
        ///
        /// - Parameter index: A valid character index of the source string.
        public subscript(index: String.Index) -> Script {
            let string = owner.string
            precondition(index >= string.startIndex && index < string.endIndex, .indexOutOfRange)

            let codeUnitIndex = string.utf16Index(forCharacterAt: index)
            let script = owner.scriptsBuffer[codeUnitIndex]

            return Script(rawValue: Int(script))!
        }

        /// Accesses the script at the specified position.
        ///
        /// - Parameter index: The position of the element to access. `index` must be greater than or equal to
        ///                    `startIndex` and less than `endIndex`.
        public subscript(index: Int) -> Script {
            precondition(index >= 0 && index < count, .indexOutOfRange)

            return Script(rawValue: Int(owner.scriptsBuffer[index]))!
        }
    }
}

// MARK: - RunSequence

extension ScriptClassifier {
    /// A sequence of script runs in a script classifier.
    public struct RunSequence: Sequence {
        private let iterator: RunIterator

        init(_ owner: ScriptClassifier, range: Range<Int>) {
            self.iterator = RunIterator(owner, range: range)
        }

        /// Returns an iterator over the elements of this sequence.
        public func makeIterator() -> RunIterator {
            return iterator
        }
    }

    /// An iterator over the script runs.
    public struct RunIterator: IteratorProtocol {
        private let owner: ScriptClassifier
        private var currentIndex: Int
        private let endIndex: Int

        init(_ owner: ScriptClassifier, range: Range<Int>) {
            self.owner = owner
            self.currentIndex = range.lowerBound
            self.endIndex = range.upperBound
        }

        /// Advances to the next script run and returns it, or `nil` if no next run exists.
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

                return ScriptRun(string: owner.string,
                                 codeUnitRange: Range(uncheckedBounds: (startIndex, currentIndex)),
                                 script: Script(rawValue: Int(currentScript))!)
            }

            return nil
        }
    }
}
