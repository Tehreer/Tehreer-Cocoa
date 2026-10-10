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

/// Tests of the font files and the typefaces that they create, which come from Tehreer Core. The
/// fonts are the small ones that Core uses for its own tests.
final class FontFileTests: XCTestCase {
    private func fontPath(_ name: String) -> String {
        return TestFonts.path(name)
    }

    func testStaticFont() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("Roboto-Regular.abc.ttf")))
        XCTAssertEqual(fontFile.typefaces.count, 1)

        let typeface = fontFile.typefaces[0]
        XCTAssertFalse(typeface.isVariable)
        XCTAssertEqual(typeface.familyName, "Roboto")
        XCTAssertEqual(typeface.styleName, "Regular")
        XCTAssertEqual(typeface.fullName, "Roboto Regular")
        XCTAssertEqual(typeface.weight, .regular)
        XCTAssertEqual(typeface.unitsPerEm, 2048)
        XCTAssertEqual(typeface.ascent, 1900)
        XCTAssertEqual(typeface.descent, 500)

        XCTAssertEqual(typeface.glyphID(forCodePoint: 0x61), 1)
        XCTAssertEqual(typeface.glyphID(forCodePoint: 0x7A), 0)
        XCTAssertEqual(typeface.advance(forGlyph: 1, typeSize: 2048.0, vertical: false), 1114.0)
        XCTAssertNotNil(typeface.path(forGlyph: 1, typeSize: 2048.0, transform: nil))
    }

    func testFontFromData() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: fontPath("Roboto-Regular.abc.ttf")))
        let fontFile = try XCTUnwrap(FontFile(data: data))

        XCTAssertEqual(fontFile.typefaces.count, 1)
        XCTAssertEqual(fontFile.typefaces[0].familyName, "Roboto")

        XCTAssertNil(FontFile(data: Data()))
        XCTAssertNil(FontFile(path: fontPath("Missing.ttf")))
    }

    func testVariableFontHasATypefacePerNamedStyle() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("Roboto-Variable.abc.ttf")))
        let typefaces = fontFile.typefaces

        XCTAssertEqual(typefaces.count, 18)

        XCTAssertTrue(typefaces[0].isVariable)
        XCTAssertEqual(typefaces[0].styleName, "Thin")
        XCTAssertEqual(typefaces[0].fullName, "Roboto Thin")
        XCTAssertEqual(typefaces[0].weight, .thin)
        XCTAssertEqual(Array(typefaces[0].variationCoordinates), [100.0, 100.0])

        XCTAssertEqual(typefaces[3].styleName, "Regular")
        XCTAssertEqual(typefaces[3].fullName, "Roboto Regular")
        XCTAssertEqual(typefaces[3].weight, .regular)

        let axes = typefaces[0].variationAxes
        XCTAssertEqual(axes.map { $0.name }, ["Weight", "Width"])
        XCTAssertEqual(axes.map { $0.defaultValue }, [400.0, 100.0])
        XCTAssertEqual(typefaces[0].namedStyles.count, 18)
    }

    func testVariationInstance() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("Roboto-Variable.abc.ttf")))
        let base = fontFile.typefaces[3]

        let instance = try XCTUnwrap(base.variationInstance(forCoordinates: [100.0, 100.0]))
        XCTAssertEqual(instance.styleName, "Thin")
        XCTAssertEqual(instance.fullName, "Roboto Thin")

        // The coordinates that match no style leave the instance without them.
        let custom = try XCTUnwrap(base.variationInstance(forCoordinates: [123.0, 100.0]))
        XCTAssertEqual(custom.styleName, "")
        XCTAssertEqual(custom.fullName, "")
        XCTAssertEqual(Array(custom.variationCoordinates), [123.0, 100.0])

        // The base is not changed.
        XCTAssertEqual(Array(base.variationCoordinates), [400.0, 100.0])

        let fixed = try XCTUnwrap(FontFile(path: fontPath("Roboto-Regular.abc.ttf"))).typefaces[0]
        XCTAssertNil(fixed.variationInstance(forCoordinates: [1.0]))
    }

    func testAxisFlags() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("Roboto-Variable.hidden.ttf")))
        let axes = fontFile.typefaces[0].variationAxes

        XCTAssertTrue(axes[0].flags.contains(.hiddenAxis))
        XCTAssertTrue(axes[1].flags.isEmpty)
    }

    func testColorFont() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("RocherColorGX.abc.ttf")))

        // The font has four instances, and a fifth one for its default coordinates.
        XCTAssertEqual(fontFile.typefaces.count, 5)

        let typeface = fontFile.typefaces[0]
        XCTAssertEqual(typeface.styleName, "Regular")
        XCTAssertEqual(typeface.variationAxes.map { $0.name }, ["Bevel", ""])
        XCTAssertEqual(typeface.paletteEntryNames.count, 4)
        XCTAssertEqual(typeface.predefinedPalettes.count, 11)
        XCTAssertEqual(typeface.associatedColors.count, 4)

        let colors = [UIColor.red, UIColor.green, UIColor.blue, UIColor.white]
        let instance = try XCTUnwrap(typeface.colorInstance(forColors: colors))
        let associated = instance.associatedColors

        XCTAssertEqual(associated.count, 4)
        XCTAssertEqual(associated[0], UIColor.red)
        XCTAssertEqual(associated[2], UIColor.blue)
        XCTAssertEqual(
            Array(typeface.associatedColors),
            Array(typeface.predefinedPalettes[0].colors)
        )
    }

    func testNamesInMacRoman() throws {
        let fontFile = try XCTUnwrap(FontFile(path: fontPath("nameID.dup.expected.ttf")))
        XCTAssertEqual(fontFile.typefaces[0].familyName, "Roboto")
    }
}
