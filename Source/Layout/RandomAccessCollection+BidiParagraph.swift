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

    func paragraph(forCodeUnitAt index: Int) -> BidiParagraph {
        return self[binarySearchIndex(forCodeUnitAt: index)]
    }

    func baseLevel(forCodeUnitAt index: Int) -> UInt8 {
        return paragraph(forCodeUnitAt: index).baseLevel
    }

    func forEachLineRun(in codeUnitRange: Range<Int>, body: (BidiRun) -> Void) {
        let lineStart = codeUnitRange.lowerBound
        let lineEnd = codeUnitRange.upperBound

        var paragraphIndex = binarySearchIndex(forCodeUnitAt: lineStart)
        let directionalParagraph = self[paragraphIndex]
        let isRTL = directionalParagraph.baseLevel & 1 == 1

        if (isRTL) {
            let paragraphEnd = directionalParagraph.codeUnitRange.upperBound
            if (paragraphEnd < lineEnd) {
                paragraphIndex = binarySearchIndex(forCodeUnitAt: lineEnd - 1)
            }
        }

        let next = isRTL ? -1 : 1
        var feasibleStart: Int
        var feasibleEnd: Int

        repeat {
            let bidiParagraph = self[paragraphIndex]
            let paragraphRange = bidiParagraph.codeUnitRange

            feasibleStart = Swift.max(paragraphRange.lowerBound, lineStart)
            feasibleEnd = Swift.min(paragraphRange.upperBound, lineEnd)

            if let bidiLine = bidiParagraph.makeLine(codeUnitRange: feasibleStart ..< feasibleEnd) {
                for bidiRun in bidiLine.visualRuns {
                    body(bidiRun)
                }
            }

            paragraphIndex += next
        } while isRTL ? feasibleStart != lineStart : feasibleEnd != lineEnd
    }
}
