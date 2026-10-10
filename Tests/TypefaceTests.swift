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

/// Tests of the additions to typefaces: table reads, scalability, bitmap strikes and glyph names.
final class TypefaceTests: XCTestCase {
    private func makeTypeface(_ name: String) throws -> Typeface {
        return try XCTUnwrap(FontFile(path: TestFonts.path(name))).typefaces[0]
    }

    func testTables() throws {
        let typeface = try makeTypeface("Roboto-Regular.abc.ttf")
        let size = typeface.sizeOfTable("head")

        XCTAssertGreaterThan(size, 0)
        XCTAssertEqual(typeface.dataOfTable("head")?.count, size)
        XCTAssertEqual(typeface.dataOfTable("head", offset: 4, length: 8)?.count, 8)
        XCTAssertEqual(typeface.dataOfTable("head", offset: size - 2, length: 8)?.count, 2)
        XCTAssertNil(typeface.dataOfTable("head", offset: size, length: 8))
        XCTAssertEqual(typeface.sizeOfTable("ZZZZ"), 0)
        XCTAssertNil(typeface.dataOfTable("ZZZZ"))
    }

    func testScalableAndStrikes() throws {
        let outline = try makeTypeface("Roboto-Regular.abc.ttf")
        XCTAssertTrue(outline.isScalable)
        XCTAssertTrue(outline.bitmapStrikes.isEmpty)

        let emoji = try makeTypeface("NotoColorEmoji-CBDT.flags.ttf")
        XCTAssertFalse(emoji.isScalable)
        XCTAssertFalse(emoji.bitmapStrikes.isEmpty)
    }

    func testGlyphNames() throws {
        // The names come from the post table of the font.
        let typeface = try makeTypeface("Roboto-Regular.names.ttf")

        XCTAssertEqual(typeface.glyphName(forGlyph: 1), "a")
        XCTAssertEqual(typeface.glyphName(forGlyph: 0), ".notdef")
        XCTAssertNil(typeface.glyphName(forGlyph: 100))
        XCTAssertEqual(typeface.variantGlyphID(forCodePoint: 0x61, selector: 0xFE00), 0)
        XCTAssertFalse(TehreerCore.version.isEmpty)
    }
}
