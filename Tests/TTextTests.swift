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
final class TTextTests: XCTestCase {
    private let typeface = FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf"))!.typefaces[0]

    func testPlainText() {
        let text = TText(string: "abc")

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

        let text = TText(attributedString: source)
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

    func testEditing() throws {
        let text = TMutableText()
        XCTAssertTrue(text.isMutable)

        text.beginEditing()
        XCTAssertTrue(text.append("abc"))
        XCTAssertTrue(text.insert("x", at: 1))
        XCTAssertFalse(text.insert("x", at: 9))
        XCTAssertTrue(text.replace(0 ..< 1, with: "yy"))
        XCTAssertTrue(text.setAttribute(.typeface, value: typeface, in: 0 ..< 5))
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

        // The typesetter works on a copy of the text.
        let typesetter = Typesetter(text: text, defaultAttributes: [.typeSize: CGFloat(10.0)])
        text.setString("a")
        XCTAssertEqual(typesetter.text.string, "xbc")
        XCTAssertEqual(typesetter.codeUnitCount, 3)
        XCTAssertFalse(typesetter.text.isMutable)
        XCTAssertEqual(typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3).codeUnitRange, 0 ..< 3)

        let copy = typesetter.text.mutableCopy()
        copy.append("d")
        XCTAssertEqual(copy.string, "xbcd")
        XCTAssertEqual(typesetter.text.string, "xbc")
    }
}
