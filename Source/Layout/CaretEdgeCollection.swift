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

import CoreGraphics
import Foundation

class CaretEdgeCollection<Base>: IntrinsicCollection<CGFloat>
    where Base: RandomAccessCollection,
          Base.Index == Int,
          Base.Element == CGFloat {
    private let allEdges: Base
    private let offset: Int
    private let edgeCount: Int
    private let pivotDistance: CGFloat

    convenience init(allEdges: Base) {
        self.init(allEdges: allEdges,
                  chunkOffset: 0, chunkLength: allEdges.count,
                  startExtra: 0, endExtra: 0, isRTL: false)
    }

    init(allEdges: Base,
         chunkOffset: Int, chunkLength: Int,
         startExtra: Int, endExtra: Int, isRTL: Bool) {
        self.allEdges = allEdges
        self.offset = chunkOffset
        self.edgeCount = chunkLength + 1
        self.pivotDistance = allEdges[(isRTL ? chunkLength - endExtra : startExtra) + chunkOffset]
    }

    private func edge(at index: Int) -> CGFloat {
        return allEdges[index + offset]
    }

    func distance(of range: Range<Int>, isRTL: Bool) -> CGFloat {
        let firstEdge = edge(at: range.lowerBound)
        let lastEdge = edge(at: range.upperBound)

        return isRTL ? firstEdge - lastEdge : lastEdge - firstEdge
    }

    override var count: Int {
        return edgeCount
    }

    override func item(at index: Int) -> CGFloat {
        return edge(at: index) - pivotDistance
    }
}
