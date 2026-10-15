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
    private let objects: CoreTextObjects

    init(core: TRComposedLineRef, string: String, objects: CoreTextObjects) {
        self.core = core
        self.string = string
        self.objects = objects
    }

    deinit {
        TRComposedLineRelease(core)
    }

    /// The UTF-16 range of this line in source string.
    public var codeUnitRange: Range<Int> {
        return Int(TRComposedLineGetStartIndex(core)) ..< Int(TRComposedLineGetEndIndex(core))
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
        return CGPoint(TRComposedLineGetOrigin(core))
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

    /// A Boolean value that indicates whether the text of this line is cut short, as by a
    /// truncation token.
    public var isTruncated: Bool {
        return TRComposedLineIsTruncated(core) != 0
    }

    /// Whether this line is the line of a view that has a line of its own.
    var isBlock: Bool {
        return TRComposedLineIsBlock(core) != 0
    }

    /// The typographic extent corresponding to the trailing whitespace characters in this line.
    public var trailingWhitespaceExtent: CGFloat {
        return CGFloat(TRComposedLineGetTrailingWhitespaceExtent(core))
    }

    private let runCache = Lazy<[GlyphRun]>()

    /// The glyph runs of this line in visual order. They are made the first time they are asked for.
    public var runs: PrimitiveCollection<GlyphRun> {
        return PrimitiveCollection(runCache.get {
            (0 ..< TRComposedLineGetGlyphRunCount(core)).map {
                GlyphRun(
                    core: TRComposedLineGetGlyphRun(core, $0)!,
                    string: string,
                    objects: objects
                )
            }
        })
    }

    /// Determines the distance of the specified UTF-16 code unit from the start of the line assumed
    /// at zero.
    ///
    /// - Parameters:
    ///   - index: The index of the UTF-16 code unit in source string.
    /// - Returns: The distance of the specified UTF-16 code unit from the start of the line assumed
    ///            at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        var distance: TRFloat = 0
        _ = TRComposedLineGetCodeUnitDistance(core, TRUInteger(index), &distance)

        return CGFloat(distance)
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

        withUnsafeMutablePointer(to: &edges) { (pointer) in
            _ = TRComposedLineEnumerateVisualEdges(
                core,
                TRUInteger(clampedRange.lowerBound),
                TRUInteger(clampedRange.count),
                { (user, left, right, _) in
                    let edges = user!.assumingMemoryBound(to: [CGFloat].self)
                    edges.pointee.append(CGFloat(left))
                    edges.pointee.append(CGFloat(right))
                },
                pointer
            )
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
        return Int(TRComposedLineGetCodeUnitIndexAtDistance(core, TRFloat(distance)))
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

    /// Calculates the ink box of this line, which is the smallest rectangle that encloses what is
    /// drawn for its glyphs, relative to the origin of the line. It is a null rectangle if nothing
    /// is drawn.
    ///
    /// The renderer is set up for each run while it is measured, and gets back what it had.
    ///
    /// - Parameter renderer: The renderer with the glyph cache to use, and with the settings that
    ///                       are not the runs'.
    /// - Returns: A rectangle that tightly encloses the glyphs of this line.
    public func computeInkBox(with renderer: Renderer) -> CGRect {
        return CGRect(inkBox: TRComposedLineComputeInkBox(core, renderer.core))
    }

    /// Draws this line in the `context` with the specified renderer. The runs are drawn one after
    /// another in their visual order: the background, the glyphs and then the decorations of a run,
    /// before those of the next one. The backgrounds are as tall as the line.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw the line.
    ///   - context: The context in which to draw the line.
    public func draw(with renderer: Renderer, in context: CGContext) {
        // The origin of the line is where it is placed in its frame. Here it is drawn at the
        // current position of the context, so the origin is taken back.
        let origin = TRPoint(
            x: -TRComposedLineGetOrigin(core).x,
            y: -TRComposedLineGetOrigin(core).y
        )

        renderer.withDrawing(in: context, objects: objects) {
            TRComposedLineDraw(core, renderer.core, origin)
        }
    }
}
