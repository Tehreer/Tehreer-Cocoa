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

enum Clusters {
    static func glyphRange<CM>(in clusterMap: CM, for codeUnitRange: Range<Int>, isBackward: Bool, glyphCount: Int) -> Range<Int>
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        let lower: Int
        let upper: Int

        if !isBackward {
            lower = clusterMap[codeUnitRange.lowerBound]
            upper = forwardGlyphIndex(in: clusterMap, for: codeUnitRange.upperBound - 1, glyphCount: glyphCount) + 1
        } else {
            lower = clusterMap[codeUnitRange.upperBound - 1]
            upper = backwardGlyphIndex(in: clusterMap, for: codeUnitRange.lowerBound, glyphCount: glyphCount) + 1
        }

        return Range(uncheckedBounds: (lower: lower, upper: upper))
    }

    static func leadingGlyphIndex<CM>(in clusterMap: CM, for index: Int, isBackward: Bool, glyphCount: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        if !isBackward {
            return clusterMap[index]
        }

        return backwardGlyphIndex(in: clusterMap, for: index, glyphCount: glyphCount)
    }

    static func trailingGlyphIndex<CM>(in clusterMap: CM, for index: Int, isBackward: Bool, glyphCount: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        if !isBackward {
            return forwardGlyphIndex(in: clusterMap, for: index, glyphCount: glyphCount)
        }

        return clusterMap[index]
    }

    private static func forwardGlyphIndex<CM>(in clusterMap: CM, for index: Int, glyphCount: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        let common = clusterMap[index]
        let length = clusterMap.count

        for i in (index + 1) ..< length {
            let mapping = clusterMap[i]
            if mapping != common {
                return mapping - 1
            }
        }

        return glyphCount - 1
    }

    private static func backwardGlyphIndex<CM>(in clusterMap: CM, for index: Int, glyphCount: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        let common = clusterMap[index]

        for i in (0 ..< index).reversed() {
            let mapping = clusterMap[i]
            if mapping != common {
                return mapping - 1
            }
        }

        return glyphCount - 1
    }

    static func actualClusterStart<CM>(in clusterMap: CM, for index: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        let common = clusterMap[index]

        for i in (0 ..< index).reversed() {
            if clusterMap[i] != common {
                return i + 1
            }
        }

        return 0
    }

    static func actualClusterEnd<CM>(in clusterMap: CM, for index: Int) -> Int
        where CM: RandomAccessCollection, CM.Index == Int, CM.Element == Int {
        let common = clusterMap[index]
        let length = clusterMap.count

        for i in (index + 1) ..< length {
            if clusterMap[i] != common {
                return i
            }
        }

        return length
    }
}
