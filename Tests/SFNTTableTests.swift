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

/// Tests of the SFNT tables and the Unicode properties of code points.
final class SFNTTableTests: XCTestCase {
    private func makeTypeface(_ name: String = "Roboto-Regular.names.ttf") throws -> Typeface {
        return try XCTUnwrap(FontFile(path: TestFonts.path(name))).typefaces[0]
    }

    func testTables() throws {
        let typeface = try makeTypeface()

        let head = try XCTUnwrap(HeadTable(typeface: typeface))
        XCTAssertEqual(head.unitsPerEm, typeface.unitsPerEm)
        XCTAssertEqual(head.magicNumber, 0x5F0F3CF5)

        let maxp = try XCTUnwrap(MaxpTable(typeface: typeface))
        XCTAssertEqual(maxp.numGlyphs, typeface.glyphCount)

        let hhea = try XCTUnwrap(HheaTable(typeface: typeface))
        XCTAssertEqual(Int(hhea.ascender), typeface.ascent)

        let os2 = try XCTUnwrap(OS2Table(typeface: typeface))
        XCTAssertEqual(os2.panose.count, 10)

        let post = try XCTUnwrap(PostTable(typeface: typeface))
        XCTAssertEqual(post.numberOfGlyphs, typeface.glyphCount)
        XCTAssertEqual(post.glyphName(at: 1), "a")
    }

    func testNameTable() throws {
        let typeface = try makeTypeface()
        let table = try XCTUnwrap(NameTable(typeface: typeface))

        XCTAssertGreaterThan(table.recordCount, 0)

        let family = table.records.first { $0.nameID == 1 && $0.string != nil }
        XCTAssertEqual(family?.string, typeface.familyName)
    }

    func testCodePoints() {
        XCTAssertEqual(CodePoint.bidiClass(of: "a"), .leftToRight)
        XCTAssertEqual(CodePoint.bidiClass(of: "\u{0627}"), .arabicLetter)
        XCTAssertEqual(CodePoint.generalCategory(of: "A"), .uppercaseLetter)
        XCTAssertEqual(CodePoint.script(of: "\u{0627}"), .arabic)
        XCTAssertEqual(CodePoint.mirror(of: "("), ")")
        XCTAssertNil(CodePoint.mirror(of: "a"))
        XCTAssertEqual(Script.arabic.unicodeTag, "Arab")
    }

    func testBidiClasses() throws {
        let algorithm = try XCTUnwrap(BidiAlgorithm(string: "a\u{0627}1"))

        XCTAssertEqual(
            Array(algorithm.characterBidiClasses),
            [.leftToRight, .arabicLetter, .europeanNumber]
        )
    }
}
