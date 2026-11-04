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

/// Tests of the text of Core, which is made from attributed strings and can be edited.
final class TypesetterTextTests: XCTestCase {
    private let typeface = FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf"))!.typefaces[0]

    func testPlainText() {
        let text = Typesetter(string: "abc", defaultAttributes: [:])

        XCTAssertEqual(text.length, 3)
        XCTAssertEqual(text.string, "abc")
        XCTAssertEqual(text.string(in: 1 ..< 3), "bc")
        XCTAssertNil(text.string(in: 2 ..< 5))
        XCTAssertFalse(text.isMutable)
    }

    func testAttributes() throws {
        let source = NSMutableAttributedString(string: "abcabc")
        source.addAttributes(
            [.typeface: typeface, .typeSize: CGFloat(20.0)],
            range: NSRange(location: 0, length: 6)
        )
        source.addAttributes(
            [.foregroundColor: UIColor.red, .underlineStyle: 1,
                                                                                                                                                                                                                                      .fontFeatures: [SFNTTag("liga"): 0]],
            range: NSRange(location: 3, length: 3)
        )

        let text = Typesetter(text: source, defaultAttributes: [:])
        XCTAssertEqual(text.attributedString, source)

        let first = try XCTUnwrap(text.attributes(at: 0))
        XCTAssertEqual(first.length, 3)
        XCTAssertTrue(first.attributes[.typeface] as? Typeface === typeface)
        XCTAssertEqual(first.attributes[.typeSize] as? CGFloat, 20.0)
        XCTAssertNil(first.attributes[.foregroundColor])

        let second = try XCTUnwrap(text.attributes(at: 3))
        XCTAssertEqual(second.length, 3)
        XCTAssertEqual(second.attributes[.foregroundColor] as? UIColor, UIColor.red)
        XCTAssertEqual(second.attributes[.underlineStyle] as? Int, 1)
        XCTAssertEqual((second.attributes[.fontFeatures] as? [SFNTTag: Int])?["liga"], 0)

        XCTAssertNil(text.attributes(at: 6))
    }

    func testAttributedStringFollowsTheEdits() throws {
        let defaults: [NSAttributedString.Key: Any] = [.typeface: typeface, .typeSize: CGFloat(10.0)]
        let text = MutableTypesetter(attributedString: NSAttributedString(string: "abc"), defaultAttributes: defaults)

        XCTAssertEqual(text.attributedString.string, "abc")

        XCTAssertTrue(text.append("de"))
        XCTAssertEqual(text.attributedString.string, "abcde")
        XCTAssertEqual(text.attributedString.length, 5)
    }

    func testManyAttributesAreSetInOneShapingOfTheParagraph() throws {
        let defaults: [NSAttributedString.Key: Any] = [.typeface: typeface, .typeSize: CGFloat(10.0)]
        let text = NSMutableAttributedString(string: String(repeating: "abc ", count: 4000))

        // A change of an attribute shapes its paragraph again unless it is made in a batch. This
        // is one paragraph of 16,000 code units with 500 colors, which took half a minute.
        for index in 0 ..< 500 {
            text.addAttribute(
                .foregroundColor,
                value: UIColor(white: CGFloat(index % 10) / 10.0, alpha: 1.0),
                range: NSRange(location: index * 20, length: 5)
            )
        }

        let start = Date()
        let typesetter = Typesetter(text: text, defaultAttributes: defaults)

        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
        XCTAssertEqual(typesetter.length, 16000)
        XCTAssertNotNil(typesetter.attributes(at: 20)?.attributes[.foregroundColor])
    }

    func testEditing() throws {
        let defaults: [NSAttributedString.Key: Any] = [.typeface: typeface, .typeSize: CGFloat(10.0)]
        let text = MutableTypesetter(defaultAttributes: defaults)
        XCTAssertTrue(text.isMutable)

        text.beginEditing()
        XCTAssertTrue(text.append("abc"))
        XCTAssertTrue(text.insert("x", at: 1))
        XCTAssertFalse(text.insert("x", at: 9))
        XCTAssertTrue(text.replace(0 ..< 1, with: "yy"))

        // A batch takes attributes too, and no line can be made in it.
        XCTAssertTrue(text.setAttribute(.backgroundColor, value: UIColor.blue, in: 1 ..< 3))
        text.endEditing()

        XCTAssertEqual(text.string, "yyxbc")
        XCTAssertEqual(
            text.attributes(at: 1)?.attributes[.backgroundColor] as? UIColor,
            UIColor.blue
        )

        XCTAssertTrue(text.removeAttribute(.backgroundColor, in: 1 ..< 3))
        XCTAssertNil(text.attributes(at: 1)?.attributes[.backgroundColor])
        XCTAssertFalse(text.setAttribute(.typeSize, value: "large", in: 0 ..< 1))

        XCTAssertTrue(text.delete(in: 0 ..< 2))
        XCTAssertEqual(text.string, "xbc")

        // A copy does not follow the edits of the text.
        let typesetter = text.copy()
        text.setString("a")
        XCTAssertEqual(typesetter.string, "xbc")
        XCTAssertFalse(typesetter.isMutable)
        XCTAssertEqual(typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3).codeUnitRange, 0 ..< 3)

        let copy = typesetter.mutableCopy()
        copy.append("d")
        XCTAssertEqual(copy.string, "xbcd")
        XCTAssertEqual(typesetter.string, "xbc")
        XCTAssertEqual(copy.makeSimpleLine(codeUnitRange: 0 ..< 4).codeUnitRange, 0 ..< 4)
    }

    func testParagraphStyleReplacesTheOldOne() throws {
        let text = MutableTypesetter(defaultAttributes: [:])
        text.append("abc")

        let indented = NSMutableParagraphStyle()
        indented.headIndent = 20
        text.setAttribute(.paragraphStyle, value: indented, in: 0 ..< 3)
        text.setAttribute(.paragraphStyle, value: NSParagraphStyle(), in: 0 ..< 3)

        let style = try XCTUnwrap(
            text.attributes(at: 0)?.attributes[.paragraphStyle] as? NSParagraphStyle
        )
        XCTAssertEqual(style.headIndent, 0)
    }

    func testBoundaries() {
        // No typeface is needed to find where the words and the paragraphs are.
        let text = Typesetter(string: "Hello, world\nbye", defaultAttributes: [:])

        XCTAssertEqual(text.findBoundary(from: 0, type: .word, direction: .forward), 5)
        XCTAssertEqual(text.findBoundary(from: 12, type: .word, direction: .backward), 7)
        XCTAssertEqual(text.findBoundary(from: 14, type: .paragraph, direction: .backward), 13)
        XCTAssertNil(text.findBoundary(from: 16, type: .grapheme, direction: .forward))
        XCTAssertEqual(text.boundaryRange(at: 1, type: .word), 0 ..< 5)
        XCTAssertEqual(text.boundaryRange(at: 12, type: .paragraph), 0 ..< 13)
        XCTAssertEqual(text.boundaryRange(at: 16, type: .word), 16 ..< 16)
        XCTAssertNil(text.boundaryRange(at: 17, type: .word))
    }

    func testMissingTypeface() {
        // A text without a typeface can be made, but its lines cannot.
        let text = MutableTypesetter(defaultAttributes: [:])
        text.append("abc")

        XCTAssertEqual(text.string, "abc")
        XCTAssertEqual(text.findBoundary(from: 0, type: .grapheme, direction: .forward), 1)
    }
}
