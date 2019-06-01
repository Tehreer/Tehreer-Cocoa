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

fileprivate func makeLineBreaksBuffer(string: String) -> UnsafeBufferPointer<Int8> {
    let stringBuffer = BidiBuffer(string)
    let utf16Length = stringBuffer.length

    let breaksBuffer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: utf16Length)
    set_linebreaks_utf16(stringBuffer.data, utf16Length, nil, breaksBuffer.baseAddress)

    return UnsafeBufferPointer(breaksBuffer)
}

class BreakClassifier {
    fileprivate let string: String
    fileprivate let lineBreaks: UnsafeBufferPointer<Int8>

    init(string: String) {
        self.string = string
        self.lineBreaks = makeLineBreaksBuffer(string: string)
    }

    deinit {
        lineBreaks.deallocate()
    }

    func forwardGraphemeBreaks(forCharacterRange range: Range<String.Index>) -> ForwardGraphemeBreakSequence {
        return ForwardGraphemeBreakSequence(string: string, range: range)
    }

    func backwardGraphemeBreaks(forCharacterRange range: Range<String.Index>) -> BackwardGraphemeBreakSequence {
        return BackwardGraphemeBreakSequence(string: string, range: range)
    }

    func forwardLineBreaks(forCharacterRange range: Range<String.Index>) -> ForwardLineBreakSequence {
        return ForwardLineBreakSequence(self, range: string.utf16Range(forCharacterRange: range))
    }

    func backwardLineBreaks(forCharacterRange range: Range<String.Index>) -> BackwardLineBreakSequence {
        return BackwardLineBreakSequence(self, range: string.utf16Range(forCharacterRange: range))
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

fileprivate struct ForwardUTF16BreakIterator: IteratorProtocol {
    typealias Element = Int

    fileprivate let classifier: BreakClassifier
    private var currentIndex: Int
    private let endIndex: Int

    init(_ classifier: BreakClassifier, range: Range<Int>) {
        self.classifier = classifier
        self.currentIndex = range.lowerBound
        self.endIndex = range.upperBound
    }

    mutating func next() -> Element? {
        if currentIndex != endIndex {
            let lineBreaks = classifier.lineBreaks

            while currentIndex < endIndex {
                defer { currentIndex += 1 }

                let breakType = lineBreaks[currentIndex]
                if breakType == LINEBREAK_MUSTBREAK || breakType == LINEBREAK_ALLOWBREAK {
                    break
                }
            }

            return currentIndex
        }

        return nil
    }
}

fileprivate struct BackwardUTF16BreakIterator: IteratorProtocol {
    typealias Element = Int

    fileprivate let classifier: BreakClassifier
    private let startIndex: Int
    private var currentIndex: Int

    init(_ classifier: BreakClassifier, range: Range<Int>) {
        self.classifier = classifier
        self.startIndex = range.lowerBound
        self.currentIndex = range.upperBound
    }

    mutating func next() -> Element? {
        if currentIndex != startIndex {
            let lineBreaks = classifier.lineBreaks

            currentIndex -= 1

            while currentIndex > startIndex {
                let breakType = lineBreaks[currentIndex - 1]
                if breakType == LINEBREAK_MUSTBREAK || breakType == LINEBREAK_ALLOWBREAK {
                    break
                }

                currentIndex -= 1
            }

            return currentIndex
        }

        return nil
    }
}

struct ForwardLineBreakIterator: IteratorProtocol {
    typealias Element = String.Index

    private var utf16Iter: ForwardUTF16BreakIterator

    fileprivate init(_ utf16Iter: ForwardUTF16BreakIterator) {
        self.utf16Iter = utf16Iter
    }

    mutating func next() -> Element? {
        if let value = utf16Iter.next() {
            let string = utf16Iter.classifier.string
            let index = string.characterIndex(forUTF16Index: value)

            return index
        }

        return nil
    }
}

struct ForwardLineBreakSequence: Sequence {
    typealias Element = String.Index
    typealias Iterator = ForwardLineBreakIterator

    private let iterator: Iterator

    fileprivate init(_ classifier: BreakClassifier, range: Range<Int>) {
        self.iterator = ForwardLineBreakIterator(ForwardUTF16BreakIterator(classifier, range: range))
    }

    func makeIterator() -> Iterator {
        return iterator
    }
}

struct BackwardLineBreakIterator: IteratorProtocol {
    typealias Element = String.Index

    private var utf16Iter: BackwardUTF16BreakIterator

    fileprivate init(_ utf16Iter: BackwardUTF16BreakIterator) {
        self.utf16Iter = utf16Iter
    }

    mutating func next() -> Element? {
        if let value = utf16Iter.next() {
            let string = utf16Iter.classifier.string
            let index = string.characterIndex(forUTF16Index: value)

            return index
        }

        return nil
    }
}

struct BackwardLineBreakSequence: Sequence {
    typealias Element = String.Index
    typealias Iterator = BackwardLineBreakIterator

    private let iterator: Iterator

    fileprivate init(_ classifier: BreakClassifier, range: Range<Int>) {
        self.iterator = BackwardLineBreakIterator(BackwardUTF16BreakIterator(classifier, range: range))
    }

    func makeIterator() -> Iterator {
        return iterator
    }
}
