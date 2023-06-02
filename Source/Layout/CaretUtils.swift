//
// Copyright (C) 2023 Muhammad Tayyab Akram
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

struct CaretUtils<CaretEdges>
    where CaretEdges: RandomAccessCollection,
          CaretEdges.Element == CGFloat,
          CaretEdges.Index == Int {
    let caretEdges: CaretEdges
    let isRTL: Bool

    func leftMargin(inRange range: ClosedRange<Int>) -> CGFloat {
        return caretEdges[isRTL ? range.upperBound : range.lowerBound]
    }

    func distance(forRange range: ClosedRange<Int>) -> CGFloat {
        let firstEdge = caretEdges[range.lowerBound]
        let lastEdge = caretEdges[range.upperBound]

        return isRTL ? firstEdge - lastEdge : lastEdge - firstEdge
    }

    func indexOfElement(at distance: CGFloat) -> Int {
        let firstIndex = 0
        let lastIndex = caretEdges.count - 1

        return indexOfElement(at: distance, inRange: firstIndex ... lastIndex)
    }

    func indexOfElement(at distance: CGFloat, inRange range: ClosedRange<Int>) -> Int {
        let leftMargin = leftMargin(inRange: range)

        var leadingIndex: Int = -1
        var trailingIndex: Int = -1

        var leadingEdge: CGFloat = .zero
        var trailingEdge: CGFloat = .zero

        var index = isRTL ? range.upperBound : range.lowerBound
        let next = isRTL ? -1 : 1

        while index <= range.upperBound && index >= range.lowerBound {
            let caretEdge = caretEdges[index] - leftMargin

            if caretEdge <= distance {
                leadingIndex = index
                leadingEdge = caretEdge
            } else {
                trailingIndex = index
                trailingEdge = caretEdge
                break
            }

            index += next
        }

        if leadingIndex == -1 {
            // Nothing is covered by the input distance.
            return range.lowerBound
        }

        if trailingIndex == -1 {
            // Whole range is covered by the input distance.
            return range.upperBound
        }

        if distance <= (leadingEdge + trailingEdge) / 2.0 {
            // Input distance is closer to first edge.
            return leadingIndex
        }

        // Input distance is closer to second edge.
        return trailingIndex
    }
}
