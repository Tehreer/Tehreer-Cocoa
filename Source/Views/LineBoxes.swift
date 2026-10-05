//
// Copyright (C) 2026 Muhammad Tayyab Akram
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

/// A horizontal band of the text, and the indexes of the lines whose boxes touch it.
struct LinePage {
    let band: Int
    var lineIndexes: [Int] = []
}

/// The boxes of the lines of a frame, with the pages that tell which lines are in which band.
struct LineBoxes {
    private static let pageHeight: CGFloat = 512.0

    private(set) var boxes: [CGRect] = []
    private var pages: [LinePage] = []

    private static func band(of y: CGFloat) -> Int {
        return Int((y / pageHeight).rounded(.down))
    }

    mutating func append(_ box: CGRect) {
        let lineIndex = boxes.count
        boxes.append(box)

        for band in Self.band(of: box.minY) ... Self.band(of: box.maxY) {
            let pageIndex = firstPageIndex { $0.band >= band }

            if pageIndex < pages.count && pages[pageIndex].band == band {
                pages[pageIndex].lineIndexes.append(lineIndex)
            } else {
                pages.insert(LinePage(band: band, lineIndexes: [lineIndex]), at: pageIndex)
            }
        }
    }

    /// Calls `body` once for each line that intersects the rect, without allocating.
    ///
    /// The pages of the top and the bottom of the rect are found by binary search. A line that is
    /// in several pages is reported by the first page that the search range reaches.
    func enumerateLineIndexes(intersecting rect: CGRect, _ body: (Int) -> Void) {
        let topBand = Self.band(of: rect.minY)
        let bottomBand = Self.band(of: rect.maxY)

        var pageIndex = firstPageIndex { $0.band >= topBand }

        while pageIndex < pages.count && pages[pageIndex].band <= bottomBand {
            let band = pages[pageIndex].band

            for lineIndex in pages[pageIndex].lineIndexes {
                let box = boxes[lineIndex]

                if box.intersects(rect) && max(Self.band(of: box.minY), topBand) == band {
                    body(lineIndex)
                }
            }

            pageIndex += 1
        }
    }

    /// Returns the first line that is below `y` according to `isBelow`, looking only at the pages
    /// that reach `y` or lie under it.
    func firstLineIndex(below y: CGFloat, where isBelow: (Int) -> Bool) -> Int? {
        let topBand = Self.band(of: y)

        for pageIndex in firstPageIndex(where: { $0.band >= topBand }) ..< pages.count {
            if let lineIndex = pages[pageIndex].lineIndexes.first(where: isBelow) {
                return lineIndex
            }
        }

        return nil
    }

    private func firstPageIndex(where predicate: (LinePage) -> Bool) -> Int {
        var low = 0
        var high = pages.count

        while low < high {
            let mid = (low + high) / 2

            if predicate(pages[mid]) {
                high = mid
            } else {
                low = mid + 1
            }
        }

        return low
    }
}
