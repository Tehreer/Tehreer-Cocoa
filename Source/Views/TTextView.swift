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

private class TextContext {
    var layoutID: NSObject!
    var renderScale: CGFloat = 1.0
    var layoutWidth: CGFloat = .zero
    var typeface: Typeface?
    var text: String!
    var attributedText: NSAttributedString!
    var textSize: CGFloat = 16.0
    var textAlignment: TextAlignment = .intrinsic
    var textColor: UIColor = .black
    var extraLineSpacing: CGFloat = .zero
    var lineHeightMultiplier: CGFloat = 1.0

    var typesetter: Typesetter?
    var textFrame: ComposedFrame?
}

private class TypesettingOperation: Operation {
    private let context: TextContext
    private let updateBlock: ((Typesetter?) -> Void)

    init(_ context: TextContext, updateBlock: @escaping ((Typesetter?) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func typesetterParams() -> (text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any])? {
        if let text = context.text {
            if let typeface = context.typeface, !text.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: context.textSize]

                return (NSAttributedString(string: text), defaultAttributes)
            }
        } else if let attributedText = context.attributedText {
            if let typeface = context.typeface, !attributedText.string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: context.textSize]

                return (attributedText, defaultAttributes)
            }
        }

        return nil
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        DispatchQueue.main.async {
            self.updateBlock(self.context.typesetter)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let params = typesetterParams() else {
            return
        }

        context.typesetter = Typesetter(text: params.text, defaultAttributes: params.defaultAttributes)
    }
}

private class FrameResolvingOperation: Operation {
    private let context: TextContext
    private let updateBlock: ((ComposedFrame?) -> Void)

    init(_ context: TextContext, updateBlock: @escaping ((ComposedFrame?) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func frameResolver(for typesetter: Typesetter) -> FrameResolver {
        let resolver = FrameResolver()
        resolver.typesetter = typesetter
        resolver.frameBounds = CGRect(x: .zero, y: .zero, width: context.layoutWidth, height: .greatestFiniteMagnitude)
        resolver.fitsHorizontally = false
        resolver.fitsVertically = true
        resolver.textAlignment = context.textAlignment
        resolver.extraLineSpacing = context.extraLineSpacing
        resolver.lineHeightMultiplier = context.lineHeightMultiplier

        return resolver
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        DispatchQueue.main.async {
            self.updateBlock(self.context.textFrame)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let typesetter = context.typesetter else {
            return
        }

        let resolver = frameResolver(for: typesetter)
        let string = typesetter.text.string

        context.textFrame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)
    }
}

private class LineBoxesOperation: Operation {
    private let context: TextContext
    private let updateBlock: (([CGRect]) -> Void)

    private var lineBoxes: [CGRect] = []

    init(_ context: TextContext, updateBlock: @escaping (([CGRect]) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func boxRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.renderScale = context.renderScale
        renderer.typeface = context.typeface
        renderer.typeSize = context.textSize
        renderer.fillColor = context.textColor

        return renderer
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        let array = Array(lineBoxes)

        DispatchQueue.main.async {
            self.updateBlock(array)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let lines = context.textFrame?.lines else {
            return
        }

        let renderer = boxRenderer()
        var lineCount = 0

        for textLine in lines {
            defer { lineCount += 1 }

            var boundingBox = textLine.computeBoundingBox(with: renderer)
            boundingBox = boundingBox.offsetBy(dx: textLine.origin.x, dy: textLine.origin.y)

            lineBoxes.append(boundingBox)

            if isCancelled {
                return
            }

            if lineCount == 64 {
                notifyUpdateIfNeeded()
                lineCount = 0
            }
        }
    }
}

/// A scrollable, multiline text region.
open class TTextView: UIScrollView {
    private let operationQueue = OperationQueue()
    private var layoutID: NSObject!
    private var needsTextLayout = false

    private var isTypesetterUserDefined = false
    private var isTypesetterResolved = false
    private var isTextFrameResolved = false

    private var renderScale: CGFloat = 1.0

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?
    private var _textFrame: ComposedFrame?

    private var lineViews: [LineView] = []
    private var insideViews: [LineView] = []
    private var outsideViews: [LineView] = []

    private var lineBoxes: [CGRect] = []
    private var visibleIndexes: [Int] = []

    /// Returns an object initialized from data in a given unarchiver.
    ///
    /// - Parameter coder: An unarchiver object.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    ///
    /// - Parameter frame: The frame rectangle for the view, measured in points.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        renderScale = UIScreen.main.scale
    }

    /// The frame rectangle, which describes the view’s location and size in its superview’s
    /// coordinate system.
    open override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let oldWidth = layoutWidth
            let oldFrame = frame

            super.frame = newValue

            if layoutWidth != oldWidth {
                setNeedsUpdateTextFrame()
            } else if newValue != oldFrame {
                setNeedsLayout()
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
            let oldWidth = layoutWidth
            let oldBounds = bounds

            super.bounds = newValue

            if layoutWidth != oldWidth {
                setNeedsUpdateTextFrame()
            } else if newValue != oldBounds {
                setNeedsLayout()
            }
        }
    }

    /// The custom distance that the content view is inset from the safe area or scroll view edges.
    open override var contentInset: UIEdgeInsets {
        get {
            return super.contentInset
        }
        set {
            let oldWidth = layoutWidth
            let oldInset = contentInset

            super.contentInset = newValue

            if layoutWidth != oldWidth {
                setNeedsUpdateTextFrame()
            } else if newValue != oldInset {
                setNeedsLayout()
            }
        }
    }

    private var visibleRect: CGRect {
        return CGRect(origin: contentOffset, size: bounds.size)
    }

    private var layoutWidth: CGFloat {
        return bounds.width - (contentInset.left + contentInset.right)
    }

    /// Lays out subviews.
    open override func layoutSubviews() {
        super.layoutSubviews()

        if needsTextLayout {
            performTextLayout()
        }

        layoutLines()
    }

    private func removeAllLineViews() {
        for view in subviews {
            if view is LineView {
                view.removeFromSuperview()
            }
        }
    }

    private func performTextLayout() {
        let context = TextContext()
        context.layoutID = layoutID
        context.renderScale = renderScale
        context.layoutWidth = layoutWidth
        context.typeface = typeface
        context.text = text
        context.attributedText = attributedText
        context.textSize = textSize
        context.textAlignment = textAlignment
        context.textColor = textColor
        context.extraLineSpacing = extraLineSpacing
        context.lineHeightMultiplier = lineHeightMultiplier
        context.typesetter = typesetter

        var operations: [Operation] = []
        var typesettingOperation: TypesettingOperation? = nil

        if !isTypesetterResolved {
            typesettingOperation = TypesettingOperation(context) { (typesetter) in
                self.updateTypesetter(typesetter, identifying: context.layoutID)
            }
            typesettingOperation?.qualityOfService = .userInitiated

            operations.append(typesettingOperation!)
        }

        let frameResolvingOperation = FrameResolvingOperation(context) { (textFrame) in
            self.updateTextFrame(textFrame, identifying: context.layoutID)
        }
        frameResolvingOperation.qualityOfService = .userInitiated

        if let typesettingOperation = typesettingOperation {
            frameResolvingOperation.addDependency(typesettingOperation)
        }

        operations.append(frameResolvingOperation)

        let lineBoxesOperation = LineBoxesOperation(context) { (lineBoxes) in
            self.updateLineBoxes(lineBoxes, identifying: context.layoutID)
        }
        lineBoxesOperation.qualityOfService = .userInteractive
        lineBoxesOperation.addDependency(frameResolvingOperation)

        operations.append(lineBoxesOperation)

        operationQueue.addOperations(operations, waitUntilFinished: false)
        needsTextLayout = false
    }

    private func updateTypesetter(_ typesetter: Typesetter?, identifying layoutID: NSObject) {
        guard layoutID === self.layoutID else { return }

        isTypesetterResolved = true
        _typesetter = typesetter
    }

    private func updateTextFrame(_ textFrame: ComposedFrame?, identifying layoutID: NSObject) {
        guard layoutID === self.layoutID else { return }

        isTextFrameResolved = true
        _textFrame = textFrame

        lineBoxes = []
        lineViews = []
        removeAllLineViews()

        if let textFrame = textFrame {
            contentSize = CGSize(width: textFrame.width, height: textFrame.height)
        } else {
            contentSize = .zero
        }

        let insets: UIEdgeInsets

        if #available(iOS 11.0, *) {
            insets = adjustedContentInset
        } else {
            insets = contentInset
        }

        contentOffset = CGPoint(x: -insets.left, y: -insets.top)
    }

    private func updateLineBoxes(_ array: [CGRect], identifying layoutID: NSObject) {
        guard layoutID === self.layoutID else { return }

        lineBoxes = array
        setNeedsLayout()
    }

    private func layoutLines() {
        guard let textFrame = textFrame else {
            return
        }

        let scrollRect = visibleRect

        insideViews.removeAll()
        outsideViews.removeAll()

        // Get outside and inside line views.
        for lineView in lineViews {
            if lineView.frame.intersects(scrollRect) {
                insideViews.append(lineView)
            } else {
                outsideViews.append(lineView)
            }
        }

        visibleIndexes.removeAll()

        // Get line indexes that should be visible.
        for i in 0 ..< lineBoxes.count {
            if lineBoxes[i].intersects(scrollRect) {
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
                insertSubview(lineView, aboveSubview: previousView)
            } else {
                addSubview(lineView)
            }

            previousView = lineView
        }
    }

    private func updateLineColors() {
        for lineView in lineViews {
            let renderer = lineView.renderer
            renderer.fillColor = textColor

            lineView.setNeedsDisplay()
        }
    }

    private func setNeedsUpdateTypesetter() {
        isTypesetterResolved = isTypesetterUserDefined
        setNeedsUpdateTextFrame()
    }

    private func setNeedsUpdateTextFrame() {
        isTextFrameResolved = false
        setNeedsTextLayout()
    }

    private func setNeedsTextLayout() {
        operationQueue.cancelAllOperations()
        layoutID = NSObject()
        needsTextLayout = true

        setNeedsLayout()
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

    /// The composed frame being displayed.
    open var textFrame: ComposedFrame? {
        return isTextFrameResolved ? _textFrame : nil
    }

    /// The text alignment to apply on each line. Its default value is `.intrinsic`.
    open var textAlignment: TextAlignment = .intrinsic {
        didSet {
            setNeedsUpdateTextFrame()
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
            return isTypesetterResolved ? _typesetter : nil
        }
        set {
            _text = nil
            _attributedText = nil
            _typesetter = newValue
            isTypesetterUserDefined = true

            setNeedsUpdateTypesetter()
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
            isTypesetterUserDefined = false

            setNeedsUpdateTypesetter()
        }
    }

    /// The typeface in which the text is displayed.
    open var typeface: Typeface? {
        didSet {
            setNeedsUpdateTypesetter()
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
            isTypesetterUserDefined = false

            setNeedsUpdateTypesetter()
        }
    }

    /// The default size of the text.
    open var textSize: CGFloat = 16.0 {
        didSet {
            setNeedsUpdateTypesetter()
        }
    }

    /// The default color of the text.
    open var textColor: UIColor = .black {
        didSet {
            updateLineColors()
        }
    }

    /// The extra spacing that is added after each text line. It is resolved before line height
    /// multiplier. Its default value is zero.
    open var extraLineSpacing: CGFloat = .zero {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    /// The height multiplier that is applied on each text line. It is resolved after extra line
    /// spacing. Its default value is one.
    ///
    /// The additional spacing is adjusted in such a way that text remains in the middle of the
    /// line.
    open var lineHeightMultiplier: CGFloat = 1.0 {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }
}
