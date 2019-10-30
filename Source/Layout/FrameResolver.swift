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

private struct FrameContext {
    var layoutWidth: CGFloat = .zero
    var layoutHeight: CGFloat = .zero

    let maxLines: Int

    var startIndex: String.Index
    var endIndex: String.Index
    var baseLevel: UInt8 = .zero

    var textLines: [ComposedLine] = []
    var lineTop: CGFloat = .zero

    var isFilled: Bool = false

    init(resolver: FrameResolver, startIndex: String.Index, endIndex: String.Index) {
        self.layoutWidth = resolver.frameBounds.width
        self.layoutHeight = resolver.frameBounds.height
        self.maxLines = resolver.maxLines ?? .max
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

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

    public func makeFrame(characterRange range: Range<String.Index>) -> ComposedFrame? {
        var context = FrameContext(resolver: self, startIndex: range.lowerBound, endIndex: range.upperBound)

        let allParagraphs = typesetter.paragraphs
        var paragraphIndex = allParagraphs.binarySearchIndex(ofCharacterAt: range.lowerBound)

        var segmentStart = range.lowerBound

        // Iterate over all paragraphs in provided range.
        repeat {
            let paragraph = allParagraphs[paragraphIndex]
            let segmentEnd = min(range.upperBound, paragraph.endIndex)

            // Setup the frame filler and add the lines.
            context.startIndex = segmentStart
            context.endIndex = segmentEnd
            context.baseLevel = paragraph.baseLevel
            addParagraphLines(context: &context)

            if (context.isFilled) {
                break
            }

            segmentStart = segmentEnd
            paragraphIndex += 1
        } while segmentStart < range.upperBound

        resolveAlignments(context: &context)

        let textFrame = ComposedFrame(string: typesetter.text.string,
                                      startIndex: range.lowerBound,
                                      endIndex: context.endIndex,
                                      lines: context.textLines)
        textFrame.width = context.layoutWidth
        textFrame.height = context.layoutHeight

        return textFrame
    }

    private func addParagraphLines(context: inout FrameContext) {
        let flushFactor = textAlignment.flushFactor(for: context.baseLevel)
        var lineStart = context.startIndex

        // Iterate over each line of this paragraph.
        while lineStart != context.endIndex {
            let lineEnd = typesetter.suggestForwardBreak(inCharacterRange: lineStart ..< context.endIndex,
                                                         extent: context.layoutWidth, breakMode: .line)

            let textLine = typesetter.makeSimpleLine(characterRange: lineStart ..< lineEnd)
            prepareLine(context: &context, textLine: textLine, flushFactor: flushFactor)

            let lineHeight = textLine.height

            // Make sure that at least one line is added even if frame is smaller in height.
            if context.lineTop + lineHeight > frameBounds.height && !context.textLines.isEmpty {
                context.isFilled = true
                return
            }

            context.textLines.append(textLine)

            // Stop the filling process if maximum lines have been added.
            if context.textLines.count == context.maxLines {
                context.isFilled = true
                return
            }

            lineStart = lineEnd
            context.lineTop += lineHeight
        }
    }

    private func prepareLine(context: inout FrameContext, textLine: ComposedLine, flushFactor: CGFloat) {
        // Resolve line height multiplier.
        if lineHeightMultiplier != .zero {
            let oldHeight = textLine.height
            let newHeight = oldHeight * lineHeightMultiplier
            let midOffset = (newHeight - oldHeight) / 2.0

            // Adjust metrics in such a way that text remains in the middle of the line.
            textLine.ascent += midOffset
            textLine.descent += midOffset
        }

        // Resolve extra line spacing.
        if extraLineSpacing != .zero {
            textLine.leading += extraLineSpacing
        }

        // Compute the origin of the line.
        let originX = textLine.penOffset(forFlushFactor: flushFactor, flushExtent: context.layoutWidth)
        let originY = context.lineTop + textLine.ascent

        // Update the properties of line.
        textLine.origin = CGPoint(x: originX, y: originY)
        textLine.flushFactor = flushFactor
    }

    private func resolveAlignments(context: inout FrameContext) {
        guard let lastLine = context.textLines.last else {
            return
        }

        // Find out the occupied height.
        let occupiedHeight = lastLine.bottom

        if fitsVertically {
            // Update the layout height to occupied height.
            context.layoutHeight = occupiedHeight
        } else {
            // Find out the additional top for vertical alignment.
            let remainingHeight = context.layoutHeight - occupiedHeight
            let additionalTop = remainingHeight * verticalAlignment.multiplier()

            // Readjust the vertical position of each line.
            for textLine in context.textLines {
                textLine.origin.y += additionalTop
            }
        }

        if fitsHorizontally {
            var occupiedWidth: CGFloat = -.infinity

            // Find out the occupied width.
            for textLine in context.textLines {
                let lineWidth = textLine.intrinsicMargin + textLine.width - textLine.trailingWhitespaceExtent
                occupiedWidth = max(occupiedWidth, lineWidth)
            }

            // Readjust the horizontal position of each line.
            for textLine in context.textLines {
                let intrinsicMargin = textLine.intrinsicMargin
                let availableWidth = occupiedWidth - intrinsicMargin
                let alignedX = textLine.penOffset(forFlushFactor: textLine.flushFactor, flushExtent: availableWidth)
                var marginalX: CGFloat = .zero

                if (textLine.paragraphLevel & 1) == 0 {
                    marginalX = intrinsicMargin
                }

                textLine.origin.x = marginalX + alignedX
            }

            // Update the layout width to occupied width.
            context.layoutWidth = occupiedWidth
        }
    }
}
