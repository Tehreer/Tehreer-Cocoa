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

private class TextData {
    weak var textView: TTextView?
    var typesetter: Typesetter?
    var textFrame: ComposedFrame?
}

private class TypesettingOperation: Operation {
    private let data: TextData

    init(data: TextData) {
        self.data = data
    }

    override func main() {
        guard let params = data.textView?.typesetterParams(),
              !isCancelled else {
            return
        }

        data.typesetter = Typesetter(text: params.text, defaultAttributes: params.defaultAttributes)
    }
}

private class FrameResolvingOperation: Operation {
    private let data: TextData

    init(data: TextData) {
        self.data = data
    }

    override func main() {
        guard let typesetter = data.typesetter,
              let resolver = data.textView?.frameResolver(for: typesetter),
              !isCancelled else {
            return
        }

        let string = typesetter.text.string
        data.textFrame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)
    }
}

private class LineBoxesOperation: Operation {
    private let data: TextData
    private let updateBlock: (([CGRect]) -> Void)?

    init(data: TextData, updateBlock: (([CGRect]) -> Void)?) {
        self.data = data
        self.updateBlock = updateBlock
    }

    override func main() {
        guard let lines = data.textFrame?.lines,
              let renderer = data.textView?.boxRenderer(),
              !isCancelled else {
            return
        }

        var lineCount = 0
        var lineBoxes: [CGRect] = []

        for textLine in lines {
            defer {
                lineCount += 1
            }

            var boundingBox = textLine.computeBoundingBox(with: renderer)
            boundingBox = boundingBox.offsetBy(dx: textLine.origin.x, dy: textLine.origin.y)

            lineBoxes.append(boundingBox)

            if isCancelled {
                return
            }

            if lineCount == 32 {
                DispatchQueue.main.async {
                    self.updateBlock?(lineBoxes)
                }
            }
        }

        DispatchQueue.main.async {
            if !self.isCancelled {
                self.updateBlock?(lineBoxes)
            }
        }
    }
}

open class TTextView: UIScrollView {
    private let lock = NSRecursiveLock()
    private let operationQueue = OperationQueue()

    private let renderer = Renderer()
    private let resolver = FrameResolver()

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?

    private var needsTypesetter: Bool = false
    private(set) open var textFrame: ComposedFrame? = nil

    private var layoutWidth: CGFloat = .zero

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

        resolver.fitsHorizontally = false
        resolver.fitsVertically = true
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
            updateLayoutWidth()

            if layoutWidth != oldWidth {
                deferNeedsTextLayout()
            } else if newValue != oldFrame {
                layoutLines()
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
            updateLayoutWidth()

            if layoutWidth != oldWidth {
                deferNeedsTextLayout()
            } else if newValue != oldBounds {
                layoutLines()
            }
        }
    }

    open override var contentOffset: CGPoint {
        didSet(value) {
            layoutLines()
        }
    }

    open override var contentInset: UIEdgeInsets {
        get {
            return super.contentInset
        }
        set {
            let oldWidth = layoutWidth
            let oldInset = contentInset

            super.contentInset = newValue
            updateLayoutWidth()

            if layoutWidth != oldWidth {
                deferNeedsTextLayout()
            } else if newValue != oldInset {
                layoutLines()
            }
        }
    }

    private var visibleRect: CGRect {
        return CGRect(origin: contentOffset, size: bounds.size)
    }

    private func updateLayoutWidth() {
        layoutWidth = bounds.width - (contentInset.left + contentInset.right)
    }

    private func removeAllLineViews() {
        for view in subviews {
            if view is LineView {
                view.removeFromSuperview()
            }
        }
    }

    private func deferNeedsTextLayout() {
        lock.lock()
        defer { lock.unlock() }

        let data = TextData()
        data.textView = self
        data.typesetter = _typesetter

        var operations: [Operation] = []
        var typesettingOperation: TypesettingOperation? = nil

        if _typesetter == nil {
            typesettingOperation = TypesettingOperation(data: data)
            typesettingOperation?.qualityOfService = .userInitiated
            typesettingOperation?.completionBlock = {
                DispatchQueue.main.async {
                    self._typesetter = data.typesetter
                }
            }

            operations.append(typesettingOperation!)
        }

        let frameResolvingOperation = FrameResolvingOperation(data: data)
        frameResolvingOperation.qualityOfService = .userInitiated
        frameResolvingOperation.completionBlock = {
            guard let textFrame = data.textFrame else {
                return
            }

            DispatchQueue.main.async {
                self.textFrame = textFrame
                self.contentSize = CGSize(width: textFrame.width, height: textFrame.height)
            }
        }
        if let typesettingOperation = typesettingOperation {
            frameResolvingOperation.addDependency(typesettingOperation)
        }

        operations.append(frameResolvingOperation)

        let lineBoxesOperation = LineBoxesOperation(data: data) { (lineBoxes) in
            self.lineBoxes = lineBoxes
            self.layoutLines()
        }
        lineBoxesOperation.qualityOfService = .userInteractive
        lineBoxesOperation.addDependency(frameResolvingOperation)

        operations.append(lineBoxesOperation)

        operationQueue.cancelAllOperations()
        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    fileprivate func typesetterParams() -> (text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any])? {
        lock.lock()
        defer { lock.unlock() }

        if let string = text {
            if let typeface = typeface, !string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize]

                return (NSAttributedString(string: string), defaultAttributes)
            }
        } else if let attributedText = attributedText {
            if let typeface = typeface, !attributedText.string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize]

                return (attributedText, defaultAttributes)
            }
        }

        return nil
    }

    fileprivate func frameResolver(for typesetter: Typesetter) -> FrameResolver {
        lock.lock()
        defer { lock.unlock() }

        let copy = FrameResolver()
        copy.typesetter = typesetter
        copy.frameBounds = CGRect(x: .zero, y: .zero, width: layoutWidth, height: .greatestFiniteMagnitude)
        copy.fitsHorizontally = resolver.fitsHorizontally
        copy.fitsVertically = resolver.fitsVertically
        copy.textAlignment = resolver.textAlignment
        copy.verticalAlignment = resolver.verticalAlignment
        copy.truncationMode = resolver.truncationMode
        copy.truncationPlace = resolver.truncationPlace
        copy.maxLines = resolver.maxLines
        copy.extraLineSpacing = resolver.extraLineSpacing
        copy.lineHeightMultiplier = resolver.lineHeightMultiplier

        return copy
    }

    fileprivate func boxRenderer() -> Renderer {
        lock.lock()
        defer { lock.unlock() }

        let copy = Renderer()
        copy.typeface = typeface
        copy.typeSize = textSize
        copy.fillColor = textColor
        copy.renderScale = renderScale

        return copy
    }

    private func layoutLines() {
        guard let textFrame = textFrame else {
            return
        }

        let scrollRect = visibleRect

        var outsideViews: [LineView] = []
        var insideViews: [LineView] = []

        // Get outside and inside line views.
        for lineView in lineViews {
            if lineView.frame.intersects(scrollRect) {
                insideViews.append(lineView)
            } else {
                outsideViews.append(lineView)
            }
        }

        var visibleIndexes: [Int] = []

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

    private func updateTypesetter() {
        if needsTypesetter {
            return
        }

        _typesetter = nil
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
