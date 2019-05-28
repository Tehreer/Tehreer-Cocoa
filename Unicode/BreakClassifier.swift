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

class BreakClassifier {
    private let string: String

    init(string: String) {
        self.string = string
    }

    func forwardGraphemeBreaks(forCharacterRange range: Range<String.Index>) -> ForwardGraphemeBreakSequence {
        return ForwardGraphemeBreakSequence(string: string, range: range)
    }

    func backwardGraphemeBreaks(forCharacterRange range: Range<String.Index>) -> BackwardGraphemeBreakSequence {
        return BackwardGraphemeBreakSequence(string: string, range: range)
    }
}

struct ForwardGraphemeBreakIterator: IteratorProtocol {
    typealias Element = String.Index

    private var string: String
    private var currentIndex: String.Index
    private let endIndex: String.Index

    fileprivate init(string: String, range: Range<String.Index>) {
        self.string = string
        self.currentIndex = range.lowerBound
        self.endIndex = range.upperBound
    }

    mutating func next() -> Element? {
        if currentIndex < endIndex {
            currentIndex = string.index(after: currentIndex)
            return min(currentIndex, endIndex)
        }

        return nil
    }
}

struct ForwardGraphemeBreakSequence: Sequence {
    typealias Element = String.Index
    typealias Iterator = ForwardGraphemeBreakIterator

    private let iterator: Iterator

    fileprivate init(string: String, range: Range<String.Index>) {
        self.iterator = ForwardGraphemeBreakIterator(string: string, range: range)
    }

    func makeIterator() -> Iterator {
        return iterator
    }
}

struct BackwardGraphemeBreakIterator: IteratorProtocol {
    typealias Element = String.Index

    private var string: String
    private let startIndex: String.Index
    private var currentIndex: String.Index

    fileprivate init(string: String, range: Range<String.Index>) {
        self.string = string
        self.startIndex = range.lowerBound
        self.currentIndex = range.upperBound
    }

    mutating func next() -> Element? {
        if currentIndex > startIndex {
            currentIndex = string.index(before: currentIndex)
            return max(startIndex, currentIndex)
        }

        return nil
    }
}

struct BackwardGraphemeBreakSequence: Sequence {
    typealias Element = String.Index
    typealias Iterator = BackwardGraphemeBreakIterator

    private let iterator: Iterator

    fileprivate init(string: String, range: Range<String.Index>) {
        self.iterator = BackwardGraphemeBreakIterator(string: string, range: range)
    }

    func makeIterator() -> Iterator {
        return iterator
    }
}
