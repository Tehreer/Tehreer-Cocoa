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

public class ComposedLine {
    private var extent: CGFloat

    init(startIndex: String.Index, endIndex: String.Index, paragraphLevel: UInt8,
         ascent: CGFloat, descent: CGFloat, leading: CGFloat, extent: CGFloat,
         trailingWhitespaceExtent: CGFloat, visualRuns: PrimitiveCollection<GlyphRun>) {
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

    public let startIndex: String.Index

    public let endIndex: String.Index

    /// The paragraph level of this line.
    public let paragraphLevel: UInt8

    /// The origin of this line in parent frame.
    public internal(set) var origin: CGPoint = .zero

    /// The ascent of this line which is the maximum ascent from the baseline of all runs.
    public let ascent: CGFloat

    /// The descent of this line which is the maximum descent from the baseline of all runs.
    public let descent: CGFloat

    /// The leading of this line which is the maximum leading of all runs.
    public let leading: CGFloat

    /// The typographic width of this line.
    public var width: CGFloat {
        return extent
    }

    /// The typographic height of this line.
    public var height: CGFloat {
        return (ascent + descent + leading)
    }

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

    public let visualRuns: PrimitiveCollection<GlyphRun>

    private func checkCharacterIndex(_ characterIndex: String.Index) {
        precondition(characterIndex >= startIndex && characterIndex < endIndex,
                     "Index is out of range")
    }

    public func distanceForCharacter(at index: String.Index) -> CGFloat {
        checkCharacterIndex(index)

        var distance: CGFloat = 0.0

        for glyphRun in visualRuns {
            if index >= glyphRun.startIndex && index < glyphRun.endIndex {
                distance += glyphRun.distanceForCharacter(at: index)
                break
            }

            distance += glyphRun.width
        }

        return distance
    }

    public func computeVisualEdges(for range: Range<String.Index>) -> [CGFloat] {
        var visualEdges: [CGFloat] = []

        for glyphRun in visualRuns {
            if glyphRun.startIndex < range.upperBound && glyphRun.endIndex > range.lowerBound {
                let selectionStart = max(range.lowerBound, glyphRun.startIndex)
                let selectionEnd = min(range.upperBound, glyphRun.endIndex)

                let leadingEdge = glyphRun.distanceForCharacter(at: selectionStart)
                let trailingEdge = glyphRun.distanceForCharacter(at: selectionEnd)

                let relativeLeft = glyphRun.origin.x
                let selectionLeft = min(leadingEdge, trailingEdge) + relativeLeft
                let selectionRight = max(leadingEdge, trailingEdge) + relativeLeft

                visualEdges.append(selectionLeft)
                visualEdges.append(selectionRight)
            }
        }

        return visualEdges
    }

    public func nearestCharacterIndex(at distance: CGFloat) -> String.Index {
        for glyphRun in visualRuns.reversed() {
            if glyphRun.origin.x <= distance {
                return glyphRun.nearestCharacterIndex(at: distance - glyphRun.origin.x)
            }
        }

        return startIndex
    }

    public func flushPenOffset(for flushFactor: CGFloat, flushExtent: CGFloat) -> CGFloat {
        var penOffset = (flushExtent - (extent - trailingWhitespaceExtent)) * flushFactor
        if (paragraphLevel & 1) == 1 {
            penOffset -= trailingWhitespaceExtent
        }

        return penOffset
    }

    public func draw(using renderer: Renderer, in context: CGContext) {
        for glyphRun in visualRuns {
            context.translateBy(x: glyphRun.origin.x, y: glyphRun.origin.y)
            glyphRun.draw(using: renderer, in: context)
            context.translateBy(x: -glyphRun.origin.x, y: -glyphRun.origin.y)
        }
    }
}
