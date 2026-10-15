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
import UIKit

/// A glyph run is a collection of consecutive glyphs sharing the same attributes and direction.
// Unchecked because the run of Core is immutable, and the rest is set once in the initializer.
public final class GlyphRun: @unchecked Sendable {
    private let core: TRGlyphRunRef
    private let string: String

    private let objects: CoreTextObjects

    init(core: TRGlyphRunRef, string: String, objects: CoreTextObjects) {
        self.core = TRGlyphRunRetain(core)
        self.string = string
        self.objects = objects
    }

    deinit {
        TRGlyphRunRelease(core)
    }

    /// The replacement that this run is for, if its glyphs do not come from the text.
    var replacement: TextReplacement? {
        return TRGlyphRunGetReplacement(core).flatMap { objects.replacements[UnsafeRawPointer($0)] }
    }

    /// The UTF-16 range of this run in source string.
    public var codeUnitRange: Range<Int> {
        return Int(TRGlyphRunGetStartIndex(core)) ..< Int(TRGlyphRunGetEndIndex(core))
    }

    /// The index to the first character of this run in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this run in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
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
        return Int(TRGlyphRunGetStartExtraLength(core))
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
        return Int(TRGlyphRunGetEndExtraLength(core))
    }

    /// The bidirectional level of this run.
    public var bidiLevel: UInt8 {
        return TRGlyphRunGetBidiLevel(core)
    }

    /// The writing direction of this run.
    public var writingDirection: WritingDirection {
        return WritingDirection(coreValue: TRGlyphRunGetWritingDirection(core))
    }

    /// The typeface of this run.
    public var typeface: Typeface {
        // The typeface was given by the text, or by its default attributes, and is kept by the
        // typesetter that made the line.
        guard let typeface = objects.typefaces[TRGlyphRunGetTypeface(core)] else {
            fatalError("Typeface of the run is unknown")
        }

        return typeface
    }

    /// The type size of this run.
    public var typeSize: CGFloat {
        return CGFloat(TRGlyphRunGetTypeSize(core))
    }

    /// The ascent of this run, which is the distance from the top of the run to the baseline. It is
    /// always either positive or zero.
    public var ascent: CGFloat {
        return CGFloat(TRGlyphRunGetAscent(core))
    }

    /// The descent of this run, which is the distance from the baseline to the bottom of the run.
    /// It is always either positive or zero.
    public var descent: CGFloat {
        return CGFloat(TRGlyphRunGetDescent(core))
    }

    /// The leading of this run, which is the distance that should be placed between two lines.
    public var leading: CGFloat {
        return CGFloat(TRGlyphRunGetLeading(core))
    }

    /// The origin of this run in parent line.
    public var origin: CGPoint {
        return CGPoint(TRGlyphRunGetOrigin(core))
    }

    /// The typographic width of this run.
    public var width: CGFloat {
        return CGFloat(TRGlyphRunGetWidth(core))
    }

    /// The typographic height of this run.
    public var height: CGFloat {
        return CGFloat(TRGlyphRunGetHeight(core))
    }

    /// The foreground color of this run, or `nil` if the text does not set one, in which case the
    /// run is drawn with the fill color of the renderer.
    public var foregroundColor: UIColor? {
        var color: TRColor = 0

        return TRGlyphRunGetForegroundColor(core, &color) != 0 ? UIColor(coreValue: color) : nil
    }

    /// The background color of this run, or `nil` if the text does not set one.
    public var backgroundColor: UIColor? {
        var color: TRColor = 0

        return TRGlyphRunGetBackgroundColor(core, &color) != 0 ? UIColor(coreValue: color) : nil
    }

    /// A Boolean value that indicates whether the text underlines this run.
    public var hasUnderline: Bool {
        return TRGlyphRunHasUnderline(core) != 0
    }

    /// A Boolean value that indicates whether the text strikes this run through.
    public var hasStrikethrough: Bool {
        return TRGlyphRunHasStrikethrough(core) != 0
    }

    /// The color of the underline and the strikethrough of this run, or `nil` if the text does not
    /// set one, in which case they are drawn with the foreground color.
    public var decorationColor: UIColor? {
        var color: TRColor = 0

        return TRGlyphRunGetDecorationColor(core, &color) != 0 ? UIColor(coreValue: color) : nil
    }

    private var glyphCount: Int {
        return Int(TRGlyphRunGetGlyphCount(core))
    }

    /// The glyph IDs of this run.
    public var glyphIDs: PrimitiveCollection<GlyphID> {
        return PrimitiveCollection(CoreCollection(owner: self,
                                                  pointer: TRGlyphRunGetGlyphIDsPtr(core),
                                                  count: glyphCount) { $0 })
    }

    /// The glyph offsets of this run.
    public var glyphOffsets: PrimitiveCollection<CGPoint> {
        return PrimitiveCollection(CoreCollection(owner: self,
                                                  pointer: TRGlyphRunGetGlyphOffsetsPtr(core),
                                                  count: glyphCount) { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
    }

    /// The glyph advances of this run.
    public var glyphAdvances: PrimitiveCollection<CGFloat> {
        return PrimitiveCollection(CoreCollection(owner: self,
                                                  pointer: TRGlyphRunGetGlyphAdvancesPtr(core),
                                                  count: glyphCount) { CGFloat($0) })
    }

    /// The indexes, mapping each code unit of this run to corresponding glyph.
    public var clusterMap: PrimitiveCollection<Int> {
        return PrimitiveCollection(CoreCollection(owner: self,
                                                  pointer: TRGlyphRunGetClusterMapPtr(core),
                                                  count: Int(TRGlyphRunGetClusterMapCount(core))) { Int($0) })
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

        return Int(TRGlyphRunGetClusterStart(core, TRUInteger(index)))
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

        let start = clusterStart(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
        return string.characterIndex(forUTF16Index: start)
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

        return Int(TRGlyphRunGetClusterEnd(core, TRUInteger(index)))
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

        let end = clusterEnd(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
        return string.characterIndex(forUTF16Index: end)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        var distance: TRFloat = 0
        _ = TRGlyphRunGetCodeUnitDistance(core, TRUInteger(index), &distance)

        return CGFloat(distance)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCharacterAt index: String.Index) -> CGFloat {
        precondition(index >= startIndex && index <= endIndex, .indexOutOfRange)

        return distance(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
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
        return Int(TRGlyphRunGetCodeUnitIndex(core, TRFloat(distance)))
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
        return string.characterIndex(forUTF16Index: indexOfCodeUnit(at: distance))
    }

    /// Calculates the ink box of this run. The ink box is a rectangle that encloses what is drawn
    /// for the glyphs of this run, as tightly as possible, which is not the box of their advances.
    /// It is in the coordinates of the run with the pen at the origin and the y axis pointing down.
    ///
    /// The renderer is set up for the run while it is measured, and gets back what it had.
    ///
    /// - Parameter renderer: The renderer with the glyph cache to use, and with the settings that
    ///                       are not the run's.
    /// - Returns: A rectangle that tightly encloses the glyphs of this run.
    public func computeInkBox(with renderer: Renderer) -> CGRect {
        return CGRect(TRGlyphRunComputeInkBox(core, renderer.core))
    }

    // MARK: Drawing

    /// Draws this run in the `context` with the specified `renderer`. The background of the run is
    /// drawn first, then its glyphs or its replacement, and then its underline and strikethrough.
    ///
    /// The run is drawn with its foreground color, or with the fill color of the renderer if it has
    /// none. The renderer is set up for the run while it is drawn, and gets back what it had.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw this run.
    ///   - context: The context in which to draw this run.
    public func draw(with renderer: Renderer, in context: CGContext) {
        renderer.withDrawing(in: context, objects: objects) {
            TRGlyphRunDraw(core, renderer.core, TRPoint(x: 0.0, y: 0.0))
        }
    }
}
