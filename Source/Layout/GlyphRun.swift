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

    /// The typeface of Core, which is the one of the object that the text gave to Core.
    private let runTypeface: Typeface
    private let runReplacement: TextReplacement?

    init(core: TRGlyphRunRef, string: String, objects: CoreTextObjects) {
        self.core = TRGlyphRunRetain(core)
        self.string = string

        // The typeface was given by the text, or by its default attributes, and is kept by the
        // typesetter that made the line.
        guard let typeface = objects.typefaces[TRGlyphRunGetTypeface(core)] else {
            fatalError("Typeface of the run is unknown")
        }

        self.runTypeface = typeface
        self.runReplacement = TRGlyphRunGetReplacement(core).flatMap { objects.replacements[UnsafeRawPointer($0)] }
    }

    deinit {
        TRGlyphRunRelease(core)
    }

    /// The replacement that this run is for, if its glyphs do not come from the text.
    var replacement: TextReplacement? {
        return runReplacement
    }

    /// The UTF-16 range of this run in source string.
    public var codeUnitRange: Range<Int> {
        let range = TRGlyphRunGetCodeUnitRange(core)
        return Int(range.index) ..< Int(range.index + range.length)
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
        return TRGlyphRunGetWritingDirection(core) == TRWritingDirection(TRWritingDirectionRightToLeft)
            ? .rightToLeft
            : .leftToRight
    }

    /// The typeface of this run.
    public var typeface: Typeface {
        return runTypeface
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
        let origin = TRGlyphRunGetOrigin(core)
        return CGPoint(x: CGFloat(origin.x), y: CGFloat(origin.y))
    }

    /// The typographic width of this run.
    public var width: CGFloat {
        return CGFloat(TRGlyphRunGetWidth(core))
    }

    /// The typographic height of this run.
    public var height: CGFloat {
        return CGFloat(TRGlyphRunGetHeight(core))
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

    private var isBackward: Bool {
        return TRGlyphRunIsBackward(core) != 0
    }

    private var isRTL: Bool {
        return (bidiLevel & 1) == 1
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

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return Int(TRGlyphRunGetLeadingGlyphIndex(core, TRUInteger(index)))
    }

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return leadingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), .indexOutOfRange)

        return Int(TRGlyphRunGetTrailingGlyphIndex(core, TRUInteger(index)))
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, .indexOutOfRange)

        return trailingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        return CGFloat(TRGlyphRunGetDistance(core, TRUInteger(index)))
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
        return Int(TRGlyphRunGetIndexOfCodeUnit(core, TRFloat(distance)))
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

    func computeBoundingBox(with renderer: Renderer) -> CGRect {
        return computeBoundingBox(forGlyphRange: 0 ..< glyphCount, with: renderer)
    }

    /// Calculates the bounding box for the specified glyph range in this run. The bounding box is a
    /// rectangle that encloses the paths of glyphs, as tightly as possible.
    ///
    /// - Parameters:
    ///   - glyphRange: The range of glyphs to be measured.
    /// - Returns: A rectangle that tightly encloses the paths of glyphs in the specified range.
    public func computeBoundingBox(forGlyphRange glyphRange: Range<Int>, with renderer: Renderer) -> CGRect {
        let range = TRRange(index: TRUInteger(glyphRange.lowerBound), length: TRUInteger(glyphRange.count))
        let box = TRGlyphRunGetBoundingBox(core, range, renderer.core)
        renderer.syncCore()

        return CGRect(x: CGFloat(box.origin.x), y: CGFloat(box.origin.y),
                      width: CGFloat(box.size.width), height: CGFloat(box.size.height))
    }

    // MARK: Drawing

    private struct ClusterRange {
        var actualStart: Int
        var actualEnd: Int
        var glyphStart: Int
        var glyphEnd: Int
    }

    /// Returns the distance of a code unit that may belong to a cluster split by the start or the
    /// end of this run, so it can lie outside of the run.
    private func clusterDistance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound - startExtraLength
                     && index <= codeUnitRange.upperBound + endExtraLength, .indexOutOfRange)

        return CGFloat(TRGlyphRunGetClusterDistance(core, TRUInteger(index)))
    }

    private func leadingEdge(from start: Int, to end: Int) -> CGFloat {
        return clusterDistance(forCodeUnitAt: !isBackward ? start : end)
    }

    private func clusterRange(forCodeUnitAt index: Int, exclusion: ClusterRange?) -> ClusterRange? {
        let actualStart = clusterStart(forCodeUnitAt: index)
        let actualEnd = clusterEnd(forCodeUnitAt: index)

        let leadingIndex = leadingGlyphIndex(forCodeUnitAt: index)
        let trailingIndex = trailingGlyphIndex(forCodeUnitAt: index)

        var cluster = ClusterRange(
            actualStart: actualStart,
            actualEnd: actualEnd,
            glyphStart: min(leadingIndex, trailingIndex),
            glyphEnd: max(leadingIndex, trailingIndex) + 1
        )

        if let exclusion = exclusion {
            let minStart = min(exclusion.glyphStart, cluster.glyphEnd)
            let maxEnd = max(cluster.glyphStart, exclusion.glyphEnd)

            cluster.glyphStart = (!isBackward ? maxEnd : cluster.glyphStart)
            cluster.glyphEnd = (isBackward ? minStart : cluster.glyphEnd)
        }

        if cluster.glyphStart < cluster.glyphEnd {
            return cluster
        }

        return nil
    }

    private func drawEdgeCluster(_ cluster: ClusterRange, with renderer: Renderer, in context: CGContext) {
        let codeUnitRange = self.codeUnitRange
        let runStart = codeUnitRange.lowerBound
        let runEnd = codeUnitRange.upperBound

        let startClipped = (cluster.actualStart < runStart)
        let endClipped = (cluster.actualEnd > runEnd)

        let bbox = context.boundingBoxOfClipPath
        let clipLeft: CGFloat
        let clipRight: CGFloat

        if !isRTL {
            clipLeft = (startClipped ? distance(forCodeUnitAt: runStart) : bbox.minX)
            clipRight = (endClipped ? distance(forCodeUnitAt: runEnd) : bbox.maxX)
        } else {
            clipRight = (startClipped ? distance(forCodeUnitAt: runStart) : bbox.maxX)
            clipLeft = (endClipped ? distance(forCodeUnitAt: runEnd) : bbox.minX)
        }

        context.saveGState()

        context.clip(
            to: CGRect(
                x: clipLeft,
                y: bbox.minY,
                width: clipRight - clipLeft,
                height: bbox.height
            )
        )
        context.translateBy(
            x: leadingEdge(from: cluster.actualStart, to: cluster.actualEnd),
            y: 0.0
        )

        renderer.drawGlyphs(
            in: context,
            glyphIDs: glyphIDs[cluster.glyphStart ..< cluster.glyphEnd],
            offsets: glyphOffsets[cluster.glyphStart ..< cluster.glyphEnd],
            advances: glyphAdvances[cluster.glyphStart ..< cluster.glyphEnd]
        )

        context.restoreGState()
    }

    /// Draws this run in the `context` with the specified `renderer`.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw this run.
    ///   - context: The context in which to draw this run.
    public func draw(with renderer: Renderer, in context: CGContext) {
        if let replacement = replacement {
            replacement.draw(in: context)
            return
        }

        renderer.typeface = typeface
        renderer.typeSize = typeSize
        renderer.scaleX = CGFloat(TRGlyphRunGetScaleX(core))
        renderer.scaleY = CGFloat(TRGlyphRunGetScaleY(core))
        renderer.writingDirection = writingDirection

        let defaultFillColor = renderer.fillColor

        var foregroundColor: TRColor = 0
        if TRGlyphRunGetForegroundColor(core, &foregroundColor) != 0 {
            renderer.fillColor = UIColor(coreColor: foregroundColor)
        }

        let codeUnitRange = self.codeUnitRange
        let firstIndex = codeUnitRange.lowerBound
        let lastIndex = codeUnitRange.upperBound - 1

        var firstCluster: ClusterRange? = nil
        var lastCluster: ClusterRange? = nil

        if startExtraLength > 0 {
            firstCluster = clusterRange(forCodeUnitAt: firstIndex, exclusion: nil)
        }
        if endExtraLength > 0 {
            lastCluster = clusterRange(forCodeUnitAt: lastIndex, exclusion: firstCluster)
        }

        let isBackward = self.isBackward

        var glyphStart: Int = 0
        var glyphEnd = glyphCount

        var chunkStart = codeUnitRange.lowerBound
        var chunkEnd = codeUnitRange.upperBound

        if let firstCluster = firstCluster {
            drawEdgeCluster(firstCluster, with: renderer, in: context)

            // Exclude first cluster characters.
            chunkStart = firstCluster.actualEnd
            // Exclude first cluster glyphs.
            glyphStart = (!isBackward ? firstCluster.glyphEnd : glyphStart)
            glyphEnd = (isBackward ? firstCluster.glyphStart : glyphEnd)
        }
        if let lastCluster = lastCluster {
            // Exclude last cluster characters.
            chunkEnd = lastCluster.actualStart
            // Exclude last cluster glyphs.
            glyphEnd = (!isBackward ? lastCluster.glyphStart : glyphEnd)
            glyphStart = (isBackward ? lastCluster.glyphEnd : glyphStart)
        }

        context.saveGState()
        context.translateBy(x: leadingEdge(from: chunkStart, to: chunkEnd), y: 0.0)

        renderer.drawGlyphs(
            in: context,
            glyphIDs: glyphIDs[glyphStart ..< glyphEnd],
            offsets: glyphOffsets[glyphStart ..< glyphEnd],
            advances: glyphAdvances[glyphStart ..< glyphEnd]
        )

        context.restoreGState()

        if let lastCluster = lastCluster {
            drawEdgeCluster(lastCluster, with: renderer, in: context)
        }

        renderer.fillColor = defaultFillColor
    }
}
