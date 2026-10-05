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

/// The methods that a `TTextView` calls to know what to do when a link or a replacement of its
/// text is tapped. Both have a default implementation that returns `true`.
@MainActor
public protocol TTextViewDelegate: AnyObject {
    /// Asks the delegate whether the link should be opened. It is called when the finger is lifted
    /// from a link, which is a character range with a `.link` attribute.
    ///
    /// - Parameters:
    ///   - textView: The text view containing the link.
    ///   - url: The URL of the link.
    ///   - codeUnitRange: The UTF-16 range of the link in the source string.
    /// - Returns: `true` if the text view should open the URL. Return `false` after handling the
    ///            tap, to keep it from being opened.
    func textView(_ textView: TTextView, shouldInteractWith url: URL, in codeUnitRange: Range<Int>) -> Bool

    /// Tells the delegate that a replacement, such as an inline image, is tapped. A replacement
    /// has no default action, and a link under it is not tappable. The text of a `ViewAttachment`
    /// is inert: the view takes its own touches.
    ///
    /// - Parameters:
    ///   - textView: The text view containing the replacement.
    ///   - replacement: The replacement that was tapped.
    ///   - codeUnitRange: The UTF-16 range of the replacement in the source string.
    /// - Returns: The return value is not used.
    func textView(_ textView: TTextView, shouldInteractWith replacement: TextReplacement, in codeUnitRange: Range<Int>) -> Bool
}

public extension TTextViewDelegate {
    func textView(_ textView: TTextView, shouldInteractWith url: URL, in codeUnitRange: Range<Int>) -> Bool {
        return true
    }

    func textView(_ textView: TTextView, shouldInteractWith replacement: TextReplacement, in codeUnitRange: Range<Int>) -> Bool {
        return true
    }
}

/// What a touch can press in a `TTextView`.
enum InteractionTarget {
    case link(URL, Range<Int>)
    case replacement(TextReplacement, Range<Int>)

    var codeUnitRange: Range<Int> {
        switch self {
        case .link(_, let range), .replacement(_, let range):
            return range
        }
    }

    var isLink: Bool {
        if case .link = self {
            return true
        }

        return false
    }

    func isSame(as other: InteractionTarget) -> Bool {
        switch (self, other) {
        case (.link(_, let first), .link(_, let second)):
            return first == second
        case (.replacement(let first, _), .replacement(let second, _)):
            return first === second
        default:
            return false
        }
    }
}

/// A view drawn behind the text, which shows the link that is pressed.
final class LinkHighlightView: UIView {
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }

    private var shapeLayer: CAShapeLayer {
        return layer as! CAShapeLayer
    }

    var fillColor: UIColor = .clear {
        didSet {
            shapeLayer.fillColor = fillColor.cgColor
        }
    }

    var path: CGPath? {
        didSet {
            shapeLayer.path = path
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Follows a touch on a link or a replacement of a `TTextView`. It highlights the link while it is
/// pressed, and recognizes a tap when the finger is lifted from the same place. The touch is only
/// observed, never taken away from the scroll view.
final class LinkInteractionRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let touchSlop: CGFloat = 10.0

    private var startPosition: CGPoint = .zero

    /// The target that is pressed right now.
    private(set) var target: InteractionTarget?

    private var container: TextContainer? {
        return view as? TextContainer
    }

    init() {
        super.init(target: nil, action: nil)

        cancelsTouchesInView = false
        delegate = self
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    func cancelInteraction() {
        target = nil
        container?.clearHighlight()
    }

    private func fail() {
        cancelInteraction()
        state = .failed
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let container = container, let touch = touches.first, numberOfTouches == 1 else {
            fail()
            return
        }

        // The scroll view takes the touch that stops a fling; that is not a tap on a link.
        let position = touch.location(in: container)

        guard !container.isDecelerating, let found = container.interactionTarget(at: position) else {
            fail()
            return
        }

        target = found
        startPosition = position
        container.highlight(found)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let container = container, let touch = touches.first, let pressed = target else {
            return
        }

        if numberOfTouches > 1 {
            fail()
            return
        }

        let position = touch.location(in: container)
        let isSlop = abs(position.x - startPosition.x) > touchSlop || abs(position.y - startPosition.y) > touchSlop

        if isSlop || container.interactionTarget(at: position)?.isSame(as: pressed) != true {
            fail()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if target != nil {
            state = .recognized
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        cancelInteraction()
        state = .cancelled
    }

    override func reset() {
        cancelInteraction()
    }
}

extension TextContainer {
    /// The source that the displayed frame was made from, or `nil` while it is not resolved.
    var sourceText: NSAttributedString? {
        guard textFrame != nil else {
            return nil
        }

        return typesetter?.text ?? attributedText
    }

    /// Finds what a touch at the position would press: a replacement, or, unless link interaction
    /// is turned off, a link.
    func interactionTarget(at position: CGPoint) -> InteractionTarget? {
        guard let textFrame = textFrame,
              let text = sourceText,
              let codeUnitIndex = indexOfCodeUnitUnderPosition(position),
              textFrame.codeUnitRange.contains(codeUnitIndex),
              codeUnitIndex < text.length else {
            return nil
        }

        // The room of a view is the view's business, so the text under it, and the margins around
        // it, are inert.
        if isInsideViewAttachment(at: position) {
            return nil
        }

        let fullRange = NSRange(location: 0, length: text.length)
        var effectiveRange = NSRange(location: 0, length: 0)

        if let replacement = text.attribute(
            .replacement, at: codeUnitIndex, longestEffectiveRange: &effectiveRange, in: fullRange
        ) as? TextReplacement {
            if replacement is ViewAttachment {
                return nil
            }

            return .replacement(replacement, effectiveRange.location ..< NSMaxRange(effectiveRange))
        }

        guard isLinkInteractionEnabled,
              let value = text.attribute(.link, at: codeUnitIndex, longestEffectiveRange: &effectiveRange, in: fullRange) else {
            return nil
        }

        let url = (value as? URL) ?? (value as? String).flatMap { URL(string: $0) }
        guard let linkURL = url else {
            return nil
        }

        return .link(linkURL, effectiveRange.location ..< NSMaxRange(effectiveRange))
    }

    /// Shows the target as pressed. Only a link is highlighted.
    func highlight(_ target: InteractionTarget) {
        guard target.isLink else {
            return
        }

        let path = CGMutablePath()
        path.addRects(selectionRects(forCodeUnitRange: target.codeUnitRange))

        highlightView.path = path
    }

    func clearHighlight() {
        highlightView.path = nil
    }

    @objc func linkInteractionRecognized() {
        guard linkRecognizer.state == .recognized, let target = linkRecognizer.target else {
            return
        }

        switch target {
        case .replacement(let replacement, let range):
            _ = textView.textViewDelegate?.textView(textView, shouldInteractWith: replacement, in: range)
        case .link(let url, let range):
            if textView.textViewDelegate?.textView(textView, shouldInteractWith: url, in: range) ?? true {
                UIApplication.shared.open(url)
            }
        }
    }
}
