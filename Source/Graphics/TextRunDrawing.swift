//
// Copyright (C) 2023 Muhammad Tayyab Akram
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

protocol TextRunDrawing {
    func draw(with renderer: Renderer, in context: CGContext)
}

struct DefaultTextRunDrawing: TextRunDrawing {
    let textRun: TextRun

    private func leadingEdge(
        from start: Int,
        to end: Int
    ) -> CGFloat {
        return textRun.caretEdge(forCodeUnitAt: !textRun.isBackward ? start : end)
    }

    private func clusterRange(forCodeUnitAt index: Int, exclusion: ClusterRange?) -> ClusterRange? {
        let actualStart = textRun.clusterStart(forCodeUnitAt: index)
        let actualEnd = textRun.clusterEnd(forCodeUnitAt: index)

        let leadingIndex = textRun.leadingGlyphIndex(forCodeUnitAt: index)
        let trailingIndex = textRun.trailingGlyphIndex(forCodeUnitAt: index)

        var cluster = ClusterRange(
            actualStart: actualStart,
            actualEnd: actualEnd,
            glyphStart: min(leadingIndex, trailingIndex),
            glyphEnd: max(leadingIndex, trailingIndex) + 1
        )

        if let exclusion = exclusion {
            let minStart = min(exclusion.glyphStart, cluster.glyphEnd)
            let maxEnd = max(cluster.glyphStart, exclusion.glyphEnd)
            let isBackward = textRun.isBackward

            cluster.glyphStart = (!isBackward ? maxEnd : cluster.glyphStart)
            cluster.glyphEnd = (isBackward ? minStart : cluster.glyphEnd)
        }

        if cluster.glyphStart < cluster.glyphEnd {
            return cluster
        }

        return nil
    }

    private func drawEdgeCluster(
        _ cluster: ClusterRange,
        with renderer: Renderer,
        in context: CGContext
    ) {
        let codeUnitRange = textRun.codeUnitRange
        let runStart = codeUnitRange.lowerBound
        let runEnd = codeUnitRange.upperBound

        let startClipped = (cluster.actualStart < runStart)
        let endClipped = (cluster.actualEnd > runEnd)

        let bbox = context.boundingBoxOfClipPath
        let clipLeft: CGFloat
        let clipRight: CGFloat

        let isBackward = textRun.isBackward
        let isRTL = textRun.isRTL

        if !isRTL {
            clipLeft = (startClipped ? textRun.caretEdge(forCodeUnitAt: codeUnitRange.lowerBound) : bbox.minX)
            clipRight = (endClipped ? textRun.caretEdge(forCodeUnitAt: codeUnitRange.upperBound) : bbox.maxX)
        } else {
            clipRight = (startClipped ? textRun.caretEdge(forCodeUnitAt: codeUnitRange.lowerBound) : bbox.maxX)
            clipLeft = (endClipped ? textRun.caretEdge(forCodeUnitAt: codeUnitRange.upperBound) : bbox.minX)
        }

        context.saveGState()
        context.clip(to: CGRect(x: clipLeft, y: bbox.minY, width: clipRight - clipLeft, height: bbox.height))
        context.translateBy(
            x: leadingEdge(from: cluster.actualStart, to: cluster.actualEnd),
            y: 0.0
        )

        renderer.drawGlyphs(
            in: context,
            glyphIDs: textRun.glyphIDs[cluster.glyphStart ..< cluster.glyphEnd],
            offsets: textRun.glyphOffsets[cluster.glyphStart ..< cluster.glyphEnd],
            advances: textRun.glyphAdvances[cluster.glyphStart ..< cluster.glyphEnd]
        )

        context.restoreGState()
    }

    func draw(with renderer: Renderer, in context: CGContext) {
        renderer.typeface = textRun.typeface
        renderer.typeSize = textRun.typeSize
        renderer.scaleX = 1.0
        renderer.scaleY = 1.0
        renderer.writingDirection = textRun.writingDirection

        let defaultFillColor = renderer.fillColor

        for (key, value) in textRun.attributes {
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

        let codeUnitRange = textRun.codeUnitRange
        let firstIndex = codeUnitRange.lowerBound
        let lastIndex = codeUnitRange.upperBound - 1

        var firstCluster: ClusterRange? = nil
        var lastCluster: ClusterRange? = nil

        if textRun.startExtraLength > 0 {
            firstCluster = clusterRange(forCodeUnitAt: firstIndex, exclusion: nil)
        }
        if textRun.endExtraLength > 0 {
            lastCluster = clusterRange(forCodeUnitAt: lastIndex, exclusion: firstCluster)
        }

        let isBackward = textRun.isBackward
        let caretBoundary = textRun.caretBoundary(forCodeUnitRange: codeUnitRange)

        var glyphStart: Int = 0
        var glyphEnd = textRun.glyphIDs.count

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
            glyphIDs: textRun.glyphIDs[glyphStart ..< glyphEnd],
            offsets: textRun.glyphOffsets[glyphStart ..< glyphEnd],
            advances: textRun.glyphAdvances[glyphStart ..< glyphEnd]
        )

        context.restoreGState()

        if let lastCluster = lastCluster {
            drawEdgeCluster(lastCluster, with: renderer, in: context)
        }

        renderer.fillColor = defaultFillColor
    }
}
