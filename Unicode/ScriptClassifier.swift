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
    fileprivate let scripts: [Script]

    public init(string: String) {
        self.string = string
        self.scripts = makeScriptArray(string: string)
    }

    public func script(forCharacterAt index: String.Index) -> Script {
        return scripts[string.utf16Index(forCharacterAt: index)]
    }

    public func scriptRuns(forCharacterRange range: Range<String.Index>) -> ScriptRunSequence {
        return ScriptRunSequence(self, range: string.utf16Range(forCharacterRange: range))
    }
}

public struct ScriptRunIterator: IteratorProtocol {
    public typealias Element = ScriptRun

    let container: ScriptClassifier
    var currentIndex: Int
    let endIndex: Int

    init(_ container: ScriptClassifier, range: Range<Int>) {
        self.container = container
        self.currentIndex = range.lowerBound
        self.endIndex = range.upperBound
    }

    public mutating func next() -> ScriptRun? {
        if currentIndex < endIndex {
            let startIndex = currentIndex
            let currentScript = container.scripts[startIndex]

            currentIndex += 1

            while currentIndex < endIndex {
                if container.scripts[currentIndex] != currentScript {
                    break
                }

                currentIndex += 1
            }

            let range = container.string.characterRange(forUTF16Range: startIndex ..< endIndex)

            return ScriptRun(startIndex: range.lowerBound,
                             endIndex: range.upperBound,
                             script: currentScript)
        }

        return nil
    }
}

public struct ScriptRunSequence: Sequence {
    public typealias Element = ScriptRun
    public typealias Iterator = ScriptRunIterator

    let container: ScriptClassifier
    let range: Range<Int>

    init(_ container: ScriptClassifier, range: Range<Int>) {
        self.container = container
        self.range = range
    }

    public func makeIterator() -> ScriptRunIterator {
        return ScriptRunIterator(container, range: range)
    }
}
