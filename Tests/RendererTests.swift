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

/// Tests of the renderer. In the test font, the glyphs 'a', 'b' and 'c' are 1114, 1149 and 1072
/// units wide, and have the ids 1, 2 and 3.
final class RendererTests: XCTestCase {
    private func makeRenderer(fontName: String = "Roboto-Regular.abc.ttf") throws -> Renderer {
        let fontFile = try XCTUnwrap(FontFile(path: TestFonts.path(fontName)))

        let renderer = Renderer()
        renderer.typeface = fontFile.typefaces[0]
        renderer.typeSize = 100.0

        return renderer
    }

    /// Draws with a closure on a white bitmap of the given size, which has its y axis pointing
    /// downward as it does in UIKit, and returns the pixels as RGBA.
    private func draw(width: Int, height: Int, scale: CGFloat = 1.0, body: (CGContext) -> Void) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0xFF, count: width * height * 4)

        try pixels.withUnsafeMutableBytes { (bytes) in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress,
                                                  width: width,
                                                  height: height,
                                                  bitsPerComponent: 8,
                                                  bytesPerRow: width * 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))

            context.translateBy(x: 0.0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)

            body(context)
        }

        return pixels
    }

    private func inkedColumns(_ pixels: [UInt8], width: Int) -> Range<Int>? {
        var first: Int?
        var last: Int?

        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] != 0xFF || pixels[index + 1] != 0xFF || pixels[index + 2] != 0xFF {
                let column = (index / 4) % width
                first = min(first ?? column, column)
                last = max(last ?? column, column)
            }
        }

        if let first = first, let last = last {
            return first ..< (last + 1)
        }

        return nil
    }

    func testGlyphPath() throws {
        let renderer = try makeRenderer()
        let path = try XCTUnwrap(renderer.makePath(glyphID: 1))
        let box = path.boundingBox

        // The path is in pixels, and points downward from the baseline.
        XCTAssertFalse(box.isEmpty)
        XCTAssertLessThan(box.minY, 0.0)
        XCTAssertLessThan(box.maxY, 5.0)
        XCTAssertLessThan(box.width, 100.0)

        // A glyph without a typeface has no path.
        XCTAssertNil(Renderer().makePath(glyphID: 1))
    }

    func testRunPath() throws {
        let renderer = try makeRenderer()
        let ids: [GlyphID] = [1, 2]
        let offsets = [CGPoint.zero, CGPoint.zero]
        let advances: [CGFloat] = [50.0, 50.0]

        let path = try XCTUnwrap(renderer.makePath(glyphIDs: ids, offsets: offsets, advances: advances))
        let single = try XCTUnwrap(renderer.makePath(glyphID: 2))

        // The second glyph is moved by the advance of the first one.
        XCTAssertEqual(path.boundingBox.maxX, single.boundingBox.maxX + 50.0, accuracy: 1.0)
        XCTAssertEqual(path.boundingBox.minY, single.boundingBox.minY, accuracy: 1.0)
    }

    func testBoundingBoxes() throws {
        let renderer = try makeRenderer()

        let glyphBox = renderer.computeInkBox(forGlyph: 1)
        XCTAssertFalse(glyphBox.isEmpty)
        XCTAssertLessThan(glyphBox.minY, 0.0)

        let runBox = renderer.computeInkBox(
            forGlyphs: [1, 2] as [GlyphID],
            offsets: [CGPoint.zero, CGPoint.zero],
            advances: [50.0, 50.0] as [CGFloat]
        )
        XCTAssertGreaterThan(runBox.width, glyphBox.width)

        let empty = renderer.computeInkBox(
            forGlyphs: [] as [GlyphID],
            offsets: [] as [CGPoint],
            advances: [] as [CGFloat]
        )
        XCTAssertTrue(empty.isNull)
    }

    func testDrawingFillsPixels() throws {
        let renderer = try makeRenderer()

        let pixels = try draw(width: 200, height: 200) { (context) in
            context.translateBy(x: 50.0, y: 150.0)
            renderer.drawGlyphs(in: context, glyphIDs: [1] as [GlyphID],
                                offsets: [CGPoint.zero], advances: [50.0] as [CGFloat])
        }

        let columns = try XCTUnwrap(inkedColumns(pixels, width: 200))
        XCTAssertGreaterThanOrEqual(columns.lowerBound, 45)
        XCTAssertLessThan(columns.upperBound, 110)
    }

    func testFillColor() throws {
        let renderer = try makeRenderer()
        renderer.fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)

        let pixels = try draw(width: 200, height: 200) { (context) in
            context.translateBy(x: 50.0, y: 150.0)
            renderer.drawGlyphs(in: context, glyphIDs: [1] as [GlyphID],
                                offsets: [CGPoint.zero], advances: [50.0] as [CGFloat])
        }

        // Where the glyph is solid, it is red.
        var hasRed = false
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] == 0xFF && pixels[index + 1] == 0x00 && pixels[index + 2] == 0x00 {
                hasRed = true
            }
        }

        XCTAssertTrue(hasRed)
    }

    func testRightToLeftRunsGoLeftOfTheOrigin() throws {
        let renderer = try makeRenderer()
        renderer.writingDirection = .rightToLeft

        let pixels = try draw(width: 300, height: 200) { (context) in
            context.translateBy(x: 200.0, y: 150.0)
            renderer.drawGlyphs(in: context, glyphIDs: [1, 2] as [GlyphID],
                                offsets: [CGPoint.zero, CGPoint.zero],
                                advances: [50.0, 50.0] as [CGFloat])
        }

        let columns = try XCTUnwrap(inkedColumns(pixels, width: 300))
        XCTAssertLessThanOrEqual(columns.upperBound, 205)
        XCTAssertGreaterThanOrEqual(columns.lowerBound, 95)
    }

    func testStrokeStyles() throws {
        let renderer = try makeRenderer()
        renderer.strokeRadius = 2.0

        func render(_ style: Renderer.DrawStyle) throws -> [UInt8] {
            renderer.drawStyle = style

            return try draw(width: 200, height: 200) { (context) in
                context.translateBy(x: 50.0, y: 150.0)
                renderer.drawGlyphs(in: context, glyphIDs: [1] as [GlyphID],
                                    offsets: [CGPoint.zero], advances: [50.0] as [CGFloat])
            }
        }

        let fill = try render(.fill)
        let stroke = try render(.stroke)
        let both = try render(.fillStroke)

        XCTAssertNotEqual(fill, stroke)
        XCTAssertNotEqual(fill, both)

        // A stroke has the outline only, so it has fewer pixels than the fill together with it.
        let strokeColumns = try XCTUnwrap(inkedColumns(stroke, width: 200))
        let bothColumns = try XCTUnwrap(inkedColumns(both, width: 200))
        XCTAssertGreaterThanOrEqual(strokeColumns.count, 1)
        XCTAssertGreaterThanOrEqual(bothColumns.count, strokeColumns.count - 1)
    }

    func testRenderScale() throws {
        let renderer = try makeRenderer()
        renderer.renderScale = 2.0

        // The context is scaled by the render scale as well, so the glyph keeps its size.
        let pixels = try draw(width: 400, height: 400, scale: 2.0) { (context) in
            context.translateBy(x: 50.0, y: 150.0)
            renderer.drawGlyphs(in: context, glyphIDs: [1] as [GlyphID],
                                offsets: [CGPoint.zero], advances: [50.0] as [CGFloat])
        }

        let columns = try XCTUnwrap(inkedColumns(pixels, width: 400))
        XCTAssertGreaterThanOrEqual(columns.lowerBound, 90)
        XCTAssertLessThan(columns.upperBound, 220)
    }

    func testTinyGlyphsAreNotDrawn() throws {
        let renderer = try makeRenderer()
        renderer.typeSize = 0.0

        let pixels = try draw(width: 100, height: 100) { (context) in
            context.translateBy(x: 20.0, y: 50.0)
            renderer.drawGlyphs(in: context, glyphIDs: [1] as [GlyphID],
                                offsets: [CGPoint.zero], advances: [50.0] as [CGFloat])
        }

        XCTAssertNil(inkedColumns(pixels, width: 100))
    }

    func testColorFontDrawsInColor() throws {
        let renderer = try makeRenderer(fontName: "COLRv0.extents.ttf")
        renderer.typeSize = 100.0

        let pixels = try draw(width: 300, height: 300) { (context) in
            context.translateBy(x: 20.0, y: 200.0)
            renderer.drawGlyphs(in: context, glyphIDs: [13] as [GlyphID],
                                offsets: [CGPoint.zero], advances: [100.0] as [CGFloat])
        }

        XCTAssertNotNil(inkedColumns(pixels, width: 300))
    }

    func testDrawingFromThreads() throws {
        let renderer = try makeRenderer()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "renderer", attributes: .concurrent)
        let inked = NSLock()
        var failures = 0

        for _ in 0 ..< 8 {
            let local = Renderer()
            local.typeface = renderer.typeface
            local.typeSize = 40.0

            queue.async(group: group) {
                for _ in 0 ..< 50 {
                    let box = local.computeInkBox(
                        forGlyphs: [1, 2, 3] as [GlyphID],
                        offsets: [CGPoint](repeating: .zero, count: 3),
                        advances: [CGFloat](repeating: 20.0, count: 3)
                    )
                    if box.isNull || box.isEmpty {
                        inked.lock()
                        failures += 1
                        inked.unlock()
                    }
                }
            }
        }

        group.wait()
        XCTAssertEqual(failures, 0)
    }
}
