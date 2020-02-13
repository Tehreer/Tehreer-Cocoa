//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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

private struct ClusterRange {
    var actualStart: Int
    var actualEnd: Int
    var glyphStart: Int
    var glyphEnd: Int
}

/// A glyph run is a collection of consecutive glyphs sharing the same attributes and direction.
public class GlyphRun {
    private let string: String
    private let codeUnitRange: Range<Int>
    private let attributes: [NSAttributedString.Key: Any]
    private let isBackward: Bool
    private let caretEdges: PrimitiveCollection<CGFloat>

    init(string: String, codeUnitRange: Range<Int>, startExtraLength: Int, endExtraLength: Int,
         attributes: [NSAttributedString.Key: Any], isBackward: Bool, bidiLevel: UInt8,
         writingDirection: WritingDirection, typeface: Typeface, typeSize: CGFloat,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         glyphIDs: PrimitiveCollection<GlyphID>, glyphOffsets: PrimitiveCollection<CGPoint>,
         glyphAdvances: PrimitiveCollection<CGFloat>,
         clusterMap: PrimitiveCollection<Int>, caretEdges: PrimitiveCollection<CGFloat>) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.startExtraLength = startExtraLength
        self.endExtraLength = endExtraLength
        self.attributes = attributes
        self.isBackward = isBackward
        self.bidiLevel = bidiLevel
        self.writingDirection = writingDirection
        self.typeface = typeface
        self.typeSize = typeSize
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.glyphIDs = glyphIDs
        self.glyphOffsets = glyphOffsets
        self.glyphAdvances = glyphAdvances
        self.clusterMap = clusterMap
        self.caretEdges = caretEdges
    }

    init(_ other: GlyphRun) {
        self.string = other.string
        self.codeUnitRange = other.codeUnitRange
        self.startExtraLength = other.startExtraLength
        self.endExtraLength = other.endExtraLength
        self.attributes = other.attributes
        self.isBackward = other.isBackward
        self.bidiLevel = other.bidiLevel
        self.writingDirection = other.writingDirection
        self.typeface = other.typeface
        self.typeSize = other.typeSize
        self.ascent = other.ascent
        self.descent = other.descent
        self.leading = other.leading
        self.glyphIDs = other.glyphIDs
        self.glyphOffsets = other.glyphOffsets
        self.glyphAdvances = other.glyphAdvances
        self.clusterMap = other.clusterMap
        self.caretEdges = other.caretEdges
        self.origin = other.origin
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
    public let startExtraLength: Int

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
    public let endExtraLength: Int

    /// The bidirectional level of this run.
    public let bidiLevel: UInt8

    private var isRTL: Bool {
        return (bidiLevel & 1) == 1
    }

    /// The writing direction of this run.
    public let writingDirection: WritingDirection

    /// The typeface of this run.
    public let typeface: Typeface

    /// The type size of this run.
    public let typeSize: CGFloat

    /// The ascent of this run, which is the distance from the top of the run to the baseline. It is
    /// always either positive or zero.
    public let ascent: CGFloat

    /// The descent of this run, which is the distance from the baseline to the bottom of the run.
    /// It is always either positive or zero.
    public let descent: CGFloat

    /// The leading of this run, which is the distance that should be placed between two lines.
    public let leading: CGFloat

    /// The origin of this run in parent line.
    public internal(set) var origin: CGPoint = .zero

    /// The typographic width of this run.
    public var width: CGFloat {
        return distance(forCodeUnitRange: codeUnitRange)
    }

    /// The typographic height of this run.
    public var height: CGFloat {
        return ascent + descent + leading
    }

    private var glyphCount: Int {
        return glyphIDs.count
    }

    /// The glyph IDs of this run.
    public let glyphIDs: PrimitiveCollection<GlyphID>

    /// The glyph offsets of this run.
    public let glyphOffsets: PrimitiveCollection<CGPoint>

    /// The glyph advances of this run.
    public let glyphAdvances: PrimitiveCollection<CGFloat>

    /// The indexes, mapping each code unit of this run to corresponding glyph.
    public let clusterMap: PrimitiveCollection<Int>

    /// Returns the index to the first UTF-16 code unit of specified cluster in source string. In
    /// most cases, it would be the same index as the specified one. But if the code unit occurs
    /// within a cluster, then a previous index would be returned; whether the run logically flows
    /// forward or backward.
    ///
    /// - Parameter index: The index of a code unit in source string.
    /// - Returns: The index to the first code unit of specified cluster in source string.
    public func clusterStart(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), String.indexOutOfRange)

        let extraStart = codeUnitRange.lowerBound - startExtraLength
        let arrayIndex = index - extraStart

        return Clusters.actualClusterStart(in: clusterMap, for: arrayIndex) + extraStart
    }

    /// Returns the index to the first character of specified cluster in source string. In most
    /// cases, it would be the same index as the specified one. But if the character occurs within
    /// a cluster, then a previous index would be returned; whether the run logically flows forward
    /// or backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index to the first character of specified cluster in source string.
    public func clusterStart(forCharacterAt index: String.Index) -> String.Index {
        precondition(index >= startIndex && index < endIndex, String.indexOutOfRange)

        let inputIndex = string.utf16Index(forCharacterAt: index)
        let actualIndex = clusterStart(forCodeUnitAt: inputIndex)

        return string.characterIndex(forUTF16Index: actualIndex)
    }

    /// Returns the index after the last UTF-16 code unit of specified cluster in source string. In
    /// most cases, it would be an index after the specified one. But if the code unit occurs within
    /// a cluster, then a farther index would be returned; whether the run logically flows forward
    /// or backward.
    ///
    /// - Parameter index: The index of a code unit in source string.
    /// - Returns: The index after the last code unit of specified cluster in source string.
    public func clusterEnd(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), String.indexOutOfRange)

        let extraStart = codeUnitRange.lowerBound - startExtraLength
        let arrayIndex = index - extraStart

        return Clusters.actualClusterEnd(in: clusterMap, for: arrayIndex) + extraStart
    }

    /// Returns the index after the last character of specified cluster in source string. In most
    /// cases, it would be an index after the specified one. But if the character occurs within a
    /// cluster, then a farther index would be returned; whether the run logically flows forward or
    /// backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index after the last character of specified cluster in source string.
    public func clusterEnd(forCharacterAt index: String.Index) -> String.Index {
        precondition(index >= startIndex && index < endIndex, String.indexOutOfRange)

        let inputIndex = string.utf16Index(forCharacterAt: index)
        let actualIndex = clusterEnd(forCodeUnitAt: inputIndex)

        return string.characterIndex(forUTF16Index: actualIndex)
    }

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), String.indexOutOfRange)

        let extraStart = codeUnitRange.lowerBound - startExtraLength
        let arrayIndex = index - extraStart

        return Clusters.leadingGlyphIndex(in: clusterMap, for: arrayIndex,
                                          isBackward: isBackward, glyphCount: glyphCount)
    }

    /// Returns the index of leading glyph related to the specified cluster. It will come after the
    /// trailing glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of leading glyph related to the specified cluster.
    public func leadingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, String.indexOutOfRange)

        return leadingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCodeUnitAt index: Int) -> Int {
        precondition(codeUnitRange.contains(index), String.indexOutOfRange)

        let extraStart = codeUnitRange.lowerBound - startExtraLength
        let arrayIndex = index - extraStart

        return Clusters.trailingGlyphIndex(in: clusterMap, for: arrayIndex,
                                           isBackward: isBackward, glyphCount: glyphCount)
    }

    /// Returns the index of trailing glyph related to the specified cluster. It will come before
    /// the leading glyph, if the characters of this run logically flow backward.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The index of trailing glyph related to the specified cluster.
    public func trailingGlyphIndex(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index < endIndex, String.indexOutOfRange)

        return trailingGlyphIndex(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    private func caretEdge(forCodeUnitAt index: Int) -> CGFloat {
        let extraStart = codeUnitRange.lowerBound - startExtraLength
        let arrayIndex = index - extraStart

        return caretEdges[arrayIndex]
    }

    private func caretEdge(forCharacterAt index: String.Index) -> CGFloat {
        return caretEdge(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    private func leadingEdge(from start: Int, to end: Int) -> CGFloat {
        return caretEdge(forCodeUnitAt: !isBackward ? start : end)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a UTF-16 code unit in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCodeUnitAt index: Int) -> CGFloat {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, String.indexOutOfRange)

        return caretEdge(forCodeUnitAt: index)
    }

    /// Returns the distance of specified character from the start of the run assumed at zero.
    ///
    /// - Parameter index: The index of a character in source string.
    /// - Returns: The distance of specified character from the start of the run assumed at zero.
    public func distance(forCharacterAt index: String.Index) -> CGFloat {
        precondition(index >= startIndex && index <= endIndex, String.indexOutOfRange)

        return caretEdge(forCharacterAt: index)
    }

    func distance(forCodeUnitRange range: Range<Int>) -> CGFloat {
        let extraStart = codeUnitRange.lowerBound - startExtraLength

        let lowerBound = range.lowerBound - extraStart
        let upperBound = range.upperBound - extraStart

        let lowerEdge = caretEdges[lowerBound]
        let upperEdge = caretEdges[upperBound]

        return isRTL ? lowerEdge - upperEdge : upperEdge - lowerEdge
    }

    func distance(forCharacterRange range: Range<String.Index>) -> CGFloat {
        return distance(forCodeUnitRange: string.utf16Range(forCharacterRange: range))
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
        let extraStart = codeUnitRange.lowerBound - startExtraLength

        var leadingCharIndex: Int = -1
        var trailingCharIndex: Int = -1

        var leadingCaretEdge: CGFloat = .zero
        var trailingCaretEdge: CGFloat = .zero

        var index = isRTL ? codeUnitRange.upperBound : codeUnitRange.lowerBound
        let next = isRTL ? -1 : 1

        while index <= codeUnitRange.upperBound && index >= codeUnitRange.lowerBound {
            let caretEdge = caretEdges[index - extraStart]

            if caretEdge <= distance {
                leadingCharIndex = index
                leadingCaretEdge = caretEdge
            } else {
                trailingCharIndex = index
                trailingCaretEdge = caretEdge
                break
            }

            index += next
        }

        if leadingCharIndex == -1 {
            // No char is covered by the input distance.
            return codeUnitRange.lowerBound
        }

        if trailingCharIndex == -1 {
            // Whole run is covered by the input distance.
            return codeUnitRange.upperBound
        }

        if distance <= (leadingCaretEdge + trailingCaretEdge) / 2.0 {
            // Input distance is closer to first edge.
            return leadingCharIndex
        }

        // Input distance is closer to second edge.
        return trailingCharIndex
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

    /// Calculates the bounding box for the specified glyph range in this run. The bounding box is a
    /// rectangle that encloses the paths of glyphs, as tightly as possible.
    ///
    /// - Parameters:
    ///   - glyphRange: The range of glyphs to be measured.
    /// - Returns: A rectangle that tightly encloses the paths of glyphs in the specified range.
    public func computeBoundingBox(forGlyphRange glyphRange: Range<Int>, with renderer: Renderer) -> CGRect {
        renderer.typeface = typeface
        renderer.typeSize = typeSize
        renderer.writingDirection = writingDirection

        return renderer.computeBoundingBox(forGlyphs: glyphIDs[glyphRange],
                                           offsets: glyphOffsets[glyphRange],
                                           advances: glyphAdvances[glyphRange])
    }

    /// Calculates the typographic extent for the given glyph range in this run. The typographic
    /// extent is equal to the sum of advances of glyphs.
    ///
    /// - Parameters:
    ///   - glyphRange: The range of glyphs to be measured.
    /// - Returns: The typographic extent for the specified glyph range in the run.
    public func typographicExtent(forGlyphRange glyphRange: Range<Int>) -> CGFloat {
        var extent: CGFloat = 0.0

        for i in glyphRange {
            extent += glyphAdvances[i]
        }

        return extent
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
            glyphEnd: max(leadingIndex, trailingIndex) + 1)

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

    private func drawEdgeCluster(using renderer: Renderer, in context: CGContext, cluster: ClusterRange) {
        let startClipped = (cluster.actualStart < codeUnitRange.lowerBound)
        let endClipped = (cluster.actualEnd > codeUnitRange.upperBound)

        let bbox = context.boundingBoxOfClipPath
        let clipLeft: CGFloat
        let clipRight: CGFloat

        if !isRTL {
            clipLeft = (startClipped ? caretEdge(forCodeUnitAt: codeUnitRange.lowerBound) : bbox.minX)
            clipRight = (endClipped ? caretEdge(forCodeUnitAt: codeUnitRange.upperBound) : bbox.maxX)
        } else {
            clipRight = (startClipped ? caretEdge(forCodeUnitAt: codeUnitRange.lowerBound) : bbox.maxX)
            clipLeft = (endClipped ? caretEdge(forCodeUnitAt: codeUnitRange.upperBound) : bbox.minX)
        }

        context.saveGState()
        context.clip(to: CGRect(x: clipLeft, y: bbox.minY, width: clipRight - clipLeft, height: bbox.height))
        context.translateBy(x: leadingEdge(from: cluster.actualStart, to: cluster.actualEnd), y: 0.0)

        renderer.drawGlyphs(in: context,
                            glyphIDs: glyphIDs[cluster.glyphStart ..< cluster.glyphEnd],
                            offsets: glyphOffsets[cluster.glyphStart ..< cluster.glyphEnd],
                            advances: glyphAdvances[cluster.glyphStart ..< cluster.glyphEnd])

        context.restoreGState()
    }

    /// Draws this run in the `context` with the specified `renderer`.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw this run.
    ///   - context: The context in which to draw this run.
    public func draw(with renderer: Renderer, in context: CGContext) {
        renderer.typeface = typeface
        renderer.typeSize = typeSize
        renderer.scaleX = 1.0
        renderer.scaleY = 1.0
        renderer.writingDirection = writingDirection

        for (key, value) in attributes {
            switch key {
            case .scaleX:
                if let scaleX = value as? CGFloat {
                    renderer.scaleX = scaleX
                }
            case .scaleY:
                if let scaleY = value as? CGFloat {
                    renderer.scaleY = scaleY
                }
            case .foregroundColor:
                if let color = value as? UIColor {
                    renderer.fillColor = color
                }
            default:
                break
            }
        }

        var firstCluster: ClusterRange? = nil
        var lastCluster: ClusterRange? = nil

        if startExtraLength > 0 {
            firstCluster = clusterRange(forCodeUnitAt: codeUnitRange.lowerBound, exclusion: nil)
        }
        if endExtraLength > 0 {
            lastCluster = clusterRange(forCodeUnitAt: codeUnitRange.upperBound - 1, exclusion: firstCluster)
        }

        var glyphStart: Int = 0
        var glyphEnd = glyphCount

        var chunkStart = codeUnitRange.lowerBound
        var chunkEnd = codeUnitRange.upperBound

        if let firstCluster = firstCluster {
            drawEdgeCluster(using: renderer, in: context, cluster: firstCluster)

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

        renderer.drawGlyphs(in: context,
                            glyphIDs: glyphIDs[glyphStart ..< glyphEnd],
                            offsets: glyphOffsets[glyphStart ..< glyphEnd],
                            advances: glyphAdvances[glyphStart ..< glyphEnd])

        context.restoreGState()

        if let lastCluster = lastCluster {
            drawEdgeCluster(using: renderer, in: context, cluster: lastCluster)
        }
    }
}
