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

/// Represents a line of text consisting of an array of `GlyphRun` objects in visual order.
public class ComposedLine {
    private var extent: CGFloat

    init(startIndex: String.Index, endIndex: String.Index, paragraphLevel: UInt8,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat, extent: CGFloat,
         trailingWhitespaceExtent: CGFloat, visualRuns: [GlyphRun]) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.paragraphLevel = paragraphLevel
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.extent = extent
        self.trailingWhitespaceExtent = trailingWhitespaceExtent
        self.visualRuns = visualRuns
    }

    /// The index to the first character of this line in source string.
    public let startIndex: String.Index

    /// The index after the last character of this line in source string.
    public let endIndex: String.Index

    /// The paragraph level of this line.
    public let paragraphLevel: UInt8

    /// The origin of this line in parent frame.
    public internal(set) var origin: CGPoint = .zero

    /// The ascent of this line which is the maximum ascent from the baseline of all runs.
    public internal(set) var ascent: CGFloat

    /// The descent of this line which is the maximum descent from the baseline of all runs.
    public internal(set) var descent: CGFloat

    /// The leading of this line which is the maximum leading of all runs.
    public internal(set) var leading: CGFloat

    /// The typographic width of this line.
    public var width: CGFloat {
        return extent
    }

    /// The typographic height of this line.
    public var height: CGFloat {
        return (ascent + descent + leading)
    }

    var flushFactor: CGFloat = .zero

    var intrinsicMargin: CGFloat = .zero

    var top: CGFloat {
        return origin.y - ascent
    }

    var bottom: CGFloat {
        return origin.y + descent + leading
    }

    var left: CGFloat {
        return origin.x
    }

    var right: CGFloat {
        return origin.x + extent
    }

    /// The typographic extent corresponding to the trailing whitespace characters in this line.
    public let trailingWhitespaceExtent: CGFloat

    /// The glyph runs of this line in visual order.
    public let visualRuns: [GlyphRun]

    private func checkCharacterIndex(_ characterIndex: String.Index) {
        precondition(characterIndex >= startIndex && characterIndex < endIndex,
                     "Index is out of range")
    }

    /// Determines the distance of specified character from the start of the line assumed at zero.
    ///
    /// - Parameters:
    ///   - index: The index of character in source string.
    /// - Returns: The distance of specified character from the start of the line assumed at zero.
    public func distance(forCharacterAt index: String.Index) -> CGFloat {
        checkCharacterIndex(index)

        var distance: CGFloat = 0.0

        for glyphRun in visualRuns {
            if index >= glyphRun.startIndex && index < glyphRun.endIndex {
                distance += glyphRun.distance(forCharacterAt: index)
                break
            }

            distance += glyphRun.width
        }

        return distance
    }

    /// Returns an array of visual edges corresponding to the specified character range.
    ///
    /// The resulting array will contain pairs of leading and trailing edges sorted from left to
    /// right. There will be a separate pair for each glyph run occurred in the specified character
    /// range. Each edge will be positioned relative to the start of the line assumed at zero.
    ///
    /// - Parameters:
    ///   - characterRange: The range of characters in source string.
    /// - Returns: An array of visual edges corresponding to the specified character range.
    public func visualEdges(forCharacterRange characterRange: Range<String.Index>) -> [CGFloat] {
        var visualEdges: [CGFloat] = []

        for glyphRun in visualRuns {
            if glyphRun.startIndex < characterRange.upperBound && glyphRun.endIndex > characterRange.lowerBound {
                let selectionStart = max(characterRange.lowerBound, glyphRun.startIndex)
                let selectionEnd = min(characterRange.upperBound, glyphRun.endIndex)

                let leadingEdge = glyphRun.distance(forCharacterAt: selectionStart)
                let trailingEdge = glyphRun.distance(forCharacterAt: selectionEnd)

                let relativeLeft = glyphRun.origin.x
                let selectionLeft = min(leadingEdge, trailingEdge) + relativeLeft
                let selectionRight = max(leadingEdge, trailingEdge) + relativeLeft

                visualEdges.append(selectionLeft)
                visualEdges.append(selectionRight)
            }
        }

        return visualEdges
    }

    /// Returns the index of character nearest to the specified distance.
    ///
    /// - Parameters:
    ///   - distance: The distance for which to determine the character index. It should be offset
    ///               from zero origin.
    /// - Returns: The index of character in source string, nearest to the specified distance.
    public func indexOfCharacter(at distance: CGFloat) -> String.Index {
        for glyphRun in visualRuns.reversed() {
            if glyphRun.origin.x <= distance {
                return glyphRun.indexOfCharacter(at: distance - glyphRun.origin.x)
            }
        }

        return startIndex
    }

    /// Returns the pen offset required to draw flush text.
    ///
    /// - Parameters:
    ///   - flushFactor: Specifies the kind of flushness. A flush factor of 0 or less indicates left
    ///                  flush. A flushFactor of 1.0 or more indicates right flush. Flush factors
    ///                  between 0 and 1.0 indicate varying degrees of center flush, with a value of
    ///                  0.5 being totally center flush.
    ///   - flushExtent: Specifies the extent that the flushness operation should apply to.
    /// - Returns: A value which can be used to offset the current pen position for the flush
    ///            operation.
    public func penOffset(forFlushFactor flushFactor: CGFloat, flushExtent: CGFloat) -> CGFloat {
        var penOffset = (flushExtent - (extent - trailingWhitespaceExtent)) * flushFactor
        if (paragraphLevel & 1) == 1 {
            penOffset -= trailingWhitespaceExtent
        }

        return penOffset
    }

    /// Draws this line in the `context` with the specified renderer.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw the line.
    ///   - context: The context in which to draw the line.
    public func draw(with renderer: Renderer, in context: CGContext) {
        for glyphRun in visualRuns {
            context.translateBy(x: glyphRun.origin.x, y: glyphRun.origin.y)
            glyphRun.draw(with: renderer, in: context)
            context.translateBy(x: -glyphRun.origin.x, y: -glyphRun.origin.y)
        }
    }
}
