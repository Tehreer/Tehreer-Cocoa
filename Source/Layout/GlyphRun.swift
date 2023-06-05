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

/// A glyph run is a collection of consecutive glyphs sharing the same attributes and direction.
public class GlyphRun {
    var textRun: TextRun

    init(textRun: TextRun) {
        self.textRun = textRun
        self.origin = .zero
    }

    init(_ other: GlyphRun) {
        self.textRun = other.textRun
        self.origin = other.origin
    }

    /// The UTF-16 range of this run in source string.
    public var codeUnitRange: Range<Int> {
        return textRun.codeUnitRange
    }

    /// The index to the first character of this run in source string.
    public var startIndex: String.Index {
        return textRun.startIndex
    }

    /// The index after the last character of this run in source string.
    public var endIndex: String.Index {
        return textRun.endIndex
    }

    /// The extra excluded length at the start of the cluster map.
    ///
    /// If the first cluster of this run begins within the extra range, then its rendering will be
    /// clipped from the start. The amount of clipping would be equal to the perceived trailing
    /// caret position of last excluded character.
    ///
    /// For example, consider three characters `f`, `i` and another `i` form a cluster having a
    /// single ligature, `fii` and the run starts from the second `i` with `f` and `i` being extra
    /// characters. In this case, the ligature would be divided into three equal parts and the first
    /// two parts would be clipped.
    public var startExtraLength: Int {
        return textRun.startExtraLength
    }

    /// The extra excluded length at the end of the cluster map.
    ///
    /// If the last cluster of this run finishes within the excluded range, then its rendering will
    /// be clipped from the end. The amount of clipping would be equal to the perceived leading
    /// caret position of first excluded character.
    ///
    /// For example, consider three characters `f`, `i` and another `i` form a cluster having a
    /// single ligature, `fii` and the run consists of just `f` with both `i` being extra
    /// characters. In this case, the ligature would be divided into three equal parts and the last
    /// two parts would be clipped.
    public var endExtraLength: Int {
        return textRun.endExtraLength
    }

    /// The bidirectional level of this run.
    public var bidiLevel: UInt8 {
        return textRun.bidiLevel
    }

    /// The writing direction of this run.
    public var writingDirection: WritingDirection {
        return textRun.writingDirection
    }

    /// The typeface of this run.
    public var typeface: Typeface {
        return textRun.typeface
    }

    /// The type size of this run.
    public var typeSize: CGFloat {
        return textRun.typeSize
    }

    /// The ascent of this run, which is the distance from the top of the run to the baseline. It is
    /// always either positive or zero.
    public var ascent: CGFloat {
        return textRun.ascent
    }

    /// The descent of this run, which is the distance from the baseline to the bottom of the run.
    /// It is always either positive or zero.
    public var descent: CGFloat {
        return textRun.descent
    }

    /// The leading of this run, which is the distance that should be placed between two lines.
    public var leading: CGFloat {
        return textRun.leading
    }

    /// The origin of this run in parent line.
    public internal(set) var origin: CGPoint = .zero

    /// The typographic width of this run.
    public var width: CGFloat {
        return textRun.width
    }

    /// The typographic height of this run.
    public var height: CGFloat {
        return textRun.height
    }

    /// The glyph IDs of this run.
    public var glyphIDs: PrimitiveCollection<GlyphID> {
        return textRun.glyphIDs
    }

    /// The glyph offsets of this run.
    public var glyphOffsets: PrimitiveCollection<CGPoint> {
        return textRun.glyphOffsets
    }

    /// The glyph advances of this run.
    public var glyphAdvances: PrimitiveCollection<CGFloat> {
        return textRun.glyphAdvances
    }

    /// The indexes, mapping each code unit of this run to corresponding glyph.
    public var clusterMap: PrimitiveCollection<Int> {
        return textRun.clusterMap
    }

    /// Returns the index to the first UTF-16 code unit of specified cluster in source string. In
    /// most cases, it would be the same index as the specified one. But if the code unit occurs
    /// within a cluster, then a previous index would be returned; whether the run logically flows
    /// forward or backward.
    ///
    /// - Parameter index: The index of a code unit in source string.
    /// - Returns: The index to the first code unit of specified cluster in source string.
    public func clusterStart(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return textRun.clusterStart(forCodeUnitAt: index)
    }

    /// Returns the index to the first character of specified cluster in source string. In most
    /// cases, it would be the same index as the specified one. But if the character occurs within
    /// a cluster, then a previous index would be returned; whether the run logically flows forward
    /// or backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index to the first character of specified cluster in source string.
    public func clusterStart(forCharacterAt index: String.Index) -> String.Index {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return textRun.clusterStart(forCharacterAt: index)
    }

    /// Returns the index after the last UTF-16 code unit of specified cluster in source string. In
    /// most cases, it would be an index after the specified one. But if the code unit occurs within
    /// a cluster, then a farther index would be returned; whether the run logically flows forward
    /// or backward.
    ///
    /// - Parameter index: The index of a code unit in source string.
    /// - Returns: The index after the last code unit of specified cluster in source string.
    public func clusterEnd(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return textRun.clusterEnd(forCodeUnitAt: index)
    }

    /// Returns the index after the last character of specified cluster in source string. In most
    /// cases, it would be an index after the specified one. But if the character occurs within a
    /// cluster, then a farther index would be returned; whether the run logically flows forward or
    /// backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index after the last character of specified cluster in source string.
    public func clusterEnd(forCharacterAt index: String.Index) -> String.Index {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return textRun.clusterEnd(forCharacterAt: index)
    }

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return textRun.leadingGlyphIndex(forCodeUnitAt: index)
    }

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return textRun.leadingGlyphIndex(forCharacterAt: index)
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return textRun.trailingGlyphIndex(forCodeUnitAt: index)
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return textRun.trailingGlyphIndex(forCharacterAt: index)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        return textRun.caretEdge(forCodeUnitAt: index)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCharacterAt index: String.Index) -> CGFloat {
        precondition(index >= startIndex && index <= endIndex, .indexOutOfRange)

        return textRun.caretEdge(forCharacterAt: index)
    }

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat {
        return textRun.distance(forCodeUnitRange: range)
    }

    /// Determines the index of a UTF-16 code unit nearest to the specified distance.
    ///
    /// The process involves iterating over the clusters of the glyph run. If a cluster consists of
    /// multiple characters, its total advance is evenly distributed among the number of characters
    /// it contains. The advance of each character is added to track the covered distance. This way
    /// leading and trailing characters are determined close to the specified distance. Afterwards,
    /// the index of nearer character is returned.
    ///
    /// If `distance` is negative, then run's starting index is returned. If it is beyond run's
    /// extent, then ending index is returned. The indices will be reversed in case of right-to-left
    /// run.
    ///
    /// - Parameters:
    ///   - distance: The distance for which to determine the UTF-16 code unit index. It should be offset
    ///               from zero origin.
    /// - Returns: The index of UTF-16 code unit in source string, nearest to the specified distance.
    public func indexOfCodeUnit(at distance: CGFloat) -> Int {
        return textRun.indexOfCodeUnit(at: distance)
    }

    /// Determines the index of a character nearest to the specified distance.
    ///
    /// The process involves iterating over the clusters of the glyph run. If a cluster consists of
    /// multiple characters, its total advance is evenly distributed among the number of characters
    /// it contains. The advance of each character is added to track the covered distance. This way
    /// leading and trailing characters are determined close to the specified distance. Afterwards,
    /// the index of nearer character is returned.
    ///
    /// If `distance` is negative, then run's starting index is returned. If it is beyond run's
    /// extent, then ending index is returned. The indices will be reversed in case of right-to-left
    /// run.
    ///
    /// - Parameters:
    ///   - distance: The distance for which to determine the character index. It should be offset
    ///               from zero origin.
    /// - Returns: The index of character in source string, nearest to the specified distance.
    public func indexOfCharacter(at distance: CGFloat) -> String.Index {
        return textRun.indexOfCharacter(at: distance)
    }

    func computeBoundingBox(with renderer: Renderer) -> CGRect {
        return computeBoundingBox(forGlyphRange: 0 ..< glyphIDs.count, with: renderer)
    }

    /// Calculates the bounding box for the specified glyph range in this run. The bounding box is a
    /// rectangle that encloses the paths of glyphs, as tightly as possible.
    ///
    /// - Parameters:
    ///   - glyphRange: The range of glyphs to be measured.
    /// - Returns: A rectangle that tightly encloses the paths of glyphs in the specified range.
    public func computeBoundingBox(forGlyphRange glyphRange: Range<Int>, with renderer: Renderer) -> CGRect {
        return textRun.computeBoundingBox(forGlyphRange: glyphRange, with: renderer)
    }

    /// Draws this run in the `context` with the specified `renderer`.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw this run.
    ///   - context: The context in which to draw this run.
    public func draw(with renderer: Renderer, in context: CGContext) {
        textRun.draw(with: renderer, in: context)
    }
}
