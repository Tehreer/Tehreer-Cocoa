//
// Copyright (C) 2021-2026 Muhammad Tayyab Akram
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

/// A scrollable, multiline text region.
open class TTextView: UIScrollView {
    let container = TextContainer()

    /// How far above and below the screen, in points, a `ViewAttachment`'s view is made,
    /// attached and laid out, rather than only once its line reaches the screen. The default
    /// value is 0, which is the screen only.
    open var viewAttachmentPrefetchDistance: CGFloat {
        get { return container.viewAttachmentPrefetchDistance }
        set { container.viewAttachmentPrefetchDistance = newValue }
    }

    /// The delegate that decides what happens when a link or a replacement of the text is
    /// tapped. It is named so, and not `delegate`, as that belongs to `UIScrollView`.
    open weak var textViewDelegate: TTextViewDelegate?

    /// A boolean value that indicates whether the links of the text, the ones with a `.link`
    /// attribute, respond to a tap. When they do, a link is highlighted while it is pressed and,
    /// when the finger is lifted, `textViewDelegate` is asked, and a link is opened unless it
    /// says otherwise. Its default value is `true`.
    open var isLinkInteractionEnabled: Bool {
        get { return container.isLinkInteractionEnabled }
        set { container.isLinkInteractionEnabled = newValue }
    }

    /// The color that a link is highlighted with while it is pressed. It is drawn behind the
    /// text, so it should be translucent. Its default value is a translucent blue.
    open var highlightColor: UIColor {
        get { return container.highlightColor }
        set { container.highlightColor = newValue }
    }

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
        container.textView = self
        addSubview(container)
    }

    /// The frame rectangle, which describes the view’s location and size in its superview’s
    /// coordinate system.
    open override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let oldWidth = container.layoutWidth
            super.frame = newValue
            container.layoutWidthDidChange(from: oldWidth)
        }
    }

    /// The bounds rectangle, which describes the view’s location and size in its own coordinate
    /// system.
    open override var bounds: CGRect {
        get {
            return super.bounds
        }
        set {
            let oldWidth = container.layoutWidth
            super.bounds = newValue
            container.layoutWidthDidChange(from: oldWidth)
        }
    }

    /// The custom distance that the content view is inset from the safe area or scroll view edges.
    open override var contentInset: UIEdgeInsets {
        get {
            return super.contentInset
        }
        set {
            let oldWidth = container.layoutWidth
            super.contentInset = newValue
            container.layoutWidthDidChange(from: oldWidth)
        }
    }

    /// Lays out subviews.
    open override func layoutSubviews() {
        super.layoutSubviews()
        container.layoutContent()
    }

    /// Returns the UTF-16 index representing the specified position: the one of the nearest line,
    /// which is found even above the first line or below the last one. It returns `nil` if there
    /// is no text, or if the position is on the left or on the right of the text of that line.
    ///
    /// The position is in the coordinate system of this view, which is what the location of a
    /// touch gives; scroll and insets are taken care of.
    ///
    /// - Parameter position: The position for which to determine the UTF-16 index.
    open func indexOfCodeUnit(at position: CGPoint) -> Int? {
        return container.indexOfCharacter(at: position).flatMap {
            textFrame?.string.utf16Index(forCharacterAt: $0)
        }
    }

    /// Returns the index of character representing the specified position: the one of the nearest
    /// line, which is found even above the first line or below the last one. It returns `nil` if
    /// there is no text, or if the position is on the left or on the right of the text of that
    /// line.
    ///
    /// - Parameter position: The position for which to determine the character index.
    open func indexOfCharacter(at position: CGPoint) -> String.Index? {
        return container.indexOfCharacter(at: position)
    }

    /// The UTF-16 index of the first character of the first line that is on the screen, or `nil`
    /// if no text is displayed. Together with `scrollToCodeUnit(at:animated:)` it saves and
    /// restores the place where the reader is.
    ///
    /// When the lines are made again, the text view keeps what is on the screen where it is. A
    /// new text starts at the top.
    open var firstVisibleCodeUnitIndex: Int? {
        return container.firstVisibleCodeUnitIndex
    }

    /// The index of the first character of the first line that is on the screen, or `nil` if no
    /// text is displayed.
    open var firstVisibleCharacterIndex: String.Index? {
        return firstVisibleCodeUnitIndex.flatMap {
            textFrame?.string.characterIndex(forUTF16Index: $0)
        }
    }

    /// Scrolls so that the line with the specified UTF-16 code unit is at the top of the text. If
    /// the text is not displayed yet, the scroll is done as soon as it is, instead of the scroll
    /// to the top that a new text gets.
    ///
    /// - Parameters:
    ///   - index: The index of a UTF-16 code unit.
    ///   - animated: Whether to scroll smoothly. It is ignored while the text is not displayed.
    open func scrollToCodeUnit(at index: Int, animated: Bool) {
        container.scrollToCodeUnit(at: index, animated: animated)
    }

    /// Scrolls so that the line with the specified character is at the top of the text.
    ///
    /// - Parameters:
    ///   - index: The index of a character.
    ///   - animated: Whether to scroll smoothly. It is ignored while the text is not displayed.
    open func scrollToCharacter(at index: String.Index, animated: Bool) {
        let string = textFrame?.string ?? (typesetter?.text.string ?? text ?? attributedText?.string ?? "")

        scrollToCodeUnit(at: string.utf16Index(forCharacterAt: index), animated: animated)
    }

    /// Returns the rectangles that the specified UTF-16 code unit range covers, one for each line
    /// it occupies, in the coordinate system of this view, which is the one that the location of
    /// a touch uses. They follow the convention of a text selection: when the range continues
    /// over several lines, the first rectangle goes on to the edge of the text, and the last one
    /// starts from the other edge.
    ///
    /// The rectangles are returned even if they are scrolled out of the view. An empty array is
    /// returned when the range is not in the displayed text or the text is not laid out yet.
    ///
    /// - Parameter codeUnitRange: The range of UTF-16 code units in source string.
    /// - Returns: The rectangles that the range covers, in the order of the lines.
    public func selectionRects(forCodeUnitRange codeUnitRange: Range<Int>) -> [CGRect] {
        return container.selectionRects(forCodeUnitRange: codeUnitRange)
    }

    /// Returns the rectangles that the specified character range covers. See
    /// `selectionRects(forCodeUnitRange:)`.
    ///
    /// - Parameter characterRange: The range of characters in source string.
    /// - Returns: The rectangles that the range covers, in the order of the lines.
    public func selectionRects(forCharacterRange characterRange: Range<String.Index>) -> [CGRect] {
        return container.selectionRects(forCharacterRange: characterRange)
    }

    /// Returns the rectangles that the specified replacement covers, in the coordinate system of
    /// this view: the box that it draws in, or the room of the view of a `ViewAttachment`.
    ///
    /// The rectangles are returned even if they are scrolled out of the view. An empty array is
    /// returned when the replacement is not in the displayed text or the text is not laid out yet.
    ///
    /// - Parameter replacement: A replacement of the text being displayed.
    /// - Returns: The rectangles that the replacement covers, in the order of the lines.
    public func rects(for replacement: TextReplacement) -> [CGRect] {
        return container.rects(for: replacement)
    }

    /// Returns the smallest rectangle that covers the specified replacement in the coordinate
    /// system of this view.
    ///
    /// - Parameter replacement: A replacement of the text being displayed.
    /// - Returns: The bounds of the replacement, or `nil` if the replacement is not in the
    ///            displayed text or the text is not laid out yet.
    ///
    /// - SeeAlso: `rects(for:)`
    public func boundingRect(for replacement: TextReplacement) -> CGRect? {
        return container.boundingRect(for: replacement)
    }

    /// The composed frame being displayed.
    open var textFrame: ComposedFrame? {
        return container.textFrame
    }

    /// The text alignment to apply on each line. Its default value is `.leading`.
    open var textAlignment: TextAlignment {
        get { return container.textAlignment }
        set { container.textAlignment = newValue }
    }

    /// The typesetter that is used to compose text lines.
    ///
    /// Setting this property will make `text` and `attributedText` properties `nil`.
    ///
    /// A typesetter is preferred over `attributedText` as it avoids an extra step of creating the typesetter
    /// from the `attributedText`.
    open var typesetter: Typesetter? {
        get { return container.typesetter }
        set { container.typesetter = newValue }
    }

    /// The current styled text that is displayed by the label.
    ///
    /// This property will be `nil` if either `text` or `typesetter` is being used instead. Setting
    /// this property will make `text` property `nil`.
    ///
    /// If performance is required, a typesetter should be used directly.
    open var attributedText: NSAttributedString! {
        get { return container.attributedText }
        set { container.attributedText = newValue }
    }

    /// The current text that is displayed by the label.
    ///
    /// This property will be `nil` if either `attributedText` or `typesetter` is being used
    /// instead. Setting this property will make `text` property `nil`.
    ///
    /// If performance is required, a typesetter should be used directly.
    open var text: String! {
        get { return container.text }
        set { container.text = newValue }
    }

    /// The typeface in which the text is displayed.
    open var typeface: Typeface? {
        get { return container.typeface }
        set { container.typeface = newValue }
    }

    /// The default size of the text.
    open var textSize: CGFloat {
        get { return container.textSize }
        set { container.textSize = newValue }
    }

    /// The default color of the text.
    open var textColor: UIColor {
        get { return container.textColor }
        set { container.textColor = newValue }
    }

    /// The extra spacing that is added after each text line. It is resolved before line height
    /// multiplier. Its default value is zero.
    open var extraLineSpacing: CGFloat {
        get { return container.extraLineSpacing }
        set { container.extraLineSpacing = newValue }
    }

    /// The height multiplier that is applied on each text line. It is resolved after extra line
    /// spacing. Its default value is one.
    ///
    /// The additional spacing is adjusted in such a way that text remains in the middle of the
    /// line.
    open var lineHeightMultiplier: CGFloat {
        get { return container.lineHeightMultiplier }
        set { container.lineHeightMultiplier = newValue }
    }

    /// A boolean value that indicates whether or not to justify the text lines. Its default value
    /// is `false`.
    open var isJustificationEnabled: Bool {
        get { return container.isJustificationEnabled }
        set { container.isJustificationEnabled = newValue }
    }

    /// The justification level which can range from `0.0` to `1.0`. A lower value increases the
    /// tightness between words while a higher value decreases it. Its default value is `1.0`.
    open var justificationLevel: CGFloat {
        get { return container.justificationLevel }
        set { container.justificationLevel = newValue }
    }

    /// The rendering style, used for controlling how text should appear while drawing. Its default value is
    /// `.fill`.
    open var renderingStyle: Renderer.RenderingStyle {
        get { return container.renderingStyle }
        set { container.renderingStyle = newValue }
    }

    /// The stroke color for text. Its default value is `black`.
    open var strokeColor: UIColor {
        get { return container.strokeColor }
        set { container.strokeColor = newValue }
    }

    /// The stroke width for text.
    open var strokeWidth: CGFloat {
        get { return container.strokeWidth }
        set { container.strokeWidth = newValue }
    }

    /// The stroke cap style which controls how the start and end of stroked lines and paths are
    /// treated. Its default value is `.butt`.
    open var strokeCap: Renderer.StrokeCap {
        get { return container.strokeCap }
        set { container.strokeCap = newValue }
    }

    /// The stroke join type. Its default value is `.round`.
    open var strokeJoin: Renderer.StrokeJoin {
        get { return container.strokeJoin }
        set { container.strokeJoin = newValue }
    }

    /// The stroke miter limit in pixels. This is used to control the behavior of miter joins when
    /// the joins angle is sharp.
    open var strokeMiter: CGFloat {
        get { return container.strokeMiter }
        set { container.strokeMiter = newValue }
    }

    /// The color to display a separator line below each rendered text line. Its default value is
    /// `nil`.
    open var separatorColor: UIColor? {
        get { return container.separatorColor }
        set { container.separatorColor = newValue }
    }
}
