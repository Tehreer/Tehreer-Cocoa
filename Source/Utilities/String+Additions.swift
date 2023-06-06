//
// Copyright (C) 2019-2023 Muhammad Tayyab Akram
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

extension String {
    static let indexOutOfRange = "Index is out of range"

    func leadingWhitespaceEnd(in codeUnitRange: Range<Int>) -> Int {
        let index = leadingWhitespaceEnd(in: characterRange(forUTF16Range: codeUnitRange))

        return utf16Index(forCharacterAt: index)
    }

    func leadingWhitespaceEnd(in range: Range<String.Index>) -> String.Index {
        var index = range.lowerBound

        while index < range.upperBound {
            if !self[index].isSingleWhitespace {
                return index
            }

            index = self.index(after: index)
        }

        return range.upperBound
    }

    func trailingWhitespaceStart(in codeUnitRange: Range<Int>) -> Int {
        let index = trailingWhitespaceStart(in: characterRange(forUTF16Range: codeUnitRange))

        return utf16Index(forCharacterAt: index)
    }

    func trailingWhitespaceStart(in range: Range<String.Index>) -> String.Index {
        var index = range.upperBound

        while index > range.lowerBound {
            let next = index
            index = self.index(before: next)

            if !self[index].isSingleWhitespace {
                return next
            }
        }

        return range.lowerBound
    }

    func nextSpace(in codeUnitRange: Range<Int>) -> Int {
        let index = nextSpace(in: characterRange(forUTF16Range: codeUnitRange))
        return utf16Index(forCharacterAt: index)
    }

    func nextSpace(in range: Range<String.Index>) -> String.Index {
        var index = range.lowerBound

        while index < range.upperBound {
            if self[index].isSingleWhitespace {
                return index
            }

            index = self.index(after: index)
        }

        return range.upperBound
    }

    @inlinable
    func utf16Index(forCharacterAt index: String.Index) -> Int {
        return utf16.codeUnitIndex(forCharacterAt: index)
    }

    @inlinable
    func utf16Range(forCharacterRange range: Range<String.Index>) -> NSRange {
        return utf16.codeUnitRange(forCharacterRange: range)
    }

    @inlinable
    func utf16Range(forCharacterRange range: Range<String.Index>) -> Range<Int> {
        return utf16.codeUnitRange(forCharacterRange: range)
    }

    @inlinable
    func characterIndex(forUTF16Index index: Int) -> String.Index {
        return utf16.characterIndex(forCodeUnitAt: index)
    }

    @inlinable
    func characterRange(forUTF16Range range: NSRange) -> Range<String.Index> {
        return utf16.characterRange(forCodeUnitRange: range)
    }

    @inlinable
    func characterRange(forUTF16Range range: Range<Int>) -> Range<String.Index> {
        return utf16.characterRange(forCodeUnitRange: range)
    }
}
