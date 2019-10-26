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

func makeScriptArray(string: String) -> [Script] {
    let buffer = BidiBuffer(string)

    var codepointSequence = SBCodepointSequence(
        stringEncoding: SBStringEncoding(SBStringEncodingUTF16),
        stringBuffer: UnsafeMutableRawPointer(mutating: buffer.data),
        stringLength: SBUInteger(buffer.length))

    let scriptLocator = SBScriptLocatorCreate()
    let scriptAgent = SBScriptLocatorGetAgent(scriptLocator)
    var scriptArray: [Script] = []

    SBScriptLocatorLoadCodepoints(scriptLocator, &codepointSequence)

    while SBScriptLocatorMoveNext(scriptLocator) != 0 {
        let startIndex = scriptAgent!.pointee.offset
        let endIndex = startIndex + scriptAgent!.pointee.length

        let script = Script(rawValue: Int(scriptAgent!.pointee.script))!

        for _ in startIndex ..< endIndex {
            scriptArray.append(script)
        }
    }

    SBScriptLocatorRelease(scriptLocator)

    return scriptArray
}

public class ScriptClassifier {
    public let string: String
    private let scripts: [Script]

    public init(string: String) {
        self.string = string
        self.scripts = makeScriptArray(string: string)
    }

    public func script(forCharacterAt index: String.Index) -> Script {
        return scripts[string.utf16Index(forCharacterAt: index)]
    }

    public func scriptRuns(forCharacterRange range: Range<String.Index>) -> RunSequence {
        return RunSequence(self, range: string.utf16Range(forCharacterRange: range))
    }
}

extension ScriptClassifier {
    public struct RunSequence: Sequence {
        public typealias Element = ScriptRun
        public typealias Iterator = RunIterator

        private let owner: ScriptClassifier
        private let range: Range<Int>

        init(_ owner: ScriptClassifier, range: Range<Int>) {
            self.owner = owner
            self.range = range
        }

        public func makeIterator() -> RunIterator {
            return RunIterator(owner, range: range)
        }
    }

    public struct RunIterator: IteratorProtocol {
        public typealias Element = ScriptRun

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
                let currentScript = owner.scripts[startIndex]

                currentIndex += 1

                while currentIndex < endIndex {
                    if owner.scripts[currentIndex] != currentScript {
                        break
                    }

                    currentIndex += 1
                }

                let range = owner.string.characterRange(forUTF16Range: startIndex ..< currentIndex)

                return ScriptRun(startIndex: range.lowerBound,
                                 endIndex: range.upperBound,
                                 script: currentScript)
            }

            return nil
        }
    }
}
