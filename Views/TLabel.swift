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

@IBDesignable public class TLabel: UIView {
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

    private var fittingSize: CGSize {
        get {
            return _fittingSize
        }
        set {
            let contentsScale = layer.contentsScale

            _fittingSize.width = ceil(newValue.width * contentsScale) / contentsScale
            _fittingSize.height = ceil(newValue.height * contentsScale) / contentsScale
        }
    }

    public override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let oldSize = bounds.size
            super.frame = newValue

            let newSize = bounds.size
            if newSize != oldSize {
                setNeedsLayout()
            }
        }
    }

    public override var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            let oldSize = bounds.size
            super.bounds = newValue

            let newSize = bounds.size
            if newSize != oldSize {
                setNeedsLayout()
            }
        }
    }

    public override var intrinsicContentSize: CGSize {
        if typesetter != nil && preferredWidth == nil {
            resolver.fitsHorizontally = true
            resolver.fitsVertically = true

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: .infinity, layoutHeight: .infinity)

            fittingSize = textFrame?.size ?? .zero
            preferredWidth = fittingSize.width
        }

        return fittingSize
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        let viewSize = bounds.size

        if preferredWidth != nil && viewSize.width != preferredWidth {
            resolver.fitsHorizontally = true
            resolver.fitsVertically = true

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: viewSize.width, layoutHeight: .infinity)

            fittingSize = textFrame?.size ?? .zero
            preferredWidth = viewSize.width

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        } else if preferredWidth == nil || viewSize.height != fittingSize.height {
            resolver.fitsHorizontally = false
            resolver.fitsVertically = false

            updateFrame(paddingLeft: .zero, paddingTop: .zero,
                        layoutWidth: viewSize.width, layoutHeight: viewSize.height)
        }
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        if let context = UIGraphicsGetCurrentContext() {
            let t1 = CFAbsoluteTimeGetCurrent()

            renderer.renderScale = layer.contentsScale
            context.saveGState()

            if let textFrame = textFrame {
                textFrame.draw(using: renderer, in: context, at: .zero)
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
    }

    public var textAlignment: TextAlignment {
        get {
            return resolver.textAlignment
        }
        set {
            resolver.textAlignment = newValue
            setNeedsLayout()
        }
    }

    public var verticalAlignment: VerticalAlignment {
        get {
            return resolver.verticalAlignment
        }
        set {
            resolver.verticalAlignment = newValue
            setNeedsLayout()
        }
    }

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
        }
    }

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

    public var typeface: Typeface? {
        get {
            return renderer.typeface
        }
        set {
            renderer.typeface = newValue
            updateTypesetter()
        }
    }

    @IBInspectable public var text: String! {
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

    @IBInspectable public var textSize: CGFloat {
        get {
            return renderer.typeSize
        }
        set {
            renderer.typeSize = max(.zero, newValue)
            updateTypesetter()
        }
    }

    @IBInspectable public var textColor: UIColor {
        get {
            return renderer.fillColor
        }
        set {
            renderer.fillColor = newValue
            setNeedsDisplay()
        }
    }

    public var maxLines: Int? {
        get {
            return resolver.maxLines
        }
        set {
            resolver.maxLines = newValue
            setNeedsLayoutAndSize()
        }
    }

    @IBInspectable public var extraLineSpacing: CGFloat {
        get {
            return resolver.extraLineSpacing
        }
        set {
            resolver.extraLineSpacing = newValue
            setNeedsLayoutAndSize()
        }
    }

    @IBInspectable public var lineHeightMultiplier: CGFloat {
        get {
            return resolver.lineHeightMultiplier
        }
        set {
            resolver.lineHeightMultiplier = newValue
            setNeedsLayoutAndSize()
        }
    }
}
