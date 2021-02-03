//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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
    private let string: String
    private var extent: CGFloat

    init(string: String, codeUnitRange: Range<Int>, paragraphLevel: UInt8,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat, extent: CGFloat,
         trailingWhitespaceExtent: CGFloat, visualRuns: [GlyphRun]) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.paragraphLevel = paragraphLevel
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.extent = extent
        self.trailingWhitespaceExtent = trailingWhitespaceExtent
        self.visualRuns = visualRuns
    }

    /// The UTF-16 range of this line in source string.
    public let codeUnitRange: Range<Int>

    /// The index to the first character of this line in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this line in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

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

    /// Determines the distance of the specified UTF-16 code unit from the start of the line assumed
    /// at zero.
    ///
    /// - Parameters:
    ///   - index: The index of the UTF-16 code unit in source string.
    /// - Returns: The distance of the specified UTF-16 code unit from the start of the line assumed
    ///            at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        var distance: CGFloat = 0.0

        for glyphRun in visualRuns {
            if glyphRun.codeUnitRange.contains(index) {
                distance += glyphRun.distance(forCodeUnitAt: index)
                break
            }

            distance += glyphRun.width
        }

        return distance
    }

    /// Determines the distance of the specified character from the start of the line assumed at
    /// zero.
    ///
    /// - Parameters:
    ///   - index: The index of character in source string.
    /// - Returns: The distance of specified character from the start of the line assumed at zero.
    public func distance(forCharacterAt index: String.Index) -> CGFloat {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return distance(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns an array of visual edges corresponding to the specified range of UTF-16 code units.
    ///
    /// The resulting array will contain pairs of leading and trailing edges sorted from left to
    /// right. There will be a separate pair for each glyph run occurred in the specified code unit
    /// range. Each edge will be positioned relative to the start of the line assumed at zero.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The range of UTF-16 code units in source string.
    /// - Returns: An array of visual edges corresponding to the specified UTF-16 code unit range.
    public func visualEdges(forCodeUnitRange codeUnitRange: Range<Int>) -> [CGFloat] {
        let clampedRange = codeUnitRange.clamped(to: self.codeUnitRange)
        let visualStart = clampedRange.lowerBound
        let visualEnd = clampedRange.upperBound

        guard visualStart < visualEnd else {
            return []
        }

        var visualEdges: [CGFloat] = []

        for glyphRun in visualRuns {
            let runRange = glyphRun.codeUnitRange
            let runStart = runRange.lowerBound
            let runEnd = runRange.upperBound

            if runStart < visualEnd && runEnd > visualStart {
                let selectionStart = max(visualStart, runStart)
                let selectionEnd = min(visualEnd, runEnd)

                let leadingEdge = glyphRun.distance(forCodeUnitAt: selectionStart)
                let trailingEdge = glyphRun.distance(forCodeUnitAt: selectionEnd)

                let relativeLeft = glyphRun.origin.x
                let selectionLeft = min(leadingEdge, trailingEdge) + relativeLeft
                let selectionRight = max(leadingEdge, trailingEdge) + relativeLeft

                visualEdges.append(selectionLeft)
                visualEdges.append(selectionRight)
            }
        }

        return visualEdges
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
        return visualEdges(forCodeUnitRange: string.utf16Range(forCharacterRange: characterRange))
    }

    /// Returns the index of UTF-16 code unit nearest to the specified distance.
    ///
    /// - Parameters:
    ///   - distance: The distance for which to determine the UTF-16 code unit index. It should be
    ///               offset from zero origin.
    /// - Returns: The index of UTF-16 code unit in source string, nearest to the specified
    ///            distance.
    public func indexOfCodeUnit(at distance: CGFloat) -> Int {
        for glyphRun in visualRuns.reversed() {
            if glyphRun.origin.x <= distance {
                return glyphRun.indexOfCodeUnit(at: distance - glyphRun.origin.x)
            }
        }

        return codeUnitRange.lowerBound
    }

    /// Returns the index of character nearest to the specified distance.
    ///
    /// - Parameters:
    ///   - distance: The distance for which to determine the character index. It should be offset
    ///               from zero origin.
    /// - Returns: The index of character in source string, nearest to the specified distance.
    public func indexOfCharacter(at distance: CGFloat) -> String.Index {
        return string.characterIndex(forUTF16Index: indexOfCodeUnit(at: distance))
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

    func computeBoundingBox(with renderer: Renderer) -> CGRect {
        var comulativeBox = CGRect()

        for glyphRun in visualRuns {
            var runBox = glyphRun.computeBoundingBox(with: renderer)
            runBox = runBox.offsetBy(dx: glyphRun.origin.x, dy: glyphRun.origin.y)

            comulativeBox = comulativeBox.union(runBox)
        }

        return comulativeBox
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
