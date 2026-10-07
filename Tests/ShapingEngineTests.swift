//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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

/// Tests of the shaping engine and its results. In the test font, the glyphs 'a', 'b' and 'c' are
/// 1114, 1149 and 1072 units wide at a type size of 2048, and any other character shows the missing
/// glyph that is 908 units wide.
final class ShapingEngineTests: XCTestCase {
    private func makeEngine() throws -> ShapingEngine {
        let fontFile = try XCTUnwrap(FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf")))

        let engine = ShapingEngine()
        engine.typeface = fontFile.typefaces[0]
        engine.typeSize = 2048.0

        return engine
    }

    func testDefaultDirections() {
        XCTAssertEqual(ShapingEngine.defaultDirectionForScript("latn"), .leftToRight)
        XCTAssertEqual(ShapingEngine.defaultDirectionForScript("arab"), .rightToLeft)
        XCTAssertEqual(ShapingEngine.defaultDirectionForScript("hebr"), .rightToLeft)
    }

    func testShapingForward() throws {
        let engine = try makeEngine()
        let result = engine.shape(string: "abc", codeUnitRange: 0 ..< 3)

        XCTAssertEqual(result.codeUnitRange, 0 ..< 3)
        XCTAssertFalse(result.isBackward)
        XCTAssertEqual(Array(result.glyphIDs), [1, 2, 3])
        XCTAssertEqual(Array(result.glyphAdvances), [1114.0, 1149.0, 1072.0])
        XCTAssertEqual(result.glyphOffsets.map { $0.x }, [0.0, 0.0, 0.0])
        XCTAssertEqual(Array(result.clusterMap), [0, 1, 2])
    }

    func testShapingARange() throws {
        let engine = try makeEngine()
        let result = engine.shape(string: "xabcx", codeUnitRange: 1 ..< 4)

        XCTAssertEqual(result.codeUnitRange, 1 ..< 4)
        XCTAssertEqual(Array(result.glyphIDs), [1, 2, 3])
        XCTAssertEqual(result.startIndex, "xabcx".index(after: "xabcx".startIndex))
    }

    func testMissingGlyphs() throws {
        let engine = try makeEngine()
        let result = engine.shape(string: "a b", codeUnitRange: 0 ..< 3)

        XCTAssertEqual(Array(result.glyphIDs), [1, 0, 2])
        XCTAssertEqual(Array(result.glyphAdvances), [1114.0, 908.0, 1149.0])
    }

    func testTypeSizeScalesAdvances() throws {
        let engine = try makeEngine()
        engine.typeSize = 1024.0

        let result = engine.shape(string: "ab", codeUnitRange: 0 ..< 2)
        XCTAssertEqual(Array(result.glyphAdvances), [557.0, 574.5])
    }

    func testRightToLeftAndBackward() throws {
        let engine = try makeEngine()
        engine.writingDirection = .rightToLeft

        // The text is in its logical order, as it is shaped forward. Only the pen moves left.
        let rtl = engine.shape(string: "abc", codeUnitRange: 0 ..< 3)
        XCTAssertFalse(rtl.isBackward)
        XCTAssertEqual(Array(rtl.glyphIDs), [1, 2, 3])
        XCTAssertEqual(Array(rtl.clusterMap), [0, 1, 2])
        XCTAssertEqual(rtl.makeCaretEdges(caretStops: nil), [3335.0, 2221.0, 1072.0, 0.0])

        // Backward order reads the text from its end, which a left to right direction flips back.
        engine.writingDirection = .leftToRight
        engine.shapingOrder = .backward

        let backward = engine.shape(string: "abc", codeUnitRange: 0 ..< 3)
        XCTAssertTrue(backward.isBackward)
        XCTAssertEqual(Array(backward.glyphIDs), [3, 2, 1])
        XCTAssertEqual(Array(backward.clusterMap), [2, 1, 0])
    }

    func testCaretEdges() throws {
        let engine = try makeEngine()
        let result = engine.shape(string: "abc", codeUnitRange: 0 ..< 3)

        XCTAssertEqual(result.makeCaretEdges(caretStops: nil), [0.0, 1114.0, 2263.0, 3335.0])

        // Without a caret stop before a cluster, the edge before it is the one after the cluster
        // that comes first.
        XCTAssertEqual(result.makeCaretEdges(caretStops: [true, false, true]), [0.0, 1114.0, 1114.0, 3335.0])
        XCTAssertEqual(result.makeCaretEdges(caretStops: [false, true, true]), [0.0, 0.0, 2263.0, 3335.0])
        XCTAssertEqual(result.makeCaretEdges(caretStops: [true, true, false]), [0.0, 1114.0, 2263.0, 3335.0])
    }

    func testResultOutlivesEngine() throws {
        var engine: ShapingEngine? = try makeEngine()
        let result = engine!.shape(string: "abc", codeUnitRange: 0 ..< 3)
        engine = nil

        XCTAssertEqual(Array(result.glyphIDs), [1, 2, 3])
    }

    func testFeatures() throws {
        let engine = try makeEngine()
        engine.openTypeFeatures = ["kern": 0, "liga": 1]

        let result = engine.shape(string: "abc", codeUnitRange: 0 ..< 3)
        XCTAssertEqual(Array(result.glyphIDs), [1, 2, 3])
    }
}
