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

extension RandomAccessCollection
    where Element == BidiParagraph,
          Index == Int {
    func binarySearchIndex(forCodeUnitAt index: Int) -> Int {
        var low = 0
        var high = count - 1

        while low <= high {
            let mid = (low + high) >> 1

            let bidiParagraph = self[mid]
            let paragraphRange = bidiParagraph.codeUnitRange

            if index >= paragraphRange.upperBound {
                low = mid + 1
            } else if index < paragraphRange.lowerBound {
                high = mid - 1
            } else {
                return mid
            }
        }

        return -1
    }

    func binarySearchIndex(ofCharacterAt index: String.Index) -> Int {
        var low = 0
        var high = count - 1

        while low <= high {
            let mid = (low + high) >> 1

            let bidiParagraph = self[mid]
            let paragraphRange = bidiParagraph.stringRange

            if index >= paragraphRange.upperBound {
                low = mid + 1
            } else if index < paragraphRange.lowerBound {
                high = mid - 1
            } else {
                return mid
            }
        }

        return -1
    }

    func paragraph(forCodeUnitAt index: Int) -> BidiParagraph {
        return self[binarySearchIndex(forCodeUnitAt: index)]
    }

    func paragraph(forCharacterAt index: String.Index) -> BidiParagraph {
        return self[binarySearchIndex(ofCharacterAt: index)]
    }

    func baseLevel(forCodeUnitAt index: Int) -> UInt8 {
        return paragraph(forCodeUnitAt: index).baseLevel
    }

    func baseLevel(forCharacterAt index: String.Index) -> UInt8 {
        return paragraph(forCharacterAt: index).baseLevel
    }

    func forEachLineRun(in codeUnitRange: Range<Int>, body: (BidiRun) -> Void) {
        var paragraphIndex = binarySearchIndex(forCodeUnitAt: codeUnitRange.lowerBound)
        var feasibleStart: Int
        var feasibleEnd: Int

        var isRTL: Bool!
        var allLines: [BidiLine] = []

        repeat {
            let bidiParagraph = self[paragraphIndex]
            if isRTL == nil {
                isRTL = bidiParagraph.baseLevel & 1 == 1
            }

            let paragraphRange = bidiParagraph.codeUnitRange
            feasibleStart = Swift.max(paragraphRange.lowerBound, codeUnitRange.lowerBound)
            feasibleEnd = Swift.min(paragraphRange.upperBound, codeUnitRange.upperBound)

            if let bidiLine = bidiParagraph.makeLine(codeUnitRange: feasibleStart ..< feasibleEnd) {
                allLines.append(bidiLine)
            }

            paragraphIndex += 1
        } while feasibleEnd != codeUnitRange.upperBound

        if isRTL {
            for bidiLine in allLines.reversed() {
                for bidiRun in bidiLine.visualRuns {
                    body(bidiRun)
                }
            }
        } else {
            for bidiLine in allLines {
                for bidiRun in bidiLine.visualRuns {
                    body(bidiRun)
                }
            }
        }
    }
}
