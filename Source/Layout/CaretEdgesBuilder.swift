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

import CoreGraphics
import Foundation

struct CaretEdgesBuilder<GlyphAdvances, ClusterMap>
    where GlyphAdvances: RandomAccessCollection,
          GlyphAdvances.Index == Int,
          GlyphAdvances.Element == CGFloat,
          ClusterMap: RandomAccessCollection,
          ClusterMap.Index == Int,
          ClusterMap.Element == Int {
    let isBackward: Bool
    let isRTL: Bool
    let glyphAdvances: GlyphAdvances
    let clusterMap: ClusterMap
    let caretStops: [Bool]!

    private func makeCaretAdvances() -> [CGFloat] {
        let codeUnitCount = clusterMap.count
        var caretAdvances = Array<CGFloat>(repeating: .zero, count: codeUnitCount + 1)

        var glyphIndex = clusterMap[0] + 1
        var refIndex = glyphIndex
        var totalStops = 0
        var clusterStart = 0

        for codeUnitIndex in 1 ... codeUnitCount {
            let oldIndex = glyphIndex

            if codeUnitIndex != codeUnitCount {
                glyphIndex = clusterMap[codeUnitIndex] + 1

                if caretStops != nil && !caretStops[codeUnitIndex - 1] {
                    continue
                }

                totalStops += 1
            } else {
                totalStops += 1
                glyphIndex = (isBackward ? 0 : glyphAdvances.count + 1)
            }

            if glyphIndex != oldIndex {
                var clusterAdvance: CGFloat = 0
                var distance: CGFloat = 0
                var counter = 1

                // Find the advance of current cluster.
                if isBackward {
                    while refIndex > glyphIndex {
                        clusterAdvance += glyphAdvances[refIndex - 1]
                        refIndex -= 1
                    }
                } else {
                    while refIndex < glyphIndex {
                        clusterAdvance += glyphAdvances[refIndex - 1]
                        refIndex += 1
                    }
                }

                // Divide the advance evenly between cluster length.
                while clusterStart < codeUnitIndex {
                    var advance: CGFloat = 0

                    if caretStops == nil || caretStops[clusterStart] || clusterStart == codeUnitCount - 1 {
                        let steps = totalStops
                        let previous = distance

                        distance = (clusterAdvance * CGFloat(counter)) / CGFloat(steps)
                        advance = distance - previous
                        counter += 1
                    }

                    caretAdvances[clusterStart] = advance
                    clusterStart += 1
                }

                totalStops = 0
            }
        }

        return caretAdvances
    }

    func build() -> [CGFloat] {
        let codeUnitCount = clusterMap.count

        var caretEdges = makeCaretAdvances()
        var distance: CGFloat = 0

        if isRTL {
            var index = codeUnitCount - 1

            // Last edge should be zero.
            caretEdges[codeUnitCount] = 0;

            // Iterate in reverse direction.
            while index >= 0 {
                distance += caretEdges[index]
                caretEdges[index] = distance
                index -= 1
            }
        } else {
            var advance = caretEdges[0];

            // First edge should be zero.
            caretEdges[0] = 0;

            // Iterate in forward direction.
            for i in 1 ... codeUnitCount {
                distance += advance
                advance = caretEdges[i]
                caretEdges[i] = distance
            }
        }

        return caretEdges
    }
}
