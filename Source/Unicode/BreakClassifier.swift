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
import UniBreak

private func makeLineBreaksBuffer(string: String) -> UnsafeBufferPointer<Int8> {
    let stringBuffer = BidiBuffer(string)
    let utf16Length = stringBuffer.length

    let breaksBuffer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: utf16Length)
    set_linebreaks_utf16(stringBuffer.data, utf16Length, nil, breaksBuffer.baseAddress)

    return UnsafeBufferPointer(breaksBuffer)
}

protocol StringBreak {
    var codeUnitIndex: Int { get }
    var characterIndex: String.Index { get }
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

    func forwardGraphemeBreaks(forCodeUnitRange range: Range<Int>) -> ForwardGraphemeBreakSequence {
        let characterRange = string.characterRange(forUTF16Range: range)
        return ForwardGraphemeBreakSequence(string: string, characterRange: characterRange)
    }

    func backwardGraphemeBreaks(forCodeUnitRange range: Range<Int>) -> BackwardGraphemeBreakSequence {
        let characterRange = string.characterRange(forUTF16Range: range)
        return BackwardGraphemeBreakSequence(string: string, characterRange: characterRange)
    }

    func forwardLineBreaks(forCodeUnitRange range: Range<Int>) -> ForwardLineBreakSequence {
        return ForwardLineBreakSequence(self, codeUnitRange: range)
    }

    func backwardLineBreaks(forCodeUnitRange range: Range<Int>) -> BackwardLineBreakSequence {
        return BackwardLineBreakSequence(self, codeUnitRange: range)
    }
}

// MARK: - ForwardGraphemeBreakSequence

extension BreakClassifier {
    struct GraphemeBreak: StringBreak {
        private let string: String

        fileprivate init(string: String, characterIndex: String.Index) {
            self.string = string
            self.characterIndex = characterIndex
        }

        let characterIndex: String.Index

        var codeUnitIndex: Int {
            return string.utf16Index(forCharacterAt: characterIndex)
        }
    }

    struct ForwardGraphemeBreakSequence: Sequence {
        private let iterator: ForwardGraphemeBreakIterator

        fileprivate init(string: String, characterRange: Range<String.Index>) {
            iterator = ForwardGraphemeBreakIterator(string: string, characterRange: characterRange)
        }

        func makeIterator() -> ForwardGraphemeBreakIterator {
            return iterator
        }
    }

    struct ForwardGraphemeBreakIterator: IteratorProtocol {
        private let string: String
        private var currentIndex: String.Index
        private let endIndex: String.Index

        fileprivate init(string: String, characterRange: Range<String.Index>) {
            self.string = string
            self.currentIndex = characterRange.lowerBound
            self.endIndex = characterRange.upperBound
        }

        mutating func next() -> StringBreak? {
            if currentIndex < endIndex {
                let nextIndex = string.index(after: currentIndex)
                currentIndex = min(endIndex, nextIndex)

                return GraphemeBreak(string: string, characterIndex: currentIndex)
            }

            return nil
        }
    }
}

// MARK: - BackwardGraphemeBreakSequence

extension BreakClassifier {
    struct BackwardGraphemeBreakSequence: Sequence {
        private let iterator: BackwardGraphemeBreakIterator

        fileprivate init(string: String, characterRange: Range<String.Index>) {
            iterator = BackwardGraphemeBreakIterator(string: string, characterRange: characterRange)
        }

        func makeIterator() -> BackwardGraphemeBreakIterator {
            return iterator
        }
    }

    struct BackwardGraphemeBreakIterator: IteratorProtocol {
        private let string: String
        private let startIndex: String.Index
        private var currentIndex: String.Index

        fileprivate init(string: String, characterRange: Range<String.Index>) {
            self.string = string
            self.startIndex = characterRange.lowerBound
            self.currentIndex = characterRange.upperBound
        }

        mutating func next() -> StringBreak? {
            if currentIndex > startIndex {
                let previousIndex = string.index(before: currentIndex)
                currentIndex = max(startIndex, previousIndex)

                return GraphemeBreak(string: string, characterIndex: currentIndex)
            }

            return nil
        }
    }
}

// MARK: - ForwardLineBreakSequence

extension BreakClassifier {
    struct LineBreak: StringBreak {
        private let string: String

        fileprivate init(string: String, codeUnitIndex: Int) {
            self.string = string
            self.codeUnitIndex = codeUnitIndex
        }

        let codeUnitIndex: Int

        var characterIndex: String.Index {
            return string.characterIndex(forUTF16Index: codeUnitIndex)
        }
    }

    struct ForwardLineBreakSequence: Sequence {
        private let iterator: ForwardLineBreakIterator

        fileprivate init(_ classifier: BreakClassifier, codeUnitRange: Range<Int>) {
            self.iterator = ForwardLineBreakIterator(classifier, codeUnitRange: codeUnitRange)
        }

        func makeIterator() -> ForwardLineBreakIterator {
            return iterator
        }
    }

    struct ForwardLineBreakIterator: IteratorProtocol {
        fileprivate let classifier: BreakClassifier
        private var currentIndex: Int
        private let endIndex: Int

        init(_ classifier: BreakClassifier, codeUnitRange: Range<Int>) {
            self.classifier = classifier
            self.currentIndex = codeUnitRange.lowerBound
            self.endIndex = codeUnitRange.upperBound
        }

        mutating func next() -> StringBreak? {
            if currentIndex != endIndex {
                let lineBreaks = classifier.lineBreaks

                while currentIndex < endIndex {
                    defer { currentIndex += 1 }

                    let breakType = lineBreaks[currentIndex]
                    if breakType == LINEBREAK_MUSTBREAK || breakType == LINEBREAK_ALLOWBREAK {
                        break
                    }
                }

                return LineBreak(string: classifier.string, codeUnitIndex: currentIndex)
            }

            return nil
        }
    }
}

extension BreakClassifier {
    struct BackwardLineBreakSequence: Sequence {
        private let iterator: BackwardLineBreakIterator

        fileprivate init(_ classifier: BreakClassifier, codeUnitRange: Range<Int>) {
            self.iterator = BackwardLineBreakIterator(classifier, codeUnitRange: codeUnitRange)
        }

        func makeIterator() -> BackwardLineBreakIterator {
            return iterator
        }
    }

    struct BackwardLineBreakIterator: IteratorProtocol {
        fileprivate let classifier: BreakClassifier
        private let startIndex: Int
        private var currentIndex: Int

        init(_ classifier: BreakClassifier, codeUnitRange: Range<Int>) {
            self.classifier = classifier
            self.startIndex = codeUnitRange.lowerBound
            self.currentIndex = codeUnitRange.upperBound
        }

        mutating func next() -> StringBreak? {
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

                return LineBreak(string: classifier.string, codeUnitIndex: currentIndex)
            }

            return nil
        }
    }
}
