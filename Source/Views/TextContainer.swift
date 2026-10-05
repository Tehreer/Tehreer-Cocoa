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

import Foundation
import UIKit

/// A character, and how far the top of the screen is below the top of its line.
private struct Anchor {
    let codeUnitIndex: Int
    let offset: CGFloat
}

/// The content view of a `TTextView`. It resolves the text in the background and hosts the line
/// views, the views of the attachments and the highlight of a pressed link.
final class TextContainer: UIView {
    weak var textView: TTextView!

    let highlightView = LinkHighlightView()
    let linkRecognizer = LinkInteractionRecognizer()

    private let operationQueue = OperationQueue()
    private var layoutID: NSObject!
    private var needsTextLayout = false

    private(set) var isTypesetterUserDefined = false
    private var isTypesetterResolved = false
    private var isTextFrameResolved = false

    private var _text: String!
    private var _attributedText: NSAttributedString!
    private var _typesetter: Typesetter?

    private(set) var displayedFrame: ComposedFrame?
    private var lineBoxes = LineBoxes()

    private var pendingFrame: ComposedFrame?
    private var isSwapPending = false
    private var isPendingSwapFirstLoad = false

    private var isTextNew = true
    private var pendingAnchor: Anchor?
    private var pendingScrollCodeUnitIndex = -1

    private var lineViewsByIndex: [LineView?] = []
    private var attachedLineViews: [LineView] = []
    private var reusableLineViews: [LineView] = []

    var attachedViewAttachments: [ViewAttachment] = []
    var viewSlots: [AttachmentSlot] = []
    var measuredViews: [ObjectIdentifier: UIView] = [:]
    var resizingAttachments = Set<ObjectIdentifier>()
    var isFrameFresh = false

    private var renderScale: CGFloat = 1.0

    var viewAttachmentPrefetchDistance: CGFloat = .zero

    var isLinkInteractionEnabled: Bool = true {
        didSet {
            if !isLinkInteractionEnabled {
                linkRecognizer.cancelInteraction()
            }
        }
    }

    var highlightColor: UIColor = UIColor(red: 0.2, green: 0.71, blue: 0.9, alpha: 0.4) {
        didSet {
            highlightView.fillColor = highlightColor
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        renderScale = UIScreen.main.scale
        backgroundColor = .clear

        highlightView.fillColor = highlightColor
        addSubview(highlightView)

        linkRecognizer.addTarget(self, action: #selector(linkInteractionRecognized))
        addGestureRecognizer(linkRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var layoutWidth: CGFloat {
        guard let textView = textView else { return .zero }

        let inset = textView.contentInset
        return textView.bounds.width - (inset.left + inset.right)
    }

    var visibleRect: CGRect {
        guard let textView = textView else { return .zero }

        return CGRect(origin: textView.contentOffset, size: textView.bounds.size)
    }

    var isDecelerating: Bool {
        return textView.isDecelerating
    }

    var layoutWidthForAttachments: CGFloat {
        return layoutWidth
    }

    var textViewDelegate: TTextViewDelegate? {
        return textView.textViewDelegate
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        highlightView.frame = bounds
    }

    func layoutContent() {
        if needsTextLayout {
            performTextLayout()
        }

        layoutLines()
        layoutViewAttachments()
    }

    func layoutWidthDidChange(from oldWidth: CGFloat) {
        if layoutWidth != oldWidth {
            setNeedsUpdateTextFrame()
        } else {
            textView?.setNeedsLayout()
        }
    }

    // MARK: - Text Layout

    private func performTextLayout() {
        measureViewAttachments()

        let context = TextLayoutContext()
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
        context.isJustificationEnabled = isJustificationEnabled
        context.justificationLevel = justificationLevel
        context.renderingStyle = renderingStyle
        context.strokeColor = strokeColor
        context.strokeWidth = strokeWidth
        context.strokeCap = strokeCap
        context.strokeJoin = strokeJoin
        context.strokeMiter = strokeMiter
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

    /// The frame resolves well before its line boxes, and is only displayed once they are ready,
    /// so a line view never appears before its own text.
    private func updateTextFrame(_ textFrame: ComposedFrame?, identifying layoutID: NSObject) {
        guard layoutID === self.layoutID else { return }

        isTextFrameResolved = true

        if isTextNew {
            pendingFrame = textFrame
            isSwapPending = true
            isPendingSwapFirstLoad = true

            isTextNew = false

            if pendingScrollCodeUnitIndex >= 0 {
                pendingAnchor = Anchor(codeUnitIndex: pendingScrollCodeUnitIndex, offset: .nan)
            }
            pendingScrollCodeUnitIndex = -1
        } else {
            pendingAnchor = pendingAnchor ?? captureAnchor()
            pendingFrame = textFrame
            isPendingSwapFirstLoad = isSwapPending ? isPendingSwapFirstLoad : false
            isSwapPending = true
        }
    }

    private func updateLineBoxes(_ lineBoxes: LineBoxes, identifying layoutID: NSObject) {
        guard layoutID === self.layoutID, textView != nil else { return }

        self.lineBoxes = lineBoxes

        guard isSwapPending else {
            textView.setNeedsLayout()
            return
        }

        let isFirstLoad = isPendingSwapFirstLoad

        isSwapPending = false
        isPendingSwapFirstLoad = false

        displayedFrame = pendingFrame
        pendingFrame = nil

        recycleLineViews()

        viewSlots = displayedFrame.map { resolveViewSlots(in: $0) } ?? []
        detachOrphanViews()
        isFrameFresh = true

        let contentSize = displayedFrame.map { CGSize(width: $0.width, height: $0.height) } ?? .zero
        textView.contentSize = contentSize
        frame = CGRect(origin: .zero, size: contentSize)

        if isFirstLoad {
            let inset = textView.adjustedContentInset
            textView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
        }

        if let anchor = pendingAnchor {
            pendingAnchor = nil

            if let frame = displayedFrame {
                scrollToAnchor(in: frame, anchor, animated: false)
            }
        }

        textView.setNeedsLayout()
    }

    private func markTextNew() {
        isTextNew = true
        pendingScrollCodeUnitIndex = -1
        pendingAnchor = nil

        pendingFrame = nil
        isSwapPending = false
        isPendingSwapFirstLoad = false
    }

    private func setNeedsUpdateTypesetter() {
        isTypesetterResolved = isTypesetterUserDefined
        setNeedsUpdateTextFrame()
    }

    func setNeedsUpdateTextFrame() {
        isTextFrameResolved = false

        operationQueue.cancelAllOperations()
        layoutID = NSObject()
        needsTextLayout = true

        textView?.setNeedsLayout()
    }

    // MARK: - Line Views

    private func layoutLines() {
        guard let textFrame = displayedFrame else {
            return
        }

        let lineBoxes = self.lineBoxes
        let visibleRect = self.visibleRect

        var attachedIndex = attachedLineViews.count - 1

        while attachedIndex >= 0 {
            let lineView = attachedLineViews[attachedIndex]

            if !lineBoxes.boxes[lineView.lineIndex].intersects(visibleRect) {
                lineViewsByIndex[lineView.lineIndex] = nil
                attachedLineViews.swapAt(attachedIndex, attachedLineViews.count - 1)
                attachedLineViews.removeLast()
                enqueueReusableLineView(lineView)
            }

            attachedIndex -= 1
        }

        lineBoxes.enumerateLineIndexes(intersecting: visibleRect) { lineIndex in
            guard lineViewsByIndex[lineIndex] == nil else {
                return
            }

            let lineView = dequeueReusableLineView()
            lineView.lineIndex = lineIndex
            lineView.line = textFrame.lines[lineIndex]
            lineView.frame = lineBoxes.boxes[lineIndex]
            configure(lineView)

            insertSubview(lineView, aboveSubview: highlightView)
            lineViewsByIndex[lineIndex] = lineView
            attachedLineViews.append(lineView)
        }
    }

    private func recycleLineViews() {
        for lineView in attachedLineViews {
            enqueueReusableLineView(lineView)
        }

        attachedLineViews.removeAll(keepingCapacity: true)
        lineViewsByIndex = Array(repeating: nil, count: displayedFrame?.lines.count ?? 0)
    }

    private func dequeueReusableLineView() -> LineView {
        if let lineView = reusableLineViews.popLast() {
            return lineView
        }

        let lineView = LineView()
        lineView.backgroundColor = .clear

        return lineView
    }

    private func enqueueReusableLineView(_ lineView: LineView) {
        lineView.removeFromSuperview()
        reusableLineViews.append(lineView)
    }

    private func configure(_ lineView: LineView) {
        updateRenderer(lineView.renderer)
        lineView.layoutWidth = bounds.width
        lineView.separatorColor = separatorColor
    }

    private func updateRenderer(_ renderer: Renderer) {
        renderer.fillColor = textColor
        renderer.renderingStyle = renderingStyle
        if let typeface = typeface {
            renderer.typeface = typeface
        }
        renderer.typeSize = textSize
        renderer.renderScale = renderScale
        renderer.strokeColor = strokeColor
        renderer.strokeWidth = strokeWidth
        renderer.strokeCap = strokeCap
        renderer.strokeJoin = strokeJoin
        renderer.strokeMiter = strokeMiter
    }

    private func updateLineViews() {
        for lineView in attachedLineViews {
            configure(lineView)
            lineView.setNeedsDisplay()
        }
    }

    // MARK: - Scrolling

    /// The first line that reaches below `top`, or the last one if it is further up.
    private func firstVisibleLineIndex(in frame: ComposedFrame, below top: CGFloat) -> Int {
        let lines = frame.lines

        if let lineIndex = lineBoxes.firstLineIndex(below: top, where: { lines[$0].bottom > top }) {
            return lineIndex
        }

        let unboxedIndexes = lineBoxes.boxes.count ..< lines.count

        return unboxedIndexes.first { lines[$0].bottom > top } ?? lines.count - 1
    }

    private func captureAnchor() -> Anchor? {
        guard let frame = displayedFrame, !frame.lines.isEmpty else {
            return nil
        }

        let top = visibleRect.minY
        let line = frame.lines[firstVisibleLineIndex(in: frame, below: top)]

        return Anchor(codeUnitIndex: line.codeUnitRange.lowerBound, offset: top - line.top)
    }

    private func scrollToAnchor(in frame: ComposedFrame, _ anchor: Anchor, animated: Bool) {
        guard !frame.lines.isEmpty else { return }

        let codeUnitRange = frame.codeUnitRange
        let codeUnitIndex = min(max(anchor.codeUnitIndex, codeUnitRange.lowerBound), codeUnitRange.upperBound - 1)

        let lineIndex = frame.indexOfLine(forCodeUnitAt: codeUnitIndex)
        guard lineIndex >= 0 else { return }

        let line = frame.lines[lineIndex]
        let inset = textView.adjustedContentInset

        let offset = anchor.offset.isNaN ? -inset.top : anchor.offset

        let minimumY = -inset.top
        let maximumY = max(minimumY, textView.contentSize.height + inset.bottom - textView.bounds.height)
        let targetY = min(max(line.top + offset, minimumY), maximumY)

        textView.setContentOffset(CGPoint(x: textView.contentOffset.x, y: targetY), animated: animated)
    }

    var firstVisibleCodeUnitIndex: Int? {
        guard let textFrame = textFrame, !textFrame.lines.isEmpty else {
            return nil
        }

        let top = textView.contentOffset.y + textView.adjustedContentInset.top + 0.5

        return textFrame.lines[firstVisibleLineIndex(in: textFrame, below: top)].codeUnitRange.lowerBound
    }

    func scrollToCodeUnit(at index: Int, animated: Bool) {
        let anchor = Anchor(codeUnitIndex: max(index, 0), offset: .nan)

        if isSwapPending || (displayedFrame != nil && !isTextFrameResolved) {
            pendingAnchor = anchor
        } else if let frame = displayedFrame {
            scrollToAnchor(in: frame, anchor, animated: animated)
        } else {
            pendingScrollCodeUnitIndex = anchor.codeUnitIndex
        }
    }

    // MARK: - Hit Testing

    func indexOfCharacter(at position: CGPoint) -> String.Index? {
        guard let textFrame = textFrame, !textFrame.lines.isEmpty else {
            return nil
        }

        let textLine = textFrame.lines.first { position.y <= $0.bottom } ?? textFrame.lines[textFrame.lines.count - 1]

        return indexOfCharacter(in: textLine, at: position.x, in: textFrame)
    }

    /// The UTF-16 index of the character that is exactly under the position, which is what a
    /// touch is matched with.
    func indexOfCodeUnitUnderPosition(_ position: CGPoint) -> Int? {
        guard let textFrame = textFrame,
              let textLine = textFrame.lines.first(where: { position.y >= $0.top && position.y <= $0.bottom }),
              let characterIndex = indexOfCharacter(in: textLine, at: position.x, in: textFrame) else {
            return nil
        }

        // The nearest index is the one after the character when the position is on its trailing
        // half, so the character is the one whose box has the position.
        let nearestIndex = textFrame.string.utf16Index(forCharacterAt: characterIndex)

        for codeUnitIndex in [nearestIndex, nearestIndex - 1] where textLine.codeUnitRange.contains(codeUnitIndex) {
            let rects = selectionRects(forCodeUnitRange: codeUnitIndex ..< codeUnitIndex + 1)

            if rects.contains(where: { $0.contains(position) }) {
                return codeUnitIndex
            }
        }

        return nil
    }

    private func indexOfCharacter(in textLine: ComposedLine, at x: CGFloat, in textFrame: ComposedFrame) -> String.Index? {
        let lineLeft = textLine.origin.x
        let lineRight = lineLeft + textLine.width

        guard x >= lineLeft && x <= lineRight else {
            return nil
        }

        let characterIndex = textLine.indexOfCharacter(at: x - lineLeft)
        let lastIndex = textFrame.string.index(before: textLine.endIndex)

        return min(characterIndex, lastIndex)
    }

    // MARK: - Properties

    /// The displayed frame, once it is the one of the current properties.
    var textFrame: ComposedFrame? {
        return isTextFrameResolved ? displayedFrame : nil
    }

    var textAlignment: TextAlignment = .leading {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    var typesetter: Typesetter? {
        get {
            return isTypesetterResolved ? _typesetter : nil
        }
        set {
            _text = nil
            _attributedText = nil
            _typesetter = newValue
            isTypesetterUserDefined = true

            markTextNew()
            setNeedsUpdateTypesetter()
        }
    }

    var attributedText: NSAttributedString! {
        get {
            return _attributedText
        }
        set {
            _text = nil
            _attributedText = newValue
            isTypesetterUserDefined = false

            markTextNew()
            setNeedsUpdateTypesetter()
        }
    }

    var text: String! {
        get {
            return _text
        }
        set {
            _text = newValue ?? ""
            _attributedText = nil
            isTypesetterUserDefined = false

            markTextNew()
            setNeedsUpdateTypesetter()
        }
    }

    var typeface: Typeface? {
        didSet {
            setNeedsUpdateTypesetter()
        }
    }

    var textSize: CGFloat = 16.0 {
        didSet {
            setNeedsUpdateTypesetter()
        }
    }

    var textColor: UIColor = .black {
        didSet {
            updateLineViews()
        }
    }

    var extraLineSpacing: CGFloat = .zero {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    var lineHeightMultiplier: CGFloat = 1.0 {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    var isJustificationEnabled: Bool = false {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    var justificationLevel: CGFloat = 1.0 {
        didSet {
            setNeedsUpdateTextFrame()
        }
    }

    var renderingStyle: Renderer.RenderingStyle = .fill {
        didSet {
            updateLineViews()
        }
    }

    var strokeColor: UIColor = .black {
        didSet {
            updateLineViews()
        }
    }

    var strokeWidth: CGFloat = 1.0 {
        didSet {
            updateLineViews()
        }
    }

    var strokeCap: Renderer.StrokeCap = .butt {
        didSet {
            updateLineViews()
        }
    }

    var strokeJoin: Renderer.StrokeJoin = .round {
        didSet {
            updateLineViews()
        }
    }

    var strokeMiter: CGFloat = 1.0 {
        didSet {
            updateLineViews()
        }
    }

    var separatorColor: UIColor? {
        didSet {
            updateLineViews()
        }
    }
}
