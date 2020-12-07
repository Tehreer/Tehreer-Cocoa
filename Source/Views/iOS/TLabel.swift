//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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

#if os(iOS)

import UIKit

private class SizeLabel: UILabel {
    weak var parent: TLabel!

    public override var intrinsicContentSize: CGSize {
        return parent.intrinsicContentSize(for: preferredMaxLayoutWidth)
    }
}

/// A view that displays read-only text to the user.
open class TLabel: UIView {
    private let renderer = Renderer()
    private let resolver = FrameResolver()

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?
    private var _sizeLabel = SizeLabel()

    private var needsTypesetter: Bool = false
    private(set) open var textFrame: ComposedFrame? = nil

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSizeLabel()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSizeLabel()
    }

    open override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    private func addSizeLabel() {
        _sizeLabel.parent = self
        _sizeLabel.alpha = 0.0
        _sizeLabel.isUserInteractionEnabled = false
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        _sizeLabel.numberOfLines = 0
        _sizeLabel.text = ""

        addSubview(_sizeLabel)

        addConstraint(NSLayoutConstraint(item: _sizeLabel, attribute: .left, relatedBy: .equal,
                                         toItem: self, attribute: .left,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: _sizeLabel, attribute: .top, relatedBy: .equal,
                                         toItem: self, attribute: .top,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: _sizeLabel, attribute: .right, relatedBy: .equal,
                                         toItem: self, attribute: .right,
                                         multiplier: 1.0, constant: 0.0))
        addConstraint(NSLayoutConstraint(item: _sizeLabel, attribute: .bottom, relatedBy: .equal,
                                         toItem: self, attribute: .bottom,
                                         multiplier: 1.0, constant: 0.0))
    }

    private func sceil(_ x: CGFloat) -> CGFloat {
        let scale = layer.contentsScale
        return ceil(x * scale) / scale
    }

    func intrinsicContentSize(for width: CGFloat) -> CGSize {
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true

        guard let textFrame = makeTextFrame(paddingLeft: .zero, paddingTop: .zero,
                                            layoutWidth: width == 0 ? .infinity : width,
                                            layoutHeight: .infinity) else { return .zero }

        return CGSize(width: sceil(textFrame.width), height: sceil(textFrame.height))
    }

    private func deferNeedsTextLayout() {
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.setNeedsDisplay()
        }
    }

    /// Lays out subviews.
    open override func layoutSubviews() {
        super.layoutSubviews()

        let viewSize = bounds.size

        resolver.fitsHorizontally = false
        resolver.fitsVertically = false

        updateFrame(paddingLeft: .zero, paddingTop: .zero,
                    layoutWidth: viewSize.width, layoutHeight: viewSize.height)
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

    /// Draws the receiver’s image within the passed-in rectangle.
    ///
    /// - Parameter rect: The portion of the view’s bounds that needs to be updated.
    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        if contentMode != .center {
            print("Use center content mode in label for appropriate frame changes animation.")
        }

        if let context = UIGraphicsGetCurrentContext() {
            renderer.renderScale = layer.contentsScale

            if let textFrame = textFrame {
                textFrame.draw(with: renderer, in: context, at: .zero)
            }
        }
    }

    private func makeTextFrame(paddingLeft: CGFloat, paddingTop: CGFloat, layoutWidth: CGFloat, layoutHeight: CGFloat) -> ComposedFrame? {
        if let typesetter = typesetter {
            resolver.typesetter = typesetter
            resolver.frameBounds = CGRect(x: paddingLeft, y: paddingTop, width: layoutWidth, height: layoutHeight)

            let string = typesetter.text.string
            let frame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)

            return frame
        }

        return nil
    }

    private func updateFrame(paddingLeft: CGFloat, paddingTop: CGFloat, layoutWidth: CGFloat, layoutHeight: CGFloat) {
        textFrame = makeTextFrame(paddingLeft: paddingLeft, paddingTop: paddingTop, layoutWidth: layoutWidth, layoutHeight: layoutHeight)
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

        _sizeLabel.invalidateIntrinsicContentSize()
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

    /// The vertical alignment to apply on the contents. Its default value is `.top`.
    open var verticalAlignment: VerticalAlignment {
        get {
            return resolver.verticalAlignment
        }
        set {
            resolver.verticalAlignment = newValue
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

            _sizeLabel.invalidateIntrinsicContentSize()
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
        get {
            return renderer.typeface
        }
        set {
            renderer.typeface = newValue
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
    open var textSize: CGFloat {
        get {
            return renderer.typeSize
        }
        set {
            renderer.typeSize = max(.zero, newValue)
            updateTypesetter()
        }
    }

    /// The default color of the text.
    open var textColor: UIColor {
        get {
            return renderer.fillColor
        }
        set {
            renderer.fillColor = newValue
            setNeedsDisplay()
        }
    }

    /// The truncation mode that should be used on the last line of the text in case of overflow.
    open var truncationMode: BreakMode {
        get {
            return resolver.truncationMode
        }
        set {
            resolver.truncationMode = newValue

            _sizeLabel.invalidateIntrinsicContentSize()
            deferNeedsTextLayout()
        }
    }

    /// The truncation place for the last line of the text. The truncation is disabled if its value
    /// is `.nil`
    open var truncationPlace: TruncationPlace? {
        get {
            return resolver.truncationPlace
        }
        set {
            resolver.truncationPlace = newValue

            _sizeLabel.invalidateIntrinsicContentSize()
            deferNeedsTextLayout()
        }
    }

    /// The maximum number of lines to use for rendering text.
    open var maxLines: Int? {
        get {
            return resolver.maxLines
        }
        set {
            resolver.maxLines = newValue

            _sizeLabel.invalidateIntrinsicContentSize()
            deferNeedsTextLayout()
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

            _sizeLabel.invalidateIntrinsicContentSize()
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

            _sizeLabel.invalidateIntrinsicContentSize()
            deferNeedsTextLayout()
        }
    }
}

#endif
