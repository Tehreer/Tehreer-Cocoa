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

/// Tests of the typesetter, the lines and the frames that come from Core. In the test font, the
/// glyphs 'a', 'b' and 'c' are 1114, 1149 and 1072 units wide at a type size of 2048, and any other
/// character, such as the space, shows the missing glyph that is 908 units wide. The ascent is 1900
/// and the descent 500.
final class TypesetterTests: XCTestCase {
    private let typeface = FontFile(path: TestFonts.path("Roboto-Regular.abc.ttf"))!.typefaces[0]

    private func makeTypesetter(_ string: String, paragraphStyle: NSParagraphStyle? = nil) -> Typesetter {
        let text = NSMutableAttributedString(string: string)
        if let style = paragraphStyle {
            text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        }

        return Typesetter(text: text, defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(2048.0)])
    }

    private func makeResolver(_ typesetter: Typesetter, width: CGFloat, height: CGFloat = 100000.0) -> FrameResolver {
        let resolver = FrameResolver()
        resolver.typesetter = typesetter
        resolver.frameWidth = width
        resolver.frameHeight = height

        return resolver
    }

    func testSimpleLine() {
        let typesetter = makeTypesetter("abc")
        let line = typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3)

        XCTAssertEqual(line.codeUnitRange, 0 ..< 3)
        XCTAssertEqual(line.width, 3335.0)
        XCTAssertEqual(line.ascent, 1900.0)
        XCTAssertEqual(line.descent, 500.0)
        XCTAssertEqual(line.runs.count, 1)

        let run = line.runs[0]
        XCTAssertTrue(run.typeface === typeface)
        XCTAssertEqual(Array(run.glyphIDs), [1, 2, 3])
        XCTAssertEqual(Array(run.glyphAdvances), [1114.0, 1149.0, 1072.0])
        XCTAssertEqual(Array(run.clusterMap), [0, 1, 2])
        XCTAssertFalse(run.isBackward)
        XCTAssertEqual(run.scaleX, 1.0)
        XCTAssertEqual(run.scaleY, 1.0)
        XCTAssertEqual(run.distance(forCodeUnitAt: 2), 2263.0)
        XCTAssertEqual(run.indexOfCodeUnit(at: 1200.0), 1)
    }

    func testLineDistances() {
        let typesetter = makeTypesetter("abc")
        let line = typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3)

        XCTAssertEqual(line.distance(forCodeUnitAt: 1), 1114.0)
        XCTAssertEqual(line.indexOfCodeUnit(at: 1000.0), 1)
        XCTAssertEqual(line.visualEdges(forCodeUnitRange: 1 ..< 3), [1114.0, 3335.0])
        XCTAssertEqual(line.visualEdges(forCodeUnitRange: 1 ..< 1), [])
        XCTAssertEqual(line.penOffset(forFlushFactor: 1.0, flushExtent: 5000.0), 5000.0 - 3335.0)
    }

    func testBreaks() {
        let typesetter = makeTypesetter("abc abc")

        XCTAssertEqual(typesetter.suggestForwardBreak(inCodeUnitRange: 0 ..< 7, extent: 3500.0, breakMode: .line), 4)
        // A whitespace at the end of a line takes no room, so the space still goes in it.
        XCTAssertEqual(typesetter.suggestForwardBreak(inCodeUnitRange: 0 ..< 7, extent: 3500.0, breakMode: .character), 4)
        XCTAssertEqual(typesetter.suggestForwardBreak(inCodeUnitRange: 0 ..< 7, extent: 2000.0, breakMode: .character), 1)
        XCTAssertEqual(typesetter.suggestBackwardBreak(inCodeUnitRange: 0 ..< 7, extent: 3500.0, breakMode: .line), 4)
    }

    func testTruncatedLine() {
        let typesetter = makeTypesetter("abcabc")

        // The token is the three dots, as the font has no ellipsis.
        let end = typesetter.makeTruncatedLine(codeUnitRange: 0 ..< 6, extent: 6000.0,
                                               breakMode: .character, truncationPlace: .end,
                                               tokenString: nil)
        XCTAssertEqual(end.width, 1114.0 + 1149.0 + 3.0 * 908.0)

        let custom = typesetter.makeTruncatedLine(codeUnitRange: 0 ..< 6, extent: 3500.0,
                                                  breakMode: .character, truncationPlace: .end,
                                                  tokenString: "c")
        XCTAssertEqual(custom.width, 1114.0 + 1149.0 + 1072.0)
        // A truncated line covers the whole range, as the cut out text belongs to it.
        XCTAssertEqual(custom.codeUnitRange, 0 ..< 6)
    }

    func testJustifiedLine() {
        let typesetter = makeTypesetter("a b")
        let line = typesetter.makeJustifiedLine(codeUnitRange: 0 ..< 3, justificationFactor: 1.0,
                                                justificationExtent: 4000.0)

        XCTAssertEqual(line.width, 4000.0, accuracy: 0.01)
    }

    func testResolverPropertiesAreReadFromCore() {
        let resolver = FrameResolver()

        XCTAssertFalse(resolver.fitsHorizontally)
        XCTAssertFalse(resolver.fitsVertically)
        XCTAssertEqual(resolver.textAlignment, .leading)
        XCTAssertEqual(resolver.verticalAlignment, .top)
        XCTAssertEqual(resolver.truncationMode, .line)
        XCTAssertEqual(resolver.truncationPlace, .end)
        XCTAssertFalse(resolver.isTruncationEnabled)
        XCTAssertFalse(resolver.isJustificationEnabled)
        XCTAssertEqual(resolver.justificationLevel, 1.0)
        XCTAssertNil(resolver.maxLines)
        XCTAssertEqual(resolver.extraLineSpacing, 0.0)
        XCTAssertEqual(resolver.lineHeightMultiplier, 1.0)

        resolver.frameWidth = 100.0
        resolver.frameHeight = 50.0
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true
        resolver.textAlignment = .trailing
        resolver.verticalAlignment = .bottom
        resolver.truncationMode = .character
        resolver.truncationPlace = .middle
        resolver.isTruncationEnabled = true
        resolver.isJustificationEnabled = true
        resolver.justificationLevel = 0.5
        resolver.maxLines = 3
        resolver.extraLineSpacing = 2.0
        resolver.lineHeightMultiplier = 1.5

        XCTAssertEqual(resolver.frameWidth, 100.0)
        XCTAssertEqual(resolver.frameHeight, 50.0)
        XCTAssertTrue(resolver.fitsHorizontally)
        XCTAssertTrue(resolver.fitsVertically)
        XCTAssertEqual(resolver.textAlignment, .trailing)
        XCTAssertEqual(resolver.verticalAlignment, .bottom)
        XCTAssertEqual(resolver.truncationMode, .character)
        XCTAssertEqual(resolver.truncationPlace, .middle)
        XCTAssertTrue(resolver.isTruncationEnabled)
        XCTAssertTrue(resolver.isJustificationEnabled)
        XCTAssertEqual(resolver.justificationLevel, 0.5)
        XCTAssertEqual(resolver.maxLines, 3)
        XCTAssertEqual(resolver.extraLineSpacing, 2.0)
        XCTAssertEqual(resolver.lineHeightMultiplier, 1.5)

        resolver.maxLines = nil
        XCTAssertNil(resolver.maxLines)
    }

    func testFrameWrapsLines() throws {
        let typesetter = makeTypesetter("abc abc")
        let resolver = makeResolver(typesetter, width: 3500.0)
        let frame = try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< 7))

        XCTAssertEqual(frame.lines.count, 2)
        XCTAssertEqual(frame.lines[0].codeUnitRange, 0 ..< 4)
        XCTAssertEqual(frame.lines[1].codeUnitRange, 4 ..< 7)
        XCTAssertEqual(frame.lines[0].origin.y, 1900.0)
        XCTAssertEqual(frame.lines[1].origin.y, 2400.0 + 1900.0)
        XCTAssertEqual(frame.codeUnitRange, 0 ..< 7)

        XCTAssertEqual(frame.indexOfLine(forCodeUnitAt: 2), 0)
        XCTAssertEqual(frame.indexOfLine(forCodeUnitAt: 5), 1)
        // The end of the frame belongs to the last line.
        XCTAssertEqual(frame.indexOfLine(forCodeUnitAt: 7), 1)
        XCTAssertEqual(frame.indexOfLine(at: CGPoint(x: 10.0, y: 3000.0)), 1)
    }

    func testFrameAlignmentAndStyle() throws {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.firstLineHeadIndent = 100.0

        let typesetter = makeTypesetter("abc", paragraphStyle: style)
        let resolver = makeResolver(typesetter, width: 5000.0)
        let frame = try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< 3))

        // The line is flush right, within the width that is left after the indent.
        XCTAssertEqual(frame.lines[0].origin.x, 100.0 + (4900.0 - 3335.0), accuracy: 0.01)
    }

    func testFrameTruncation() throws {
        let typesetter = makeTypesetter("abc abc")
        let resolver = makeResolver(typesetter, width: 6000.0, height: 2400.0)
        resolver.truncationMode = .character
        resolver.truncationPlace = .end
        resolver.isTruncationEnabled = true

        let frame = try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< 7))
        XCTAssertEqual(frame.lines.count, 1)
        XCTAssertEqual(frame.codeUnitRange, 0 ..< 7)
        XCTAssertEqual(frame.lines[0].width, 1114.0 + 1149.0 + 3.0 * 908.0)
    }

    func testSelectionPath() throws {
        let typesetter = makeTypesetter("abc abc")
        let resolver = makeResolver(typesetter, width: 4300.0)
        let frame = try XCTUnwrap(resolver.makeFrame(codeUnitRange: 0 ..< 7))

        let single = frame.selectionPath(forCodeUnitRange: 1 ..< 2)
        XCTAssertEqual(single.boundingBox, CGRect(x: 1114.0, y: 0.0, width: 1149.0, height: 2400.0))

        // The selection over two lines has the padding of the first one too.
        let spanning = frame.selectionPath(forCodeUnitRange: 2 ..< 6)
        XCTAssertEqual(spanning.boundingBox.minX, 0.0)
        XCTAssertEqual(spanning.boundingBox.maxX, 4300.0)
        XCTAssertEqual(spanning.boundingBox.height, 4800.0)

        XCTAssertTrue(frame.selectionPath(forCodeUnitRange: 2 ..< 2).isEmpty)
    }

    func testReplacementsAreLaidOut() throws {
        final class Box: TextReplacement {
            var ascent: CGFloat { 3000.0 }
            var descent: CGFloat { 100.0 }
            var leading: CGFloat { 0.0 }
            var width: CGFloat { 700.0 }
            func draw(in context: CGContext) { }
        }

        let box = Box()
        let text = NSMutableAttributedString(string: "a\u{FFFC}b")
        text.addAttribute(.replacement, value: box, range: NSRange(location: 1, length: 1))

        let typesetter = Typesetter(text: text, defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(2048.0)])
        let line = typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3)

        XCTAssertEqual(line.width, 1114.0 + 700.0 + 1149.0)
        XCTAssertEqual(line.ascent, 3000.0)
        XCTAssertEqual(line.runs.count, 3)
        XCTAssertTrue(line.runs[1].replacement === box)
        XCTAssertNil(line.runs[0].replacement)
    }

    func testForegroundColorSplitsRuns() throws {
        let text = NSMutableAttributedString(string: "abc")
        text.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 1, length: 1))

        let typesetter = Typesetter(text: text, defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(2048.0)])
        let line = typesetter.makeSimpleLine(codeUnitRange: 0 ..< 3)

        XCTAssertEqual(line.runs.map { $0.codeUnitRange }, [0 ..< 1, 1 ..< 2, 2 ..< 3])
    }

    func testLinesOutliveTheTypesetter() throws {
        var typesetter: Typesetter? = makeTypesetter("abc")
        let line = typesetter!.makeSimpleLine(codeUnitRange: 0 ..< 3)
        typesetter = nil

        XCTAssertEqual(line.width, 3335.0)
        XCTAssertTrue(line.runs[0].typeface === typeface)
    }

    /// Draws the two lines that a cluster is split between, which makes each run hold only a part
    /// of the cluster. The edge clusters are positioned outside of the run, so this used to trap.
    private func drawSplitCluster(_ string: String, splitAt split: Int, length: Int) throws {
        let text = NSAttributedString(string: string)
        let typesetter = Typesetter(text: text, defaultAttributes: [.typeface: typeface, .typeSize: CGFloat(40.0)])
        let lines = [typesetter.makeSimpleLine(codeUnitRange: 0 ..< split),
                     typesetter.makeSimpleLine(codeUnitRange: split ..< length)]

        let run = try XCTUnwrap(lines[0].runs.first)
        XCTAssertTrue(run.startExtraLength > 0 || run.endExtraLength > 0)

        let renderer = Renderer()
        var pixels = [UInt8](repeating: 0xFF, count: 200 * 100 * 4)

        try pixels.withUnsafeMutableBytes { (bytes) in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 200, height: 100,
                                                  bitsPerComponent: 8, bytesPerRow: 200 * 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            for line in lines {
                context.saveGState()
                context.translateBy(x: 20.0, y: 50.0)
                line.draw(with: renderer, in: context)
                context.restoreGState()
            }
        }
    }

    func testDrawsSplitClusterInLeftToRightRun() throws {
        // The combining mark is in the cluster of its base, and the lines cut it off.
        try drawSplitCluster("a\u{0301}b", splitAt: 1, length: 3)
    }

    func testDrawsSplitClusterInRightToLeftRun() throws {
        try drawSplitCluster("\u{05D0}\u{0301}\u{05D1}", splitAt: 1, length: 3)
    }
}
