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

import CoreGraphics

extension RandomAccessCollection
    where Element == IntrinsicRun,
          Index == Int {
    func binarySearchIndex(forCodeUnitAt index: Int) -> Int {
        var low = 0
        var high = count - 1

        while low <= high {
            let mid = (low + high) >> 1
            let intrinsicRun = self[mid]
            let runRange = intrinsicRun.codeUnitRange

            if index >= runRange.upperBound {
                low = mid + 1
            } else if index < runRange.lowerBound {
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
            let intrinsicRun = self[mid]

            if index >= intrinsicRun.endIndex {
                low = mid + 1
            } else if index < intrinsicRun.startIndex {
                high = mid - 1
            } else {
                return mid
            }
        }

        return -1
    }

    func measureCharacters(in codeUnitRange: Range<Int>) -> CGFloat {
        var extent: CGFloat = 0.0

        if !codeUnitRange.isEmpty {
            var startIndex = codeUnitRange.lowerBound
            let endIndex = codeUnitRange.upperBound

            var runIndex = binarySearchIndex(forCodeUnitAt: startIndex)

            repeat {
                let intrinsicRun = self[runIndex]
                let segmentEnd = Swift.min(endIndex, intrinsicRun.codeUnitRange.upperBound)
                extent += intrinsicRun.distance(forCodeUnitRange: startIndex ..< segmentEnd)

                startIndex = segmentEnd
                runIndex += 1
            } while startIndex < endIndex
        }

        return extent
    }
}
