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

import XCTest
@testable import TehreerCocoa

final class LineBoxesTests: XCTestCase {
    private func makeLineBoxes(lineCount: Int) -> LineBoxes {
        var lineBoxes = LineBoxes()

        for index in 0 ..< lineCount {
            let overflow: CGFloat = index % 7 == 0 ? 900.0 : 0.0
            lineBoxes.append(CGRect(x: 0.0, y: CGFloat(index) * 30.0, width: 320.0, height: 30.0 + overflow))
        }

        return lineBoxes
    }

    func testLineIndexesMatchAScanOfAllBoxes() {
        let lineBoxes = makeLineBoxes(lineCount: 2000)

        for top in stride(from: -100.0, to: 61_000.0, by: 733.0) {
            let rect = CGRect(x: 0.0, y: top, width: 320.0, height: 480.0)
            let expected = lineBoxes.boxes.indices.filter { lineBoxes.boxes[$0].intersects(rect) }

            var found: [Int] = []
            lineBoxes.enumerateLineIndexes(intersecting: rect) { found.append($0) }

            XCTAssertEqual(found.sorted(), expected, "at \(top)")
        }
    }

    func testFirstLineBelowAYSkipsLinesThatEndAbove() {
        let lineBoxes = makeLineBoxes(lineCount: 2000)

        XCTAssertEqual(lineBoxes.firstLineIndex(below: 100.0) { lineBoxes.boxes[$0].maxY > 100.0 }, 0)
        XCTAssertEqual(lineBoxes.firstLineIndex(below: 3015.0) { lineBoxes.boxes[$0].maxY > 3015.0 }, 70)
        XCTAssertNil(lineBoxes.firstLineIndex(below: 1_000_000.0) { _ in true })
    }

    func testNoLineIsFoundWithoutBoxes() {
        var found: [Int] = []
        LineBoxes().enumerateLineIndexes(intersecting: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 480.0)) { found.append($0) }

        XCTAssertTrue(found.isEmpty)
    }
}
