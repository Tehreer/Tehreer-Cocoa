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

private func makeLineBreaksBuffer(string: String) -> UnsafeBufferPointer<Int8> {
    let stringBuffer = BidiBuffer(string)
    let utf16Length = stringBuffer.length

    let breaksBuffer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: utf16Length)
    set_linebreaks_utf16(stringBuffer.data, utf16Length, nil, breaksBuffer.baseAddress)

    return UnsafeBufferPointer(breaksBuffer)
}

class BreakClassifier {
    private let string: String
    private let lineBreaks: UnsafeBufferPointer<Int8>

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

// MARK: - ForwardGraphemeBreakSequence

extension BreakClassifier {
    struct ForwardGraphemeBreakSequence: Sequence {
        private let iterator: ForwardGraphemeBreakIterator

        fileprivate init(string: String, range: Range<String.Index>) {
            self.iterator = ForwardGraphemeBreakIterator(string: string, range: range)
        }

        func makeIterator() -> ForwardGraphemeBreakIterator {
            return iterator
        }
    }

    struct ForwardGraphemeBreakIterator: IteratorProtocol {
        private var string: String
        private var currentIndex: String.Index
        private let endIndex: String.Index

        fileprivate init(string: String, range: Range<String.Index>) {
            self.string = string
            self.currentIndex = range.lowerBound
            self.endIndex = range.upperBound
        }

        mutating func next() -> String.Index? {
            if currentIndex < endIndex {
                currentIndex = string.index(after: currentIndex)
                return min(currentIndex, endIndex)
            }

            return nil
        }
    }
}

// MARK: - BackwardGraphemeBreakSequence

extension BreakClassifier {
    struct BackwardGraphemeBreakSequence: Sequence {
        private let iterator: BackwardGraphemeBreakIterator

        fileprivate init(string: String, range: Range<String.Index>) {
            self.iterator = BackwardGraphemeBreakIterator(string: string, range: range)
        }

        func makeIterator() -> BackwardGraphemeBreakIterator {
            return iterator
        }
    }

    struct BackwardGraphemeBreakIterator: IteratorProtocol {
        private var string: String
        private let startIndex: String.Index
        private var currentIndex: String.Index

        fileprivate init(string: String, range: Range<String.Index>) {
            self.string = string
            self.startIndex = range.lowerBound
            self.currentIndex = range.upperBound
        }

        mutating func next() -> String.Index? {
            if currentIndex > startIndex {
                currentIndex = string.index(before: currentIndex)
                return max(startIndex, currentIndex)
            }

            return nil
        }
    }
}

// MARK: - ForwardLineBreakSequence

extension BreakClassifier {
    struct ForwardLineBreakSequence: Sequence {
        private let iterator: ForwardLineBreakIterator

        fileprivate init(_ classifier: BreakClassifier, range: Range<Int>) {
            self.iterator = ForwardLineBreakIterator(ForwardUTF16BreakIterator(classifier, range: range))
        }

        func makeIterator() -> ForwardLineBreakIterator {
            return iterator
        }
    }

    struct ForwardLineBreakIterator: IteratorProtocol {
        private var utf16Iter: ForwardUTF16BreakIterator

        fileprivate init(_ utf16Iter: ForwardUTF16BreakIterator) {
            self.utf16Iter = utf16Iter
        }

        mutating func next() -> String.Index? {
            if let value = utf16Iter.next() {
                let string = utf16Iter.classifier.string
                let index = string.characterIndex(forUTF16Index: value)

                return index
            }

            return nil
        }
    }

    fileprivate struct ForwardUTF16BreakIterator: IteratorProtocol {
        fileprivate let classifier: BreakClassifier
        private var currentIndex: Int
        private let endIndex: Int

        init(_ classifier: BreakClassifier, range: Range<Int>) {
            self.classifier = classifier
            self.currentIndex = range.lowerBound
            self.endIndex = range.upperBound
        }

        mutating func next() -> Int? {
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
}

extension BreakClassifier {
    struct BackwardLineBreakSequence: Sequence {
        private let iterator: BackwardLineBreakIterator

        fileprivate init(_ classifier: BreakClassifier, range: Range<Int>) {
            self.iterator = BackwardLineBreakIterator(BackwardUTF16BreakIterator(classifier, range: range))
        }

        func makeIterator() -> BackwardLineBreakIterator {
            return iterator
        }
    }

    struct BackwardLineBreakIterator: IteratorProtocol {
        private var utf16Iter: BackwardUTF16BreakIterator

        fileprivate init(_ utf16Iter: BackwardUTF16BreakIterator) {
            self.utf16Iter = utf16Iter
        }

        mutating func next() -> String.Index? {
            if let value = utf16Iter.next() {
                let string = utf16Iter.classifier.string
                let index = string.characterIndex(forUTF16Index: value)

                return index
            }

            return nil
        }
    }

    fileprivate struct BackwardUTF16BreakIterator: IteratorProtocol {
        fileprivate let classifier: BreakClassifier
        private let startIndex: Int
        private var currentIndex: Int

        init(_ classifier: BreakClassifier, range: Range<Int>) {
            self.classifier = classifier
            self.startIndex = range.lowerBound
            self.currentIndex = range.upperBound
        }

        mutating func next() -> Int? {
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
}
