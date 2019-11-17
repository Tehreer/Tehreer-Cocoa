//
// Copyright (C) 2019 Muhammad Tayyab Akram
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

/// A view that displays read-only text to the user.
public class TLabel: UIView {
    private let renderer = Renderer()
    private let resolver = FrameResolver()

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?
    private var _fittingSize: CGSize = .zero

    private var needsTypesetter: Bool = false
    private var preferredWidth: CGFloat?
    private var layoutRect: CGRect = .zero
    private var textFrame: ComposedFrame? = nil

    private func sceil(_ x: CGFloat) -> CGFloat {
        let scale = layer.contentsScale
        return ceil(x * scale) / scale
    }

    private var fittingSize: CGSize {
        get {
            return _fittingSize
        }
        set {
            _fittingSize.width = sceil(newValue.width)
            _fittingSize.height = sceil(newValue.height)
        }
    }

    /// The frame rectangle, which describes the view’s location and size in its superview’s
    /// coordinate system.
    public override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let oldSize = bounds.size
            super.frame = newValue

            if bounds.size != oldSize {
                setNeedsLayout()
                setNeedsDisplay()
            }
        }
    }

    /// The bounds rectangle, which describes the view’s location and size in its own coordinate
    /// system.
    public override var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            let oldSize = bounds.size
            super.bounds = newValue

            if bounds.size != oldSize {
                setNeedsLayout()
                setNeedsDisplay()
            }
        }
    }

    /// The natural size for the receiving view, considering only properties of the view itself.
    public override var intrinsicContentSize: CGSize {
        if typesetter != nil && preferredWidth == nil {
            resolver.fitsHorizontally = true
            resolver.fitsVertically = true

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: .infinity, layoutHeight: .infinity)

            fittingSize = CGSize(width: textFrame?.width ?? .zero,
                                 height: textFrame?.height ?? .zero)
            preferredWidth = fittingSize.width
        }

        return fittingSize
    }

    /// Lays out subviews.
    public override func layoutSubviews() {
        super.layoutSubviews()

        let viewSize = bounds.size

        if preferredWidth != nil && viewSize.width != preferredWidth {
            resolver.fitsHorizontally = true
            resolver.fitsVertically = true

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: viewSize.width, layoutHeight: .infinity)

            fittingSize = CGSize(width: textFrame?.width ?? .zero,
                                 height: textFrame?.height ?? .zero)
            preferredWidth = viewSize.width

            invalidateIntrinsicContentSize()
            setNeedsLayout()
            setNeedsDisplay()
        } else if preferredWidth == nil || viewSize.height != sceil(textFrame?.height ?? .zero) {
            resolver.fitsHorizontally = false
            resolver.fitsVertically = false

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: viewSize.width, layoutHeight: viewSize.height)
        }
    }

    /// Draws the receiver’s image within the passed-in rectangle.
    ///
    /// - Parameter rect: The portion of the view’s bounds that needs to be updated.
    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        if contentMode != .center {
            print("Use center content mode in label for appropriate frame changes animation.")
        }

        if let context = UIGraphicsGetCurrentContext() {
            let t1 = CFAbsoluteTimeGetCurrent()

            renderer.renderScale = layer.contentsScale
            context.saveGState()

            if let textFrame = textFrame {
                textFrame.draw(with: renderer, in: context, at: .zero)
            }

            context.restoreGState()

            let t2 = CFAbsoluteTimeGetCurrent()
            print("Time taken to render label: \((t2 - t1) * 1E3)")
        }
    }

    private func setNeedsLayoutAndSize() {
        preferredWidth = nil
        setNeedsLayout()
    }

    private func updateFrame(paddingLeft: CGFloat, paddingTop: CGFloat, layoutWidth: CGFloat, layoutHeight: CGFloat) {
        textFrame = nil

        if let typesetter = typesetter {
            let t1 = CFAbsoluteTimeGetCurrent()

            layoutRect = CGRect(x: paddingLeft, y: paddingTop, width: layoutWidth, height: layoutHeight)

            resolver.typesetter = typesetter
            resolver.frameBounds = layoutRect

            let string = typesetter.text.string
            textFrame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)

            let t2 = CFAbsoluteTimeGetCurrent()
            print("Time taken to resolve frame: \((t2 - t1) * 1E3)")
        }
    }

    private func updateTypesetter() {
        if needsTypesetter {
            return
        }
        _typesetter = nil

        let t1 = CFAbsoluteTimeGetCurrent()

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

        let t2 = CFAbsoluteTimeGetCurrent()
        print("Time taken to create typesetter: \((t2 - t1) * 1E3)")

        setNeedsLayoutAndSize()
        setNeedsDisplay()
    }

    /// The text alignment to apply on each line. Its default value is `.intrinsic`.
    public var textAlignment: TextAlignment {
        get {
            return resolver.textAlignment
        }
        set {
            resolver.textAlignment = newValue

            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    /// The vertical alignment to apply on the contents. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment {
        get {
            return resolver.verticalAlignment
        }
        set {
            resolver.verticalAlignment = newValue

            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    /// The typesetter that is used to compose text lines.
    ///
    /// Setting this property will make `text` and `attributedText` properties `nil`.
    ///
    /// A typesetter is preferred over `attributedText` as it avoids an extra step of creating the typesetter
    /// from the `attributedText`.
    public var typesetter: Typesetter? {
        get {
            return _typesetter
        }
        set {
            _text = nil
            _attributedText = nil
            _typesetter = newValue
            needsTypesetter = true

            setNeedsLayoutAndSize()
            setNeedsDisplay()
        }
    }

    /// The current styled text that is displayed by the label.
    ///
    /// This property will be `nil` if either `text` or `typesetter` is being used instead. Setting
    /// this property will make `text` property `nil`.
    ///
    /// If performance is required, a typesetter should be used directly.
    public var attributedText: NSAttributedString! {
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
    public var typeface: Typeface? {
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
    public var text: String! {
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
    public var textSize: CGFloat {
        get {
            return renderer.typeSize
        }
        set {
            renderer.typeSize = max(.zero, newValue)
            updateTypesetter()
        }
    }

    /// The default color of the text.
    public var textColor: UIColor {
        get {
            return renderer.fillColor
        }
        set {
            renderer.fillColor = newValue
            setNeedsDisplay()
        }
    }

    /// The maximum number of lines to use for rendering text.
    public var maxLines: Int? {
        get {
            return resolver.maxLines
        }
        set {
            resolver.maxLines = newValue

            setNeedsLayoutAndSize()
            setNeedsDisplay()
        }
    }

    /// The extra spacing that is added after each text line. It is resolved before line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat {
        get {
            return resolver.extraLineSpacing
        }
        set {
            resolver.extraLineSpacing = newValue

            setNeedsLayoutAndSize()
            setNeedsDisplay()
        }
    }

    /// The height multiplier that is applied on each text line. It is resolved after extra line
    /// spacing. Its default value is one.
    ///
    /// The additional spacing is adjusted in such a way that text remains in the middle of the
    /// line.
    public var lineHeightMultiplier: CGFloat {
        get {
            return resolver.lineHeightMultiplier
        }
        set {
            resolver.lineHeightMultiplier = newValue

            setNeedsLayoutAndSize()
            setNeedsDisplay()
        }
    }
}
