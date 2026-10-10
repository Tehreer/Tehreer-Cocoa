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

/// Tests of the drawing of runs, lines and frames, which is done by Core through the callbacks of
/// the renderer. In the test font, the glyphs 'a', 'b' and 'c' are 1114, 1149 and 1072 units wide
/// at a type size of 2048.
final class DrawTests: XCTestCase {
    private let typeface = FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf"))!.typefaces[0]

    private func makeTypesetter(_ attributes: [NSAttributedString.Key: Any] = [:]) -> Typesetter {
        let text = NSAttributedString(string: "abc", attributes: attributes)

        return Typesetter(
            text: text,
            defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(100.0)]
        )
    }

    private func makeRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.typeface = typeface
        renderer.typeSize = 100.0

        return renderer
    }

    /// Draws on a white bitmap with its y axis pointing downward and returns its RGBA pixels.
    private func draw(width: Int = 200, height: Int = 200, body: (CGContext) -> Void) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0xFF, count: width * height * 4)

        try pixels.withUnsafeMutableBytes { (bytes) in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))

            context.translateBy(x: 0.0, y: CGFloat(height))
            context.scaleBy(x: 1.0, y: -1.0)

            body(context)
        }

        return pixels
    }

    private func pixel(_ pixels: [UInt8], x: Int, y: Int, width: Int = 200) -> (r: UInt8, g: UInt8, b: UInt8) {
        let index = (y * width + x) * 4

        return (pixels[index], pixels[index + 1], pixels[index + 2])
    }

    private func inkCount(_ pixels: [UInt8]) -> Int {
        return stride(from: 0, to: pixels.count, by: 4).filter {
            pixels[$0] != 0xFF || pixels[$0 + 1] != 0xFF || pixels[$0 + 2] != 0xFF
        }.count
    }

    func testRunAttributes() {
        let typesetter = makeTypesetter([.backgroundColor: UIColor.red,
                                         .underlineStyle: 1,
                                         .strikethroughStyle: 1,
                                         .underlineColor: UIColor.blue,
                                         .foregroundColor: UIColor.green])
        let run = typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3).visualRuns[0]

        XCTAssertEqual(run.backgroundColor, UIColor.red)
        XCTAssertTrue(run.hasUnderline)
        XCTAssertTrue(run.hasStrikethrough)
        XCTAssertEqual(run.decorationColor, UIColor.blue)
        XCTAssertEqual(run.foregroundColor, UIColor.green)

        let plain = makeTypesetter().makeSimpleLine(codeUnitRange: 0 ..< 3).visualRuns[0]
        XCTAssertNil(plain.backgroundColor)
        XCTAssertFalse(plain.hasUnderline)
        XCTAssertFalse(plain.hasStrikethrough)
        XCTAssertNil(plain.decorationColor)
        XCTAssertNil(plain.foregroundColor)
    }

    func testLineBackground() throws {
        let line = makeTypesetter([.backgroundColor: UIColor.red])
            .makeSimpleLine(codeUnitRange: 0 ..< 3)
        let renderer = makeRenderer()

        let pixels = try draw { (context) in
            context.translateBy(x: 10.0, y: line.ascent + 10.0)
            line.draw(with: renderer, in: context)
        }

        // A point at the far right of the line is not covered by a glyph, so it is background.
        let background = pixel(pixels, x: 10 + Int(line.width) - 2, y: 10 + Int(line.height / 2))
        XCTAssertEqual(background.r, 0xFF)
        XCTAssertEqual(background.g, 0x00)
        XCTAssertEqual(background.b, 0x00)

        // Nothing is drawn outside of the line.
        XCTAssertEqual(pixel(pixels, x: 2, y: 2).g, 0xFF)
    }

    func testDecorationsAndInkBox() throws {
        let renderer = makeRenderer()
        let plain = makeTypesetter().makeSimpleLine(codeUnitRange: 0 ..< 3)
        let underlined = makeTypesetter([.underlineStyle: 1]).makeSimpleLine(codeUnitRange: 0 ..< 3)

        let first = try draw { (context) in
            context.translateBy(x: 10.0, y: plain.ascent + 10.0)
            plain.draw(with: renderer, in: context)
        }
        let second = try draw { (context) in
            context.translateBy(x: 10.0, y: underlined.ascent + 10.0)
            underlined.draw(with: renderer, in: context)
        }

        XCTAssertGreaterThan(inkCount(first), 0)
        XCTAssertGreaterThan(inkCount(second), inkCount(first))

        let box = plain.computeInkBox(with: renderer)
        XCTAssertFalse(box.isNull)
        XCTAssertGreaterThan(box.width, 0.0)
        XCTAssertEqual(
            plain.visualRuns[0].computeInkBox(with: renderer).width,
            box.width,
            accuracy: 1.0
        )
    }

    func testFrameDraw() throws {
        let resolver = FrameResolver()
        resolver.typesetter = makeTypesetter()
        resolver.frameBounds = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 1000.0)

        let frame = try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< 3))
        XCTAssertGreaterThan(frame.lines.count, 1)

        let renderer = makeRenderer()
        let pixels = try draw { (context) in
            frame.draw(with: renderer, in: context, at: CGPoint(x: 10.0, y: 10.0))
        }

        XCTAssertGreaterThan(inkCount(pixels), 0)
    }

    func testStrokeStyle() throws {
        let line = makeTypesetter().makeSimpleLine(codeUnitRange: 0 ..< 3)
        let renderer = makeRenderer()
        renderer.strokeColor = .blue
        renderer.drawStyle = .stroke

        let pixels = try draw { (context) in
            context.translateBy(x: 10.0, y: line.ascent + 10.0)
            line.draw(with: renderer, in: context)
        }

        // The outlines are blue, and the insides of the glyphs are left empty.
        XCTAssertTrue(stride(from: 0, to: pixels.count, by: 4).contains {
            pixels[$0] < 0x40 && pixels[$0 + 1] < 0x40 && pixels[$0 + 2] > 0xC0
        })
    }

    func testFontFeaturesAndLanguage() {
        let features: [SFNTTag: Int] = ["liga": 0]
        let text = NSAttributedString(
            string: "abc",
            attributes: [.fontFeatures: features,
                                                                                                                                                                                                                                                                          .language: "ur-PK"]
        )
        let typesetter = Typesetter(
            text: text,
            defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(100.0)]
        )

        XCTAssertEqual(typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3).visualRuns.count, 1)
        XCTAssertEqual(ShapingEngine.languageTag(forName: "ur-PK"), "URD ")
        XCTAssertEqual(ShapingEngine.languageTag(forName: ""), "dflt")
    }

    func testFrameLine() {
        let typesetter = makeTypesetter()
        let line = typesetter.makeFrameLine(codeUnitRange: 0 ..< 3, layoutWidth: 500.0)

        XCTAssertEqual(line.codeUnitRange, 0 ..< 3)
        XCTAssertEqual(typesetter.codeUnitCount, 3)
        XCTAssertFalse(line.isTruncated)
    }

    func testGlyphCache() {
        let cache = GlyphCache(capacity: 1024 * 1024)
        XCTAssertEqual(cache?.capacity, 1024 * 1024)

        let renderer = makeRenderer()
        renderer.glyphCache = cache!
        _ = renderer.makeGlyphLayer(glyphID: 1)
        XCTAssertGreaterThan(cache!.size, 0)

        cache!.clear()
        XCTAssertEqual(cache!.size, 0)
        XCTAssertEqual(GlyphCache.default.capacity, 8 * 1024 * 1024)
    }
}
