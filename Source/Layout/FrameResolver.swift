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

import CoreGraphics
import Foundation
import UIKit

private struct TextSpan<Attribute> {
    let attribute: Attribute
    let range: NSRange
}

private struct FrameContext {
    // MARK: Layout Properties

    var layoutWidth: CGFloat = .zero
    var layoutHeight: CGFloat = .zero

    let maxLines: Int

    var textLines: [ComposedLine] = []
    var isFilled: Bool = false

    var occupiedWidth: CGFloat = .zero
    var occupiedHeight: CGFloat = .zero

    // MARK: Paragraph Properties

    var startIndex: String.Index
    var endIndex: String.Index
    var baseLevel: UInt8 = .zero

    // MARK: Line Properties

    var lineExtent: CGFloat = .zero
    var lineMargins: CGFloat = .zero
    var leftIndent: CGFloat = .zero
    var flushFactor: CGFloat = .zero

    init(resolver: FrameResolver, startIndex: String.Index, endIndex: String.Index) {
        self.layoutWidth = min(max(resolver.frameBounds.width, 0), .greatestFiniteMagnitude)
        self.layoutHeight = min(max(resolver.frameBounds.height, 0), .greatestFiniteMagnitude)
        self.maxLines = resolver.maxLines ?? .max
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

/// This class resolves text frames by using a typesetter object.
public class FrameResolver {
    /// The typesetter to use for resolving frames.
    public var typesetter: Typesetter!

    /// A rectangle that specifies the frame bounds. Its default value is an infinite rectangle at
    /// zero origin.
    public var frameBounds: CGRect = .infinite

    /// A boolean value that indicates whether or not to tightly fit the lines horizontally in a
    /// frame. If enabled, the resulting frame will have a minimum width that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsHorizontally: Bool = false

    /// A boolean value that indicates whether or not to tightly fit the lines vertically in a
    /// frame. If enabled, the resulting frame will have a minimum height that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsVertically: Bool = false

    /// The text alignment to apply on each line of a frame. Its default value is `.intrinsic`.
    public var textAlignment: TextAlignment = .intrinsic

    /// The vertical alignment to apply on the contents of a frame. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment = .top

    /// The maximum number of lines that a frame should consist of.
    public var maxLines: Int? = nil

    /// The extra spacing to add after each line of a frame. It is resolved before line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat = .zero

    /// The height multiplier to apply on each line of a frame. It is resolved after extra line
    /// spacing. Its default value is one.
    public var lineHeightMultiplier: CGFloat = 1.0

    /// Creates a frame representing specified string range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter characterRange: The character range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(characterRange: Range<String.Index>) -> ComposedFrame? {
        var context = FrameContext(resolver: self, startIndex: characterRange.lowerBound, endIndex: characterRange.upperBound)

        let allParagraphs = typesetter.paragraphs
        var paragraphIndex = allParagraphs.binarySearchIndex(ofCharacterAt: characterRange.lowerBound)

        var segmentStart = characterRange.lowerBound

        // Iterate over all paragraphs in provided range.
        repeat {
            let paragraph = allParagraphs[paragraphIndex]
            let segmentEnd = min(characterRange.upperBound, paragraph.endIndex)

            // Setup the paragraph properties.
            context.startIndex = segmentStart
            context.endIndex = segmentEnd
            context.baseLevel = paragraph.baseLevel

            // Setup the line properties.
            context.lineExtent = context.layoutWidth
            context.lineMargins = .zero
            context.leftIndent = .zero
            context.flushFactor = textAlignment.flushFactor(for: context.baseLevel)

            resolveParagraphLines(context: &context)

            if (context.isFilled) {
                break
            }

            segmentStart = segmentEnd
            paragraphIndex += 1
        } while segmentStart < characterRange.upperBound

        resolveAlignments(context: &context)

        let textFrame = ComposedFrame(string: typesetter.text.string,
                                      startIndex: characterRange.lowerBound,
                                      endIndex: context.endIndex,
                                      lines: context.textLines)
        textFrame.width = context.layoutWidth
        textFrame.height = context.layoutHeight

        return textFrame
    }

    // MARK: Paragraph Handling

    private func resolveParagraphLines(context: inout FrameContext) {
        let text = typesetter.text
        let string = text.string

        let (spans, defaultSpan) = extractParagraphSpans(context: &context, text: text)
        resolveParagraphStyle(context: &context, span: defaultSpan)

        var lineIndex = 0
        var lineStart = context.startIndex

        // Iterate over each line of this paragraph.
        while lineStart != context.endIndex {
            resolveHeadIndent(context: &context, lineIndex: lineIndex, style: defaultSpan?.attribute)

            // Find out the style of new line, if any.
            let utf16Start = string.utf16Index(forCharacterAt: lineStart)
            let lineStyle = spans.last { $0.range.contains(utf16Start) }?.attribute

            // Find out the length of new line.
            let lineEnd = typesetter.suggestForwardBreak(inCharacterRange: lineStart ..< context.endIndex,
                                                         extent: context.lineExtent, breakMode: .line)

            // Create the line and resolve its attributes.
            let textLine = typesetter.makeSimpleLine(characterRange: lineStart ..< lineEnd)
            resolveLineStyle(textLine: textLine, style: lineStyle)
            resolveLineHeightMultiplier(textLine: textLine, multiplier: lineHeightMultiplier)
            resolveExtraLineSpacing(textLine: textLine, spacing: extraLineSpacing)

            // Compute the origin of current line.
            let originX = context.leftIndent + textLine.penOffset(forFlushFactor: context.flushFactor, flushExtent: context.lineExtent)
            let originY = context.occupiedHeight + textLine.ascent

            // Update the properties of current line.
            textLine.origin = CGPoint(x: originX, y: originY)
            textLine.flushFactor = context.flushFactor

            // Compute the line width and the height.
            let lineWidth = context.lineMargins + textLine.width - textLine.trailingWhitespaceExtent
            let lineHeight = textLine.height

            // Make sure that at least one line is added even if frame is smaller in height.
            if context.occupiedHeight + lineHeight > frameBounds.height && !context.textLines.isEmpty {
                context.isFilled = true
                return
            }

            // Append the line, and update the occupied width and height.
            context.textLines.append(textLine)
            context.occupiedWidth = max(context.occupiedWidth, lineWidth)
            context.occupiedHeight += lineHeight

            // Stop the filling process if maximum lines have been added.
            if context.textLines.count == context.maxLines {
                context.isFilled = true
                return
            }

            lineIndex += 1
            lineStart = lineEnd
        }

        resolveParagraphSpacing(context: &context, string: string, span: defaultSpan)
    }

    private func extractParagraphSpans(context: inout FrameContext, text: NSAttributedString) -> (spans: [TextSpan<NSParagraphStyle>], defaultSpan: TextSpan<NSParagraphStyle>?) {
        let range: NSRange = text.string.utf16Range(forCharacterRange: context.startIndex ..< context.endIndex)

        var spans: [TextSpan<NSParagraphStyle>] = []
        var defaultSpan: TextSpan<NSParagraphStyle>?

        text.enumerateAttribute(.paragraphStyle, in: range, options: []) { (attribute, spanRange, stop) in
            guard let attribute = attribute as? NSParagraphStyle else { return }
            let span = TextSpan(attribute: attribute, range: spanRange)

            if spanRange.contains(range.location) {
                defaultSpan = span
            }

            spans.append(span)
        }

        return (spans, defaultSpan)
    }

    private func resolveParagraphStyle(context: inout FrameContext, span: TextSpan<NSParagraphStyle>?) {
        guard let span = span else { return }
        let style = span.attribute

        // Resolve `alignment`.
        context.flushFactor = style.alignment.flushFactor(for: context.baseLevel)

        // Resolve `paragraphSpacingBefore` if it is not the first paragraph.
        if span.range.location > 0 {
            context.occupiedHeight += style.paragraphSpacingBefore
        }

        // Resolve `firstLineHeadIndent` and `tailIndent`.
        resolveIndents(context: &context,
                       headIndent: style.firstLineHeadIndent,
                       tailIndent: style.tailIndent)
    }

    private func resolveIndents(context: inout FrameContext, headIndent: CGFloat, tailIndent: CGFloat) {
        let isRTL = context.baseLevel & 1 == 1

        if tailIndent > .zero {
            let resolvedIndent = context.layoutWidth - (headIndent + tailIndent)
            context.leftIndent = isRTL ? resolvedIndent : headIndent
            context.lineMargins = headIndent + resolvedIndent
            context.lineExtent = tailIndent
        } else {
            context.leftIndent = isRTL ? -tailIndent : headIndent
            context.lineMargins = headIndent + -tailIndent
            context.lineExtent = context.layoutWidth - context.lineMargins
        }
    }

    private func resolveHeadIndent(context: inout FrameContext, lineIndex: Int, style: NSParagraphStyle?) {
        guard lineIndex == 1, let style = style else { return }

        resolveIndents(context: &context,
                       headIndent: style.headIndent,
                       tailIndent: style.tailIndent)
    }

    private func resolveParagraphSpacing(context: inout FrameContext, string: String, span: TextSpan<NSParagraphStyle>?) {
        guard let span = span else { return }

        // Resolve `paragraphSpacing` if it is not the last paragraph.
        if context.endIndex < string.endIndex {
            context.occupiedHeight += span.attribute.paragraphSpacing
        }
    }

    // MARK: Line Handling

    private func resolveLineStyle(textLine: ComposedLine, style: NSParagraphStyle?) {
        guard let style = style else { return }

        // Resolve `lineHeightMultiple`.
        if style.lineHeightMultiple > .zero {
            let oldHeight = textLine.height
            let newHeight = oldHeight * style.lineHeightMultiple
            textLine.ascent += newHeight - oldHeight
        }

        // Resolve `minimumLineHeight`.
        if style.minimumLineHeight > .zero {
            if textLine.height < style.minimumLineHeight {
                textLine.ascent += style.minimumLineHeight - textLine.height
            }
        }

        // Resolve `maximumLineHeight`.
        if style.maximumLineHeight > .zero {
            if textLine.height > style.maximumLineHeight {
                textLine.ascent -= textLine.height - style.maximumLineHeight
            }
        }

        // Resolve `lineSpacing`.
        textLine.leading += style.lineSpacing
    }

    private func resolveLineHeightMultiplier(textLine: ComposedLine, multiplier: CGFloat) {
        guard multiplier > .zero else { return }

        let oldHeight = textLine.height
        let newHeight = oldHeight * multiplier
        let midOffset = (newHeight - oldHeight) / 2.0

        // Adjust metrics in such a way that text remains in the middle of the line.
        textLine.ascent += midOffset
        textLine.descent += midOffset
    }

    private func resolveExtraLineSpacing(textLine: ComposedLine, spacing: CGFloat) {
        guard spacing > .zero else { return }

        textLine.leading += spacing
    }

    // MARK: Layout Handling

    private func resolveAlignments(context: inout FrameContext) {
        if fitsVertically {
            // Update the layout height to occupied height.
            context.layoutHeight = context.occupiedHeight
        } else {
            // Find out the additional top for vertical alignment.
            let extraHeight = context.layoutHeight - context.occupiedHeight
            let additionalTop = extraHeight * verticalAlignment.multiplier()

            // Readjust the vertical position of each line.
            for textLine in context.textLines {
                textLine.origin.y += additionalTop
            }
        }

        if fitsHorizontally {
            let extraWidth = context.layoutWidth - context.occupiedWidth

            // Readjust the horizontal position of each line.
            for textLine in context.textLines {
                textLine.origin.x -= extraWidth * textLine.flushFactor
            }

            // Update the layout width to occupied width.
            context.layoutWidth = context.occupiedWidth
        }
    }
}
