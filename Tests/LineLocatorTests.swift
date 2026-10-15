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

final class LineLocatorTests: XCTestCase {
    private let typeface = FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf"))!.typefaces[0]

    private func makeFrame() throws -> ComposedFrame {
        let text = NSAttributedString(string: String(repeating: "abc ", count: 60))
        let resolver = FrameResolver()
        resolver.typesetter = Typesetter(
            text: text,
            defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(20.0)]
        )
        resolver.frameWidth = 150.0
        resolver.frameHeight = 100_000.0

        return try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< text.length))
    }

    private func lines(_ locator: LineLocator, in rect: CGRect) -> [Int] {
        var indexes: [Int] = []
        locator.findLines(in: rect, into: &indexes)

        return indexes
    }

    private func makeRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.typeface = typeface
        renderer.typeSize = 20.0

        return renderer
    }

    func testBoxesCoverTheLines() throws {
        let frame = try makeFrame()
        let locator = try XCTUnwrap(frame.makeLineLocator(renderer: makeRenderer()))

        XCTAssertEqual(locator.lineCount, frame.lines.count)
        XCTAssertGreaterThan(locator.lineCount, 5)

        for (index, line) in frame.lines.enumerated() {
            let box = locator.box(ofLineAt: index)

            XCTAssertLessThanOrEqual(box.minY, (line.origin.y - line.ascent))
            XCTAssertGreaterThanOrEqual(box.maxY, (line.origin.y + line.descent + line.leading))
            XCTAssertEqual(box, box.integral)
        }
    }

    func testLinesMatchAScanOfAllBoxes() throws {
        let frame = try makeFrame()
        let locator = try XCTUnwrap(frame.makeLineLocator(renderer: makeRenderer()))
        let boxes = (0 ..< locator.lineCount).map { locator.box(ofLineAt: $0) }

        for top in stride(from: -50.0, to: frame.height, by: 37.0) {
            let rect = CGRect(x: 0.0, y: top, width: 150.0, height: 90.0)
            let expected = boxes.indices.filter { boxes[$0].intersects(rect) }

            XCTAssertEqual(lines(locator, in: rect).sorted(), expected, "at \(top)")
        }

        XCTAssertTrue(lines(locator, in: CGRect(x: 0.0, y: 1.0e7, width: 10.0, height: 10.0)).isEmpty)
    }

    func testFoundLinesReuseTheArray() throws {
        let frame = try makeFrame()
        let locator = try XCTUnwrap(frame.makeLineLocator(renderer: makeRenderer()))

        var indexes: [Int] = []
        locator.findLines(in: CGRect(x: 0.0, y: 0.0, width: 150.0, height: frame.height), into: &indexes)
        XCTAssertEqual(indexes.count, locator.lineCount)

        let capacity = indexes.capacity
        locator.findLines(in: CGRect(x: 0.0, y: 0.0, width: 150.0, height: 30.0), into: &indexes)
        XCTAssertLessThan(indexes.count, locator.lineCount)
        XCTAssertEqual(indexes.capacity, capacity)
    }

    func testEnumerationCanBeStopped() throws {
        let frame = try makeFrame()
        let locator = try XCTUnwrap(frame.makeLineLocator(renderer: makeRenderer()))

        var count = 0
        locator.enumerateLines(in: CGRect(
            x: 0.0,
            y: 0.0,
            width: 150.0,
            height: frame.height
        )) { (_, stop) in
            count += 1
            stop = true
        }

        XCTAssertEqual(count, 1)
    }

    func testFirstLineBelow() throws {
        let frame = try makeFrame()
        let locator = try XCTUnwrap(frame.makeLineLocator(renderer: makeRenderer()))
        let line = frame.lines[3]

        XCTAssertEqual(locator.indexOfFirstLine(below: -10.0), 0)

        let index = try XCTUnwrap(locator.indexOfFirstLine(below: (line.origin.y - line.ascent) + 1.0))
        XCTAssertTrue(index == 2 || index == 3)

        XCTAssertNil(locator.indexOfFirstLine(below: 1.0e7))
    }
}
