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

extension String {
    func leadingWhitespaceEnd(in range: Range<String.Index>) -> String.Index {
        var index = range.lowerBound

        while index < range.upperBound {
            if !self[index].isWhitespace {
                return index
            }

            index = self.index(after: index)
        }

        return range.upperBound
    }

    func trailingWhitespaceStart(in range: Range<String.Index>) -> String.Index {
        var index = self.index(before: range.upperBound)

        while index >= range.lowerBound {
            if !self[index].isWhitespace {
                return index
            }

            index = self.index(before: index)
        }

        return range.lowerBound
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
