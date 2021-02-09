//
// Copyright (C) 2021 Muhammad Tayyab Akram
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

open class TTextView: UIView {
    private let scrollView = UIScrollView()
    private let delegate = Delegate()
    private let renderer = Renderer()
    private let resolver = FrameResolver()

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?

    private var needsTypesetter: Bool = false
    private(set) open var textFrame: ComposedFrame? = nil

    private var lineViews: [LineView] = []
    private var lineBoxes: [CGRect] = []

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        renderScale = UIScreen.main.scale

        delegate.parent = self

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = delegate

        addSubview(scrollView)

        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal,
                                         toItem: self, attribute: .left,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal,
                                         toItem: self, attribute: .top,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal,
                                         toItem: self, attribute: .right,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal,
                                         toItem: self, attribute: .bottom,
                                         multiplier: 1.0, constant: 0.0))
    }

    private func deferNeedsTextLayout() {
        resolver.fitsHorizontally = false
        resolver.fitsVertically = true

        updateFrame(paddingLeft: .zero, paddingTop: .zero,
                    layoutWidth: bounds.width, layoutHeight: .greatestFiniteMagnitude)
    }

    /// Lays out subviews.
    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutLines()
    }

    /// The frame rectangle, which describes the view’s location and size in its superview’s
    /// coordinate system.
    open override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let oldSize = bounds.size
            super.frame = newValue

            if bounds.size != oldSize {
                deferNeedsTextLayout()
            }
        }
    }

    /// The bounds rectangle, which describes the view’s location and size in its own coordinate
    /// system.
    open override var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            let oldSize = bounds.size
            super.bounds = newValue

            if bounds.size != oldSize {
                deferNeedsTextLayout()
            }
        }
    }

    private func makeTextFrame(paddingLeft: CGFloat, paddingTop: CGFloat,
                               layoutWidth: CGFloat, layoutHeight: CGFloat) -> ComposedFrame? {
        guard let typesetter = typesetter else {
            return nil
        }

        resolver.typesetter = typesetter
        resolver.frameBounds = CGRect(x: paddingLeft, y: paddingTop,
                                      width: layoutWidth, height: layoutHeight)

        let string = typesetter.text.string
        let frame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)

        return frame
    }

    private func resolveLineBoxes() {
        guard let textFrame = textFrame else {
            return
        }

        lineBoxes.removeAll()

        for textLine in textFrame.lines {
            var lineBox = textLine.computeBoundingBox(with: renderer)
            lineBox = lineBox.offsetBy(dx: textLine.origin.x, dy: textLine.origin.y)

            lineBoxes.append(lineBox)
        }

        scrollView.contentSize = CGSize(width: textFrame.width, height: textFrame.height)
    }

    fileprivate func layoutLines() {
        guard let textFrame = textFrame else {
            return
        }

        let contentOffset = scrollView.contentOffset
        let visibleSize = scrollView.bounds.size
        let visibleRect = CGRect(origin: contentOffset, size: visibleSize)

        var outsideViews: [LineView] = []
        var insideViews: [LineView] = []

        // Get outside and inside line views.
        for lineView in lineViews {
            if lineView.frame.intersects(visibleRect) {
                insideViews.append(lineView)
            } else {
                outsideViews.append(lineView)
            }
        }

        var visibleIndexes: [Int] = []

        // Get line indexes that should be visible.
        for i in 0 ..< lineBoxes.count {
            if lineBoxes[i].intersects(visibleRect) {
                visibleIndexes.append(i)
            }
        }

        var previousView: LineView?

        // Layout the lines.
        for index in visibleIndexes {
            let textLine = textFrame.lines[index]
            let insideView = insideViews.first { $0.line === textLine }
            let lineView: LineView

            if let insideView = insideView {
                lineView = insideView
            } else {
                if let outsideView = outsideViews.popLast() {
                    lineView = outsideView
                } else {
                    lineView = LineView()
                    lineView.backgroundColor = .clear
                    lineViews.append(lineView)
                }

                let renderer = lineView.renderer
                renderer.typeface = typeface
                renderer.typeSize = textSize
                renderer.fillColor = textColor
                renderer.renderScale = renderScale

                lineView.line = textLine
                lineView.frame = lineBoxes[index]
            }

            if let previousView = previousView {
                scrollView.insertSubview(lineView, aboveSubview: previousView)
            } else {
                scrollView.addSubview(lineView)
            }

            previousView = lineView
        }
    }

    private func updateFrame(paddingLeft: CGFloat, paddingTop: CGFloat,
                             layoutWidth: CGFloat, layoutHeight: CGFloat) {
        textFrame = makeTextFrame(paddingLeft: paddingLeft, paddingTop: paddingTop,
                                  layoutWidth: layoutWidth, layoutHeight: layoutHeight)
        resolveLineBoxes()
        layoutLines()
    }

    private func updateTypesetter() {
        if needsTypesetter {
            return
        }
        _typesetter = nil

        if let text = text {
            if let typeface = typeface, !text.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize]

                _typesetter = Typesetter(text: NSAttributedString(string: text),
                                         defaultAttributes: defaultAttributes)
            }
        } else if let attributedText = attributedText {
            if let typeface = typeface, !attributedText.string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize]

                _typesetter = Typesetter(text: attributedText, defaultAttributes: defaultAttributes)
            }
        }

        deferNeedsTextLayout()
    }

    /// Returns the UTF-16 index representing the specified position, or `nil` if there is no
    /// character at this position.
    ///
    /// - Parameter position: The position for which to determine the UTF-16 index.
    open func indexOfCodeUnit(at position: CGPoint) -> Int? {
        guard let characterIndex = indexOfCharacter(at: position) else {
            return nil
        }

        return textFrame?.string.utf16Index(forCharacterAt: characterIndex)
    }

    /// Returns the index of character representing the specified position, or `nil` if there is no
    /// character at this position.
    ///
    /// - Parameter position: The position for which to determine the character index.
    open func indexOfCharacter(at position: CGPoint) -> String.Index? {
        guard let textFrame = textFrame else {
            return nil
        }

        let lineIndex = textFrame.indexOfLine(at: position)
        let textLine = textFrame.lines[lineIndex]
        let lineLeft = textLine.origin.x
        let lineRight = lineLeft + textLine.width

        if position.x >= lineLeft && position.x <= lineRight {
            let characterIndex = textLine.indexOfCharacter(at: position.x - lineLeft)
            let lastIndex = textFrame.string.index(before: textLine.endIndex)

            // Make sure to provide character of this line.
            if characterIndex > lastIndex {
                return lastIndex
            }

            return characterIndex
        }

        return nil
    }

    private var renderScale: CGFloat {
        get {
            return renderer.renderScale
        }
        set {
            renderer.renderScale = newValue
        }
    }

    /// The text alignment to apply on each line. Its default value is `.intrinsic`.
    open var textAlignment: TextAlignment {
        get {
            return resolver.textAlignment
        }
        set {
            resolver.textAlignment = newValue
            deferNeedsTextLayout()
        }
    }

    /// The typesetter that is used to compose text lines.
    ///
    /// Setting this property will make `text` and `attributedText` properties `nil`.
    ///
    /// A typesetter is preferred over `attributedText` as it avoids an extra step of creating the typesetter
    /// from the `attributedText`.
    open var typesetter: Typesetter? {
        get {
            return _typesetter
        }
        set {
            _text = nil
            _attributedText = nil
            _typesetter = newValue
            needsTypesetter = true

            deferNeedsTextLayout()
        }
    }

    /// The current styled text that is displayed by the label.
    ///
    /// This property will be `nil` if either `text` or `typesetter` is being used instead. Setting
    /// this property will make `text` property `nil`.
    ///
    /// If performance is required, a typesetter should be used directly.
    open var attributedText: NSAttributedString! {
        get {
            return _attributedText
        }
        set {
            _text = nil
            _attributedText = newValue
            needsTypesetter = false

            updateTypesetter()
        }
    }

    /// The typeface in which the text is displayed.
    open var typeface: Typeface? {
        didSet {
            updateTypesetter()
        }
    }

    /// The current text that is displayed by the label.
    ///
    /// This property will be `nil` if either `attributedText` or `typesetter` is being used
    /// instead. Setting this property will make `text` property `nil`.
    ///
    /// If performance is required, a typesetter should be used directly.
    open var text: String! {
        get {
            return _text
        }
        set {
            _text = newValue ?? ""
            _attributedText = nil
            needsTypesetter = false

            updateTypesetter()
        }
    }

    /// The default size of the text.
    @objc open var textSize: CGFloat = 16.0 {
        didSet {
            updateTypesetter()
        }
    }

    /// The default color of the text.
    @objc open var textColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
        }
    }

    /// The extra spacing that is added after each text line. It is resolved before line height
    /// multiplier. Its default value is zero.
    open var extraLineSpacing: CGFloat {
        get {
            return resolver.extraLineSpacing
        }
        set {
            resolver.extraLineSpacing = newValue
            deferNeedsTextLayout()
        }
    }

    /// The height multiplier that is applied on each text line. It is resolved after extra line
    /// spacing. Its default value is one.
    ///
    /// The additional spacing is adjusted in such a way that text remains in the middle of the
    /// line.
    open var lineHeightMultiplier: CGFloat {
        get {
            return resolver.lineHeightMultiplier
        }
        set {
            resolver.lineHeightMultiplier = newValue
            deferNeedsTextLayout()
        }
    }
}

private class Delegate: NSObject, UIScrollViewDelegate {
    weak var parent: TTextView!

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        parent.layoutLines()
    }
}
