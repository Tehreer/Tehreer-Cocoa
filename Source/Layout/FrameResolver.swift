//
// Copyright (C) 2019-2023 Muhammad Tayyab Akram
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
    var lastSize: CGSize = .zero

    // MARK: Paragraph Properties

    var startIndex: Int = .zero
    var endIndex: Int = .zero
    var baseLevel: UInt8 = .zero
    var paragraphSpans: [TextSpan<NSParagraphStyle>] = []

    // MARK: Line Properties

    var lineExtent: CGFloat = .zero
    var lineMargins: CGFloat = .zero
    var leftIndent: CGFloat = .zero
    var flushFactor: CGFloat = .zero

    init(resolver: FrameResolver) {
        self.layoutWidth = min(max(resolver.frameBounds.width, 0), .greatestFiniteMagnitude)
        self.layoutHeight = min(max(resolver.frameBounds.height, 0), .greatestFiniteMagnitude)
        self.maxLines = resolver.maxLines ?? .max
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

    /// The text alignment to apply on each line of a frame. Its default value is `.leading`.
    public var textAlignment: TextAlignment = .leading

    /// The vertical alignment to apply on the contents of a frame. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment = .top

    /// The truncation mode to apply on the last line of a frame in case of overflow. Its default
    /// value is `.line`.
    public var truncationMode: BreakMode = .line

    /// The truncation place for the last line of a frame. The truncation is disabled if its value
    /// is `nil`.
    public var truncationPlace: TruncationPlace? = nil

    /// A boolean value that indicates whether or not to justify the lines in a frame. Its default
    /// value is `false`.
    public var isJustificationEnabled: Bool = false

    /// The justification level which can range from `0.0` to `1.0`. A lower value increases the
    /// tightness between words while a higher value decreases it. Its default value is `1.0`.
    public var justificationLevel: CGFloat = 1.0

    /// The maximum number of lines that a frame should consist of.
    public var maxLines: Int? = nil

    /// The extra spacing to add after each line of a frame. It is resolved before line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat = .zero

    /// The height multiplier to apply on each line of a frame. It is resolved after extra line
    /// spacing. Its default value is one.
    public var lineHeightMultiplier: CGFloat = 1.0

    /// Creates a frame representing the specified UTF-16 range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter codeUnitRange: The UTF-16 range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(codeUnitRange: Range<Int>) -> ComposedFrame? {
        var context = FrameContext(resolver: self)

        let allParagraphs = typesetter.paragraphs
        var paragraphIndex = allParagraphs.binarySearchIndex(forCodeUnitAt: codeUnitRange.lowerBound)

        var segmentStart = codeUnitRange.lowerBound

        // Iterate over all paragraphs in provided range.
        repeat {
            let paragraph = allParagraphs[paragraphIndex]
            let paragraphRange = paragraph.codeUnitRange
            let segmentEnd = min(codeUnitRange.upperBound, paragraphRange.upperBound)

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
        } while segmentStart < codeUnitRange.upperBound

        resolveTruncation(context: &context, frameEnd: codeUnitRange.upperBound)
        resolveAlignments(context: &context)
        resolveJustification(context: &context)

        let textFrame = ComposedFrame(string: typesetter.text.string,
                                      codeUnitRange: codeUnitRange.lowerBound ..< context.endIndex,
                                      lines: context.textLines)
        textFrame.width = context.layoutWidth
        textFrame.height = context.layoutHeight

        return textFrame
    }

    /// Creates a frame representing the specified character range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter characterRange: The character range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(characterRange: Range<String.Index>) -> ComposedFrame? {
        let string = typesetter.text.string
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeFrame(codeUnitRange: codeUnitRange)
    }

    // MARK: Paragraph Handling

    private func resolveParagraphLines(context: inout FrameContext) {
        let text = typesetter.text
        let string = text.string

        let defaultSpan = extractParagraphSpans(context: &context, text: text)
        resolveParagraphStyle(context: &context, span: defaultSpan)

        var lineIndex = 0
        var lineStart = context.startIndex

        // Iterate over each line of this paragraph.
        while lineStart != context.endIndex {
            resolveHeadIndent(context: &context, lineIndex: lineIndex, style: defaultSpan?.attribute)

            // Find out the length of new line.
            let lineEnd = typesetter.suggestForwardBreak(inCodeUnitRange: lineStart ..< context.endIndex,
                                                         extent: context.lineExtent, breakMode: .line)

            // Create the line and resolve its attributes.
            let textLine = typesetter.makeSimpleLine(codeUnitRange: lineStart ..< lineEnd)
            resolveAttributes(context: &context, textLine: textLine)

            // Make sure that at least one line is added even if frame is smaller in height.
            let occupiedSize = computeOccupiedSize(context: &context, textLine: textLine)
            if occupiedSize.height > frameBounds.height && !context.textLines.isEmpty {
                context.isFilled = true
                return
            }

            // Append the line, and update the occupied size.
            context.textLines.append(textLine)
            resolveOccupiedSize(context: &context, newSize: occupiedSize)

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

    private func extractParagraphSpans(context: inout FrameContext, text: NSAttributedString) -> TextSpan<NSParagraphStyle>? {
        let range = NSRange(location: context.startIndex, length: context.endIndex - context.startIndex)
        var paragraphSpans: [TextSpan<NSParagraphStyle>] = []
        var defaultSpan: TextSpan<NSParagraphStyle>?

        text.enumerateAttribute(.paragraphStyle, in: range, options: []) { (attribute, spanRange, stop) in
            guard let attribute = attribute as? NSParagraphStyle else { return }
            let span = TextSpan(attribute: attribute, range: spanRange)

            if spanRange.contains(range.location) {
                defaultSpan = span
            }

            paragraphSpans.append(span)
        }

        context.paragraphSpans = paragraphSpans

        return defaultSpan
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
        if context.endIndex < string.utf16.count {
            context.occupiedHeight += span.attribute.paragraphSpacing
        }
    }

    // MARK: Line Handling

    private func resolveAttributes(context: inout FrameContext, textLine: ComposedLine) {
        // Find out the style of the line, if any.
        let lineStart = typesetter.text.string.utf16Index(forCharacterAt: textLine.startIndex)
        let lineStyle = context.paragraphSpans.last { $0.range.contains(lineStart) }?.attribute

        resolveLineStyle(textLine: textLine, style: lineStyle)
        resolveLineHeightMultiplier(textLine: textLine, multiplier: lineHeightMultiplier)
        resolveExtraLineSpacing(textLine: textLine, spacing: extraLineSpacing)

        // Compute the origin of current line.
        let originX = context.leftIndent + textLine.penOffset(forFlushFactor: context.flushFactor, flushExtent: context.lineExtent)
        let originY = context.occupiedHeight + textLine.ascent

        // Update the properties of current line.
        textLine.origin = CGPoint(x: originX, y: originY)
        textLine.intrinsicMargin = context.layoutWidth - context.lineExtent
        textLine.flushFactor = context.flushFactor
    }

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

    private func computeOccupiedSize(context: inout FrameContext, textLine: ComposedLine) -> CGSize {
        let lineWidth = context.lineMargins + textLine.width - textLine.trailingWhitespaceExtent
        let lineHeight = textLine.height

        return CGSize(width: max(context.occupiedWidth, lineWidth),
                      height: context.occupiedHeight + lineHeight)
    }

    private func resolveOccupiedSize(context: inout FrameContext, newSize: CGSize) {
        context.lastSize = CGSize(width: context.occupiedWidth, height: context.occupiedHeight)
        context.occupiedWidth = newSize.width
        context.occupiedHeight = newSize.height
    }

    private func resolveOccupiedSize(context: inout FrameContext, textLine: ComposedLine) {
        let newSize = computeOccupiedSize(context: &context, textLine: textLine)
        resolveOccupiedSize(context: &context, newSize: newSize)
    }

    private func resolveTruncation(context: inout FrameContext, frameEnd: Int) {
        guard let truncationPlace = truncationPlace else { return }

        let lastIndex = context.textLines.count - 1
        let lastLine = context.textLines[lastIndex]
        let lastRange = lastLine.codeUnitRange

        // No need to truncate if frame range is already covered.
        if lastRange.upperBound == frameEnd {
            return
        }

        // Restore the occupied size to previous value.
        context.occupiedWidth = context.lastSize.width
        context.occupiedHeight = context.lastSize.height

        // Create the truncated line and resolve its attributes.
        let lineRange = lastRange.lowerBound ..< frameEnd
        let textLine = typesetter.makeTruncatedLine(codeUnitRange: lineRange,
                                                    extent: context.lineExtent,
                                                    breakMode: truncationMode,
                                                    truncationPlace: truncationPlace,
                                                    tokenString: nil)
        resolveAttributes(context: &context, textLine: textLine)

        // Replace the line and update the occupied size.
        context.textLines[lastIndex] = textLine
        resolveOccupiedSize(context: &context, textLine: textLine)
    }

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

    private func resolveJustification(context: inout FrameContext) {
        guard isJustificationEnabled else { return }

        let string = typesetter.text.string
        let textLines = context.textLines
        let lineCount = textLines.count

        for i in 0 ..< lineCount {
            let textLine = textLines[i]
            let lineRange = textLine.codeUnitRange

            // Skip the last line of paragraph if it's smaller in width.
            if textLine.endIndex == string.endIndex || string[string.index(before: textLine.endIndex)] == "\n" {
                continue
            }

            let justifiedLine = typesetter.makeJustifiedLine(
                codeUnitRange: lineRange,
                justificationFactor: 1.0,
                justificationExtent: context.layoutWidth
            )

            let intrinsicMargin = textLine.intrinsicMargin
            let flushFactor = textLine.flushFactor
            let availableWidth = context.layoutWidth - intrinsicMargin
            let alignedLeft = justifiedLine.penOffset(
                forFlushFactor: flushFactor,
                flushExtent: availableWidth
            )
            var marginalLeft: CGFloat = 0.0

            let paragraphLevel = justifiedLine.paragraphLevel
            if (paragraphLevel & 1) == 0 {
                marginalLeft = intrinsicMargin
            }

            justifiedLine.origin.x = marginalLeft + alignedLeft
            justifiedLine.origin.y = textLine.origin.y
            justifiedLine.intrinsicMargin = textLine.intrinsicMargin
            justifiedLine.flushFactor = textLine.flushFactor

            // Setup the line metrics.
            justifiedLine.ascent = textLine.ascent
            justifiedLine.descent = textLine.descent
            justifiedLine.leading = textLine.leading

            context.textLines[i] = justifiedLine
        }
    }
}
