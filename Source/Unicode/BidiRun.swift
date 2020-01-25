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

/// A bidi run represents a sequence of characters which have the same embedding level. The
/// direction of run is considered right-to-left, if its embedding level is odd.
public struct BidiRun {
    private var string: String

    /// The UTF-16 range of the run in source string.
    public var codeUnitRange: Range<Int>

    /// The embedding level of the run.
    public var embeddingLevel: UInt8

    init(string: String, codeUnitRange: Range<Int>, embeddingLevel: UInt8) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.embeddingLevel = embeddingLevel
    }
}

extension BidiRun {
    /// The index to the first character of this run in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this run in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    /// A Boolean value that indicates whether the run is right-to-left.
    public var isRightToLeft: Bool {
        return (embeddingLevel & 1) == 1
    }
}

/// Represents a pair of a unicode code point at a specific index in source string.
public struct BidiPair {
    private var string: String

    /// The index of actual UTF-16 code unit.
    public var codeUnitIndex: Int

    /// The code point of actual character in source string.
    public var actualCodePoint: UnicodeScalar

    /// The code point of character forming a pair with actual character.
    public var pairingCodePoint: UnicodeScalar

    init(string: String, codeUnitIndex: Int,
         actualCodePoint: UnicodeScalar, pairingCodePoint: UnicodeScalar) {
        self.string = string
        self.codeUnitIndex = codeUnitIndex
        self.actualCodePoint = actualCodePoint
        self.pairingCodePoint = pairingCodePoint
    }
}

extension BidiPair {
    /// The index of actual character in source string.
    public var characterIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitIndex)
    }
}
