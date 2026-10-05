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

/// A block view with a fixed height.
private final class FixedBlock: ViewAttachment, @unchecked Sendable {
    let fixedHeight: CGFloat
    private(set) var loadCount = 0

    init(height: CGFloat) {
        self.fixedHeight = height
        super.init()
    }

    override var height: CGFloat { fixedHeight }
    override var margins: UIEdgeInsets { UIEdgeInsets(top: 4.0, left: 0.0, bottom: 6.0, right: 0.0) }

    override func loadView() -> UIView {
        loadCount += 1

        let view = UIView()
        view.backgroundColor = .green
        return view
    }
}

/// A block view whose height is whatever its content asks for.
private final class WrappingBlock: ViewAttachment, @unchecked Sendable {
    var contentHeight: CGFloat
    var hides = true

    init(contentHeight: CGFloat) {
        self.contentHeight = contentHeight
        super.init()
    }

    override var hidesWhileResizing: Bool { hides }

    override func loadView() -> UIView {
        return UIView()
    }

    override func measure(forLayoutWidth layoutWidth: CGFloat, view: UIView) -> CGSize {
        return CGSize(width: layoutWidth, height: contentHeight)
    }
}

/// An inline view.
private final class InlineBox: ViewAttachment, @unchecked Sendable {
    override var placement: Placement { .inline }
    override var width: CGFloat { 40.0 }
    override var height: CGFloat { 50.0 }
    override var baselineOffset: CGFloat { 10.0 }

    override func loadView() -> UIView {
        return UIView()
    }
}

final class TTextViewAttachmentTests: TTextViewTestCase {
    private func text(with attachment: ViewAttachment, before: Int = 6, after: Int = 6) -> NSAttributedString {
        let result = NSMutableAttributedString(string: urduText(before) + "\n")

        let marker = NSMutableAttributedString(string: "\u{FFFC}")
        marker.addAttribute(.replacement, value: attachment, range: NSRange(location: 0, length: 1))
        result.append(marker)

        result.append(NSAttributedString(string: "\n" + urduText(after)))

        return result
    }

    private func line(of attachment: ViewAttachment) -> ComposedLine? {
        return lines.first { line in
            line.visualRuns.contains { ($0.textRun as? ReplacementRun)?.replacement === attachment }
        }
    }

    // MARK: - Block

    func testABlockViewHasALineOfItsOwnAsTallAsTheViewAndItsMargins() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let blockLine = line(of: block)!

        XCTAssertTrue(blockLine.isBlock)
        XCTAssertEqual(blockLine.height, 120.0 + 4.0 + 6.0, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(blockLine.width, textView.textFrame!.width - 0.5)

        // Only the view, and its newline, are on the line.
        let string = textView.textFrame!.string as NSString
        let text = string.substring(with: NSRange(location: blockLine.codeUnitRange.lowerBound, length: blockLine.codeUnitRange.count))
        XCTAssertTrue(text.hasPrefix("\u{FFFC}"))
        XCTAssertLessThanOrEqual(text.trimmingCharacters(in: .whitespacesAndNewlines).count, 1)
    }

    func testTheViewOfABlockIsAsWideAsTheTextWithoutItsMargins() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let blockLine = line(of: block)!
        let view = block.view
        XCTAssertNotNil(view)

        XCTAssertEqual(view!.frame.width, textView.textFrame!.width, accuracy: 0.5)
        XCTAssertEqual(view!.frame.height, 120.0, accuracy: 0.5)
        XCTAssertEqual(view!.frame.minY, blockLine.top + 4.0, accuracy: 0.5)
        XCTAssertTrue(view!.superview === textView.container)
    }

    func testABlockIsOnItsOwnLineEvenWhenItWouldFitTheLineBefore() {
        let block = FixedBlock(height: 20.0)

        let result = NSMutableAttributedString(string: "ab ")
        let marker = NSMutableAttributedString(string: "\u{FFFC}")
        marker.addAttribute(.replacement, value: block, range: NSRange(location: 0, length: 1))
        result.append(marker)
        result.append(NSAttributedString(string: " cd"))

        textView.attributedText = result
        awaitFrame()

        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].isBlock)
        XCTAssertFalse(lines[0].isBlock)
        XCTAssertFalse(lines[2].isBlock)
    }

    func testTheLineSpacingDoesNotApplyToABlock() {
        textView.lineHeightMultiplier = 2.0
        textView.extraLineSpacing = 10.0

        let block = FixedBlock(height: 100.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        XCTAssertEqual(line(of: block)!.height, 110.0, accuracy: 0.5)
    }

    // MARK: - Measured height

    func testTheHeightOfAWrappingBlockIsWhatTheViewMeasuredTo() {
        let block = WrappingBlock(contentHeight: 90.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        XCTAssertEqual(line(of: block)!.height, 90.0, accuracy: 0.5)
        XCTAssertEqual(block.view?.frame.height ?? 0.0, 90.0, accuracy: 0.5)
    }

    func testAResizeRequestFramesTheTextAgainWithTheNewHeight() {
        let block = WrappingBlock(contentHeight: 90.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let oldFrame = textView.textFrame!
        block.contentHeight = 200.0
        block.setNeedsResize()

        wait("the reframe") { textView.textFrame != nil && textView.textFrame !== oldFrame }
        spin(0.2)
        textView.layoutIfNeeded()

        XCTAssertEqual(line(of: block)!.height, 200.0, accuracy: 0.5)
        XCTAssertEqual(block.view?.frame.height ?? 0.0, 200.0, accuracy: 0.5)
        XCTAssertEqual(block.view?.isHidden, false)
    }

    func testAResizeToTheSameHeightDoesNotFrameTheTextAgain() {
        let block = WrappingBlock(contentHeight: 90.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let oldFrame = textView.textFrame!
        block.setNeedsResize()

        spin(0.5)

        XCTAssertTrue(textView.textFrame === oldFrame)
    }

    func testTheViewIsKeptOutOfSightWhileItIsResizedUnlessTheAttachmentSaysOtherwise() {
        let block = WrappingBlock(contentHeight: 90.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let view = block.view!
        XCTAssertTrue(view.frame.intersects(textView.container.visibleRect))

        block.contentHeight = 150.0
        textView.container.attachmentResizeRequested(block)
        XCTAssertTrue(view.isHidden)

        // It is shown again once it is where the new frame has put it.
        wait("the view to show") { !view.isHidden && view.frame.height == 150.0 }

        // The other kind of attachment lets it be seen.
        let stayer = WrappingBlock(contentHeight: 90.0)
        stayer.hides = false
        textView.attributedText = text(with: stayer)
        awaitFrame()

        let stayerView = stayer.view!
        stayer.contentHeight = 150.0
        textView.container.attachmentResizeRequested(stayer)

        XCTAssertFalse(stayerView.isHidden)
    }

    // MARK: - Inline

    func testAnInlineViewSitsInTheLineAndMakesItTallerThanTheText() {
        let box = InlineBox()

        let result = NSMutableAttributedString(string: "ab ")
        let marker = NSMutableAttributedString(string: "\u{FFFC}")
        marker.addAttribute(.replacement, value: box, range: NSRange(location: 0, length: 1))
        result.append(marker)
        result.append(NSAttributedString(string: " cd"))

        textView.attributedText = result
        awaitFrame()

        XCTAssertEqual(lines.count, 1)

        let textLine = lines[0]
        XCTAssertFalse(textLine.isBlock)
        XCTAssertGreaterThanOrEqual(textLine.ascent, 40.0 - 0.5)

        let view = box.view!
        XCTAssertEqual(view.frame.width, 40.0, accuracy: 0.5)
        XCTAssertEqual(view.frame.height, 50.0, accuracy: 0.5)

        // The bottom edge of the view is 10 points below the baseline.
        XCTAssertEqual(view.frame.maxY, textLine.origin.y + 10.0, accuracy: 0.5)
    }

    // MARK: - Placement of views

    func testViewsFarFromTheScreenAreDroppedAndMadeAgainWhenTheyComeBack() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block, before: 2, after: 80)
        awaitFrame()

        XCTAssertNotNil(block.view)
        XCTAssertEqual(block.loadCount, 1)

        textView.setContentOffset(CGPoint(x: 0.0, y: textView.contentSize.height - 480.0), animated: false)
        textView.layoutIfNeeded()

        XCTAssertNil(block.view)

        textView.setContentOffset(.zero, animated: false)
        textView.layoutIfNeeded()

        XCTAssertNotNil(block.view)
        XCTAssertEqual(block.loadCount, 2)
    }

    func testTheViewPrefetchDistanceMakesTheViewBeforeItIsOnTheScreen() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block, before: 40, after: 40)
        awaitFrame()

        let blockLine = line(of: block)!
        XCTAssertNil(block.view)

        textView.setContentOffset(CGPoint(x: 0.0, y: blockLine.top - 480.0 - 100.0), animated: false)
        textView.layoutIfNeeded()
        XCTAssertNil(block.view)

        textView.viewAttachmentPrefetchDistance = 200.0
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        XCTAssertNotNil(block.view)
    }

    func testAnAttachmentThatRetainsItsViewKeepsItFarFromTheScreen() {
        let block = RetainedBlock()
        textView.attributedText = text(with: block, before: 2, after: 80)
        awaitFrame()

        textView.setContentOffset(CGPoint(x: 0.0, y: textView.contentSize.height - 480.0), animated: false)
        textView.layoutIfNeeded()

        XCTAssertNotNil(block.view)
    }

    func testTheViewOfAnAttachmentThatIsNotInTheNewTextIsRemoved() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let view = block.view!
        XCTAssertTrue(view.superview === textView.container)

        show(urduText(10))

        XCTAssertNil(block.view)
        XCTAssertNil(view.superview)
    }

    func testTheViewIsKeptWhileTheTextIsFramedAgain() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let view = block.view!
        let oldFrame = textView.textFrame!

        textView.extraLineSpacing = 6.0
        wait("the reframe") { textView.textFrame != nil && textView.textFrame !== oldFrame }
        spin(0.2)
        textView.layoutIfNeeded()

        XCTAssertTrue(block.view === view)
        XCTAssertEqual(block.loadCount, 1)
    }

    // MARK: - Geometry

    func testTheRectOfAViewAttachmentIsTheRoomOfItsView() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let rect = textView.rects(for: block).first!

        XCTAssertEqual(rect, block.view!.frame)
    }

    func testTouchesReachTheViewOfABlockAndNotTheLinesUnderIt() {
        let block = FixedBlock(height: 120.0)
        textView.attributedText = text(with: block)
        awaitFrame()

        let view = block.view!
        let center = CGPoint(x: view.frame.midX, y: view.frame.midY)

        XCTAssertTrue(textView.hitTest(center, with: nil) === view)

        // Scrolling the lines about does not bring them over the view.
        textView.setContentOffset(CGPoint(x: 0.0, y: 5.0), animated: false)
        textView.layoutIfNeeded()

        let moved = CGPoint(x: view.frame.midX, y: view.frame.midY)
        XCTAssertTrue(textView.hitTest(moved, with: nil) === view)
    }

    func testTextUnderTheViewOfABlockIsInert() {
        let block = FixedBlock(height: 120.0)
        let source = NSMutableAttributedString(attributedString: text(with: block))
        source.addAttribute(.link, value: URL(string: "https://example.com")!, range: NSRange(location: 0, length: source.length))

        textView.attributedText = source
        awaitFrame()

        let center = CGPoint(x: block.view!.frame.midX, y: block.view!.frame.midY)
        XCTAssertNil(textView.container.interactionTarget(at: center))
    }
}

private final class RetainedBlock: ViewAttachment, @unchecked Sendable {
    override var height: CGFloat { 100.0 }
    override var retainWhenOffscreen: Bool { true }

    override func loadView() -> UIView {
        return UIView()
    }
}
