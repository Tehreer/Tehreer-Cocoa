//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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


internal import Tehreer

import CoreGraphics
import Foundation

/// Represents a line of text consisting of an array of `GlyphRun` objects in visual order.
// Unchecked because the line of Core is immutable, and the rest is set once in the initializer.
public final class ComposedLine: @unchecked Sendable {
    let core: TRComposedLineRef
    private let string: String

    init(core: TRComposedLineRef, string: String, objects: CoreTextObjects) {
        self.core = core
        self.string = string

        let count = Int(TRComposedLineGetGlyphRunCount(core))
        var runs: [GlyphRun] = []
        runs.reserveCapacity(count)

        for index in 0 ..< count {
            runs.append(GlyphRun(core: TRComposedLineGetGlyphRun(core, TRUInteger(index)),
                                 string: string, objects: objects))
        }

        self.visualRuns = runs
    }

    deinit {
        TRComposedLineRelease(core)
    }

    /// The UTF-16 range of this line in source string.
    public var codeUnitRange: Range<Int> {
        let range = TRComposedLineGetCodeUnitRange(core)
        return Int(range.index) ..< Int(range.index + range.length)
    }

    /// The index to the first character of this line in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this line in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    /// The paragraph level of this line.
    public var paragraphLevel: UInt8 {
        return TRComposedLineGetParagraphLevel(core)
    }

    /// The origin of this line in parent frame.
    public var origin: CGPoint {
        let origin = TRComposedLineGetOrigin(core)
        return CGPoint(x: CGFloat(origin.x), y: CGFloat(origin.y))
    }

    /// The ascent of this line which is the maximum ascent from the baseline of all runs.
    public var ascent: CGFloat {
        return CGFloat(TRComposedLineGetAscent(core))
    }

    /// The descent of this line which is the maximum descent from the baseline of all runs.
    public var descent: CGFloat {
        return CGFloat(TRComposedLineGetDescent(core))
    }

    /// The leading of this line which is the maximum leading of all runs.
    public var leading: CGFloat {
        return CGFloat(TRComposedLineGetLeading(core))
    }

    /// The typographic width of this line.
    public var width: CGFloat {
        return CGFloat(TRComposedLineGetWidth(core))
    }

    /// The typographic height of this line.
    public var height: CGFloat {
        return CGFloat(TRComposedLineGetHeight(core))
    }

    /// Whether this line is the line of a view that has a line of its own.
    var isBlock: Bool {
        return TRComposedLineIsBlock(core) != 0
    }

    var top: CGFloat {
        return CGFloat(TRComposedLineGetTop(core))
    }

    var bottom: CGFloat {
        return CGFloat(TRComposedLineGetBottom(core))
    }

    var left: CGFloat {
        return CGFloat(TRComposedLineGetLeft(core))
    }

    var right: CGFloat {
        return CGFloat(TRComposedLineGetRight(core))
    }

    /// The typographic extent corresponding to the trailing whitespace characters in this line.
    public var trailingWhitespaceExtent: CGFloat {
        return CGFloat(TRComposedLineGetTrailingWhitespaceExtent(core))
    }

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

        return CGFloat(TRComposedLineGetDistance(core, TRUInteger(index)))
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

        guard !clampedRange.isEmpty else {
            return []
        }

        var edges: [CGFloat] = []
        let range = TRRange(index: TRUInteger(clampedRange.lowerBound),
                            length: TRUInteger(clampedRange.count))

        withUnsafeMutablePointer(to: &edges) { (pointer) in
            TRComposedLineEnumerateEdges(core, range, { (user, left, right) in
                let edges = user!.assumingMemoryBound(to: [CGFloat].self)
                edges.pointee.append(CGFloat(left))
                edges.pointee.append(CGFloat(right))
            }, pointer)
        }

        return edges
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
        return Int(TRComposedLineGetIndexOfCodeUnit(core, TRFloat(distance)))
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
        return CGFloat(TRComposedLineGetPenOffset(core, TRFloat(flushFactor), TRFloat(flushExtent)))
    }

    func computeBoundingBox(with renderer: Renderer) -> CGRect {
        let box = TRComposedLineGetBoundingBox(core, renderer.core)
        renderer.syncCore()

        if box.size.width == 0 && box.size.height == 0 {
            return .null
        }

        return CGRect(x: CGFloat(box.origin.x), y: CGFloat(box.origin.y),
                      width: CGFloat(box.size.width), height: CGFloat(box.size.height))
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
