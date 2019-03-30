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

protocol CodeUnitView
    where Self: BidirectionalCollection,
          Self.Index == String.Index {
}

extension String.UTF8View: CodeUnitView { }
extension String.UTF16View: CodeUnitView { }
extension String.UnicodeScalarView: CodeUnitView { }

extension BidirectionalCollection where Self: CodeUnitView {
    @inlinable
    func codeUnitIndex(forCharacterAt index: String.Index) -> Int {
        return distance(from: startIndex, to: index)
    }

    @inlinable
    func codeUnitRange(forCharacterRange range: Range<String.Index>) -> NSRange {
        let location = distance(from: startIndex, to: range.lowerBound)
        let length = distance(from: range.lowerBound, to: range.upperBound)

        return NSRange(location: location, length: length)
    }

    @inlinable
    func codeUnitRange(forCharacterRange range: Range<String.Index>) -> Range<Int> {
        let turnedRange: NSRange = codeUnitRange(forCharacterRange: range)

        return turnedRange.lowerBound ..< turnedRange.upperBound
    }

    @inlinable
    func characterIndex(forCodeUnitAt index: Int) -> String.Index {
        return self.index(startIndex, offsetBy: index)
    }

    @inlinable
    func characterRange(forCodeUnitRange range: Range<Int>) -> Range<String.Index> {
        let lowerBound = index(startIndex, offsetBy: range.lowerBound)
        let upperBound = index(lowerBound, offsetBy: range.count)

        return lowerBound ..< upperBound
    }

    @inlinable
    func characterRange(forCodeUnitRange range: NSRange) -> Range<String.Index> {
        return characterRange(forCodeUnitRange: range.lowerBound ..< range.upperBound)
    }
}
