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

import UIKit
import XCTest
@testable import TehreerCocoa

private class Box: TextReplacement {
    var ascent: CGFloat { 20.0 }
    var descent: CGFloat { 0.0 }
    var leading: CGFloat { 0.0 }
    var width: CGFloat { 30.0 }

    func draw(in context: CGContext) {}
}

private class RecordingDelegate: TTextViewDelegate {
    var urls: [URL] = []

    func textView(_ textView: TTextView, shouldInteractWith url: URL, in codeUnitRange: Range<Int>) -> Bool {
        urls.append(url)
        return false
    }
}

final class TTextViewTests: TTextViewTestCase {
    // MARK: - Positions

    func testIndexOfCodeUnitFindsTheNearestLineAboveAndBelowTheText() {
        textView.contentInset = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 60.0, right: 0.0)
        show(urduText(20))

        let first = lines.first!
        let last = lines.last!

        let above = textView.indexOfCodeUnit(at: CGPoint(x: center(of: first).x, y: first.top - 50.0))
        XCTAssertNotNil(above)
        XCTAssertTrue(first.codeUnitRange.contains(above!))

        let below = textView.indexOfCodeUnit(at: CGPoint(x: center(of: last).x, y: last.bottom + 50.0))
        XCTAssertNotNil(below)
        XCTAssertTrue(last.codeUnitRange.contains(below!))
    }

    func testIndexOfCodeUnitIsNilBesideTheTextOfALine() {
        show(urduText(20) + "\nابجد")

        let last = lines.last!
        XCTAssertTrue(last.width < textView.bounds.width - 40.0)

        let y = center(of: last).y
        let leftGap = CGPoint(x: last.left > 20.0 ? 2.0 : last.right + 5.0, y: y)

        XCTAssertNil(textView.indexOfCodeUnit(at: leftGap))
        XCTAssertNotNil(textView.indexOfCodeUnit(at: center(of: last)))
    }

    func testIndexOfCodeUnitUnderPositionIsNilOutsideTheLines() {
        textView.contentInset = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        show(urduText(20))

        let first = lines.first!
        let middle = center(of: first)

        XCTAssertNotNil(textView.container.indexOfCodeUnitUnderPosition(middle))
        XCTAssertNil(textView.container.indexOfCodeUnitUnderPosition(CGPoint(x: middle.x, y: first.top - 20.0)))
    }

    func testIndexOfCodeUnitWithoutTextIsNil() {
        XCTAssertNil(textView.indexOfCodeUnit(at: CGPoint(x: 10.0, y: 10.0)))
        XCTAssertNil(textView.firstVisibleCodeUnitIndex)
    }

    // MARK: - Geometry

    func testSelectionRectsOfARangeWithinALineIsOneRectInsideTheLine() {
        show(urduText(20))

        let line = lines[1]
        let range = line.codeUnitRange.lowerBound + 2 ..< line.codeUnitRange.lowerBound + 8
        let rects = textView.selectionRects(forCodeUnitRange: range)

        XCTAssertEqual(rects.count, 1)
        XCTAssertEqual(rects[0].minY, line.top, accuracy: 0.5)
        XCTAssertEqual(rects[0].height, line.height, accuracy: 0.5)
        XCTAssertTrue(rects[0].minX >= line.left - 0.5 && rects[0].maxX <= line.right + 0.5)
    }

    func testSelectionRectsOfARangeOverLinesHasOneRectForEachLine() {
        show(urduText(20))

        let range = lines[1].codeUnitRange.lowerBound + 3 ..< lines[3].codeUnitRange.lowerBound + 3
        let rects = textView.selectionRects(forCodeUnitRange: range)

        XCTAssertEqual(rects.count, 3)

        // The lines in between are covered entirely.
        XCTAssertEqual(rects[1].minX, 0.0, accuracy: 0.5)
        XCTAssertEqual(rects[1].maxX, textView.textFrame!.width, accuracy: 0.5)
    }

    func testSelectionRectsOutsideTheFrameAreEmpty() {
        show("abc")

        XCTAssertTrue(textView.selectionRects(forCodeUnitRange: 100 ..< 120).isEmpty)
    }

    func testRectsForAReplacementAreTheBoxItDrawsIn() {
        let box = Box()
        let text = NSMutableAttributedString(string: "ab \u{FFFC} cd")
        text.addAttribute(.replacement, value: box, range: NSRange(location: 3, length: 1))

        textView.attributedText = text
        awaitFrame()

        let rects = textView.rects(for: box)

        XCTAssertEqual(rects.count, 1)
        XCTAssertEqual(rects[0].width, 30.0, accuracy: 0.5)
        XCTAssertEqual(textView.boundingRect(for: box), rects[0])
        XCTAssertNil(textView.boundingRect(for: Box()))
    }

    // MARK: - Scroll position

    func testANewTextStartsAtTheTop() {
        show(urduText(60))

        textView.setContentOffset(CGPoint(x: 0.0, y: 800.0), animated: false)
        spin()

        textView.text = urduText(61)
        wait("the new text") { textView.contentOffset.y == 0.0 && textView.textFrame != nil && !lines.isEmpty }

        XCTAssertEqual(textView.contentOffset.y, 0.0, accuracy: 0.5)
        XCTAssertEqual(textView.firstVisibleCodeUnitIndex, 0)
    }

    func testScrollToCodeUnitPutsItsLineAtTheTop() {
        show(urduText(60))

        let target = lines[20]
        textView.scrollToCodeUnit(at: target.codeUnitRange.lowerBound + 3, animated: false)
        textView.layoutIfNeeded()

        XCTAssertEqual(textView.contentOffset.y, target.top, accuracy: 0.5)
        XCTAssertEqual(textView.firstVisibleCodeUnitIndex, target.codeUnitRange.lowerBound)
    }

    func testScrollingToTheFirstVisibleIndexStaysWhereItIs() {
        show(urduText(60))

        textView.setContentOffset(CGPoint(x: 0.0, y: 777.0), animated: false)
        textView.layoutIfNeeded()

        let first = textView.firstVisibleCodeUnitIndex!
        let before = textView.contentOffset.y

        textView.scrollToCodeUnit(at: first, animated: false)
        textView.layoutIfNeeded()

        XCTAssertEqual(textView.firstVisibleCodeUnitIndex, first)
        XCTAssertLessThanOrEqual(textView.contentOffset.y, before + 0.5)
    }

    func testScrollRequestedBeforeTheTextIsFramedIsDoneWhenItIs() {
        textView.text = urduText(60)
        textView.scrollToCodeUnit(at: 1200, animated: false)

        awaitFrame()
        wait("the scroll") { textView.contentOffset.y > 0.0 }

        let first = textView.firstVisibleCodeUnitIndex!
        let line = lines.first { $0.codeUnitRange.contains(1200) }!

        XCTAssertEqual(first, line.codeUnitRange.lowerBound)
    }

    func testReframingKeepsWhatIsOnTheScreen() {
        show(urduText(60))

        textView.scrollToCodeUnit(at: lines[30].codeUnitRange.lowerBound, animated: false)
        textView.layoutIfNeeded()
        let before = textView.firstVisibleCodeUnitIndex!

        let oldFrame = textView.textFrame!
        textView.textSize = 28.0

        wait("the reframe") { textView.textFrame != nil && textView.textFrame !== oldFrame }
        spin(0.2)
        textView.layoutIfNeeded()

        let after = textView.firstVisibleCodeUnitIndex!
        let line = lines.first { $0.codeUnitRange.contains(before) }!

        XCTAssertTrue(
            abs(line.codeUnitRange.lowerBound - after) <= line.codeUnitRange.count,
            "\(before) was on the screen, \(after) is now"
        )
        XCTAssertGreaterThan(textView.contentOffset.y, 0.0)
    }

    func testTheOldLinesStayWhileTheNewFrameIsBeingMade() {
        show(urduText(60))

        let oldViews = textView.container.subviews.compactMap { $0 as? LineView }
        XCTAssertFalse(oldViews.isEmpty)

        textView.extraLineSpacing = 4.0

        // Nothing is torn down by the request itself.
        XCTAssertTrue(textView.container.subviews.contains { $0 is LineView })
        XCTAssertNotNil(textView.container.displayedFrame)
    }

    // MARK: - Culling

    func testOnlyTheLinesNearTheScreenHaveViews() {
        show(urduText(200))

        let lineCount = lines.count
        XCTAssertGreaterThan(lineCount, 200)

        for offset in [0.0, 500.0, 2000.0, textView.contentSize.height - 480.0] {
            textView.setContentOffset(CGPoint(x: 0.0, y: offset), animated: false)
            textView.layoutIfNeeded()

            let visible = textView.container.subviews.compactMap { $0 as? LineView }.filter { $0.frame.intersects(textView.container.visibleRect) }
            let expected = lines.filter { $0.bottom > offset && $0.top < offset + 480.0 }

            XCTAssertGreaterThanOrEqual(visible.count, expected.count - 1, "at \(offset)")
            XCTAssertLessThan(textView.container.subviews.count, 60)
        }
    }

    // MARK: - Links

    func testALinkIsFoundUnderItsTextAndNotBesideIt() {
        let text = NSMutableAttributedString(string: urduText(2))
        let url = URL(string: "https://example.com")!
        let range = NSRange(location: 5, length: 12)
        text.addAttribute(.link, value: url, range: range)

        textView.attributedText = text
        awaitFrame()

        let rect = textView.selectionRects(forCodeUnitRange: 5 ..< 17).first!
        let target = textView.container.interactionTarget(at: CGPoint(x: rect.midX, y: rect.midY))

        guard case .link(let found, let foundRange)? = target else {
            return XCTFail("There is no link at \(rect)")
        }

        XCTAssertEqual(found, url)
        XCTAssertEqual(foundRange, 5 ..< 17)

        // Away from the link, and in the gap of a short line.
        XCTAssertNil(textView.container.interactionTarget(at: CGPoint(x: textView.bounds.width - 1.0, y: -50.0)))
        XCTAssertNil(textView.container.interactionTarget(at: CGPoint(x: rect.midX, y: rect.maxY + 200.0)))
    }

    func testALinkIsFoundOnTheTrailingHalfOfItsLastCharacter() {
        let text = NSMutableAttributedString(string: urduText(2))
        text.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 5, length: 12))

        textView.attributedText = text
        awaitFrame()

        let last = textView.selectionRects(forCodeUnitRange: 16 ..< 17).first!
        let first = textView.selectionRects(forCodeUnitRange: 5 ..< 6).first!

        for rect in [last, first] {
            for fraction in [CGFloat(0.1), 0.5, 0.9] {
                let point = CGPoint(x: rect.minX + rect.width * fraction, y: rect.midY)

                guard case .link? = textView.container.interactionTarget(at: point) else {
                    return XCTFail("There is no link at \(point) in \(rect)")
                }
            }
        }
    }

    func testLinksAreInertWhenLinkInteractionIsTurnedOff() {
        let text = NSMutableAttributedString(string: urduText(2))
        text.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 5, length: 12))

        textView.attributedText = text
        awaitFrame()

        let rect = textView.selectionRects(forCodeUnitRange: 5 ..< 17).first!
        let point = CGPoint(x: rect.midX, y: rect.midY)

        XCTAssertNotNil(textView.container.interactionTarget(at: point))

        textView.isLinkInteractionEnabled = false
        XCTAssertNil(textView.container.interactionTarget(at: point))
    }

    func testAReplacementIsAnInteractionTargetAndOverridesALink() {
        let box = Box()
        let text = NSMutableAttributedString(string: "ab \u{FFFC} cd")
        text.addAttribute(.replacement, value: box, range: NSRange(location: 3, length: 1))
        text.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 0, length: text.length))

        textView.attributedText = text
        awaitFrame()

        let rect = textView.rects(for: box).first!

        guard case .replacement(let found, _)? = textView.container.interactionTarget(at: CGPoint(x: rect.midX, y: rect.midY)) else {
            return XCTFail("The replacement is not a target")
        }

        XCTAssertTrue(found === box)
    }

    func testPressingALinkHighlightsItAndClearingRemovesIt() {
        let text = NSMutableAttributedString(string: urduText(2))
        text.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 5, length: 12))

        textView.attributedText = text
        awaitFrame()

        let target = InteractionTarget.link(URL(string: "https://example.com")!, 5 ..< 17)

        textView.container.highlight(target)
        XCTAssertNotNil(textView.container.highlightView.path)
        XCTAssertFalse(textView.container.highlightView.path!.isEmpty)

        textView.container.clearHighlight()
        XCTAssertNil(textView.container.highlightView.path)
    }
}
