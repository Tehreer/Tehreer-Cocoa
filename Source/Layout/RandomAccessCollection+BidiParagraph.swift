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

    func paragraph(forCharacterAt index: String.Index) -> BidiParagraph {
        return self[binarySearchIndex(ofCharacterAt: index)]
    }

    func baseLevel(forCharacterAt index: String.Index) -> UInt8 {
        return paragraph(forCharacterAt: index).baseLevel
    }

    func forEachLineRun(inCharacterRange range: Range<String.Index>, body: (_ : BidiRun) -> Void) {
        var paragraphIndex = binarySearchIndex(ofCharacterAt: range.lowerBound)
        var feasibleStart: String.Index
        var feasibleEnd: String.Index

        repeat {
            let bidiParagraph = self[paragraphIndex]
            feasibleStart = Swift.max(bidiParagraph.startIndex, range.lowerBound)
            feasibleEnd = Swift.min(bidiParagraph.endIndex, range.upperBound)

            let bidiLine: BidiLine! = bidiParagraph.makeLine(characterRange: feasibleStart ..< feasibleEnd)
            for bidiRun in bidiLine.visualRuns {
                body(bidiRun)
            }

            paragraphIndex += 1
        } while feasibleEnd != range.upperBound
    }
}
