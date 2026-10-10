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

/// Tests of the typeface manager, which keeps its registry in Core.
final class TypefaceManagerTests: XCTestCase {
    private let manager = TypefaceManager.default
    private var registered: [Typeface] = []

    override func tearDown() {
        for typeface in registered {
            manager.unregister(typeface)
        }

        registered = []
    }

    private func makeTypeface(_ name: String, index: Int = 0) throws -> Typeface {
        let fontFile = try XCTUnwrap(FontFile(path: TestFonts.path(name)))

        return fontFile.typefaces[index]
    }

    private func register(_ typeface: Typeface, tag: TypefaceTag = 0, familyID: TypeFamilyID = 0) {
        manager.register(typeface, forTag: tag, familyID: familyID)
        registered.append(typeface)
    }

    func testTags() throws {
        let first = try makeTypeface("Roboto-Regular.abc.ttf")
        let second = try makeTypeface("Roboto-Variable.abc.ttf")

        register(first, tag: 11)
        register(second)

        XCTAssertTrue(manager.typeface(forTag: 11) === first)
        XCTAssertEqual(manager.tag(of: first), 11)
        XCTAssertEqual(manager.tag(of: second), 0)
        XCTAssertNil(manager.typeface(forTag: 12))

        manager.unregister(first)
        XCTAssertNil(manager.typeface(forTag: 11))
        XCTAssertEqual(manager.tag(of: first), 0)

        // The tag is free again.
        register(second.variationInstance(forCoordinates: [400.0, 100.0]) ?? second, tag: 11)
    }

    func testFamilies() throws {
        let fontFile = try XCTUnwrap(FontFile(path: TestFonts.path("Roboto-Variable.abc.ttf")))
        let typefaces = fontFile.typefaces
        XCTAssertGreaterThan(typefaces.count, 1)

        for typeface in typefaces {
            register(typeface, familyID: 7)
        }

        XCTAssertEqual(manager.familyID(of: typefaces[0]), 7)

        let families = manager.availableFamilies.filter { $0.familyID == 7 }
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families[0].typefaces.count, typefaces.count)

        let regular = manager.typeface(
            forFamilyID: 7,
            width: .normal,
            weight: .regular,
            slope: .plain
        )
        XCTAssertNotNil(regular)
        XCTAssertEqual(regular?.weight, .regular)

        let bold = manager.typeface(forFamilyID: 7, width: .normal, weight: .bold, slope: .plain)
        XCTAssertEqual(bold?.weight, .bold)

        // The typefaces with a family ID are still found by the name of their family.
        let byName = manager.typeface(
            forFamilyName: families[0].familyName.uppercased(),
            width: .normal,
            weight: .bold,
            slope: .plain
        )
        XCTAssertTrue(byName === bold)

        XCTAssertNil(manager.typeface(
            forFamilyID: 0,
            width: .normal,
            weight: .regular,
            slope: .plain
        ))
        XCTAssertNil(manager.typeface(
            forFamilyName: "No Such Family",
            width: .normal,
            weight: .regular,
            slope: .plain
        ))
    }

    func testAvailableTypefaces() throws {
        let typeface = try makeTypeface("Roboto-Regular.abc.ttf")
        register(typeface)

        XCTAssertTrue(manager.availableTypefaces.contains { $0 === typeface })
        XCTAssertTrue(manager.typeface(byName: typeface.fullName.uppercased()) === typeface)

        let family = manager.typeface(
            forFamilyName: typeface.familyName,
            width: .normal,
            weight: .regular,
            slope: .plain
        )
        XCTAssertNotNil(family)
    }
}
