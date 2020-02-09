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

/// A script run represents a sequence of characters which have the same script.
public struct ScriptRun {
    private let string: String

    /// The UTF-16 range of the run in source string.
    public let codeUnitRange: Range<Int>

    /// The resolved script of the run.
    public let script: Script

    init(string: String, codeUnitRange: Range<Int>, script: Script) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.script = script
    }
}

extension ScriptRun {
    /// The index to the first character of the run in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of the run in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }
}
