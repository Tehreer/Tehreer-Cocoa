//
// Copyright (C) 2025 Muhammad Tayyab Akram
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

import Foundation
import SwiftUI
import UIKit

private typealias LayoutID = UUID
private typealias TextSection = Int
private typealias LineIndex = Int
private typealias SectionDictionary = [TextSection: [LineIndex]]

private var sectionHeight: CGFloat {
    let screenBounds = UIScreen.main.bounds
    return max(screenBounds.width, screenBounds.height)
}

@available(iOS 13.0, *)
private final class TextContext {
    typealias LineUpdatesBlock = @MainActor (SectionDictionary, [CGRect]) -> Void

    let layoutID: LayoutID
    let renderScale: CGFloat
    let layoutWidth: CGFloat
    let string: String?
    let attributedString: NSAttributedString?
    let typeface: Typeface?
    let textSize: CGFloat
    let textAlignment: TextAlignment
    let textColor: UIColor
    let extraLineSpacing: CGFloat
    let lineHeightMultiplier: CGFloat
    let isJustificationEnabled: Bool
    let justificationLevel: CGFloat

    private(set) var typesetter: Typesetter?
    private(set) var textFrame: ComposedFrame?

    init(
        layoutID: UUID,
        renderScale: CGFloat,
        layoutWidth: CGFloat,
        string: String?,
        attributedString: NSAttributedString?,
        typesetter: Typesetter?,
        typeface: Typeface?,
        textSize: CGFloat,
        textAlignment: TextAlignment,
        textColor: UIColor,
        extraLineSpacing: CGFloat,
        lineHeightMultiplier: CGFloat,
        isJustificationEnabled: Bool,
        justificationLevel: CGFloat
    ) {
        self.layoutID = layoutID
        self.renderScale = renderScale
        self.layoutWidth = layoutWidth
        self.string = string
        self.attributedString = attributedString
        self.typesetter = typesetter
        self.typeface = typeface
        self.textSize = textSize
        self.textAlignment = textAlignment
        self.textColor = textColor
        self.extraLineSpacing = extraLineSpacing
        self.lineHeightMultiplier = lineHeightMultiplier
        self.isJustificationEnabled = isJustificationEnabled
        self.justificationLevel = justificationLevel
    }

    private func typesetterParams() -> (attributedString: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any])? {
        guard typesetter == nil else {
            return nil
        }

        if let string {
           if let typeface, !string.isEmpty {
               let defaultAttributes: [NSAttributedString.Key: Any] = [
                   .typeface: typeface,
                   .typeSize: textSize
               ]
               return (NSAttributedString(string: string), defaultAttributes)
           }
        } else if let attributedString {
           if let typeface, !attributedString.string.isEmpty {
               let defaultAttributes: [NSAttributedString.Key: Any] = [
                   .typeface: typeface,
                   .typeSize: textSize
               ]
               return (attributedString, defaultAttributes)
           }
        }

        return nil
    }

    func performTypesetting() async {
        guard let params = typesetterParams() else { return }

        typesetter = Typesetter(
            text: params.attributedString,
            defaultAttributes: params.defaultAttributes
        )
    }

    private func makeFrameResolver() -> FrameResolver {
        let resolver = FrameResolver()
        resolver.typesetter = typesetter
        resolver.frameBounds = CGRect(
            x: .zero,
            y: .zero,
            width: layoutWidth,
            height: .greatestFiniteMagnitude
        )
        resolver.fitsHorizontally = false
        resolver.fitsVertically = true
        resolver.textAlignment = textAlignment
        resolver.extraLineSpacing = extraLineSpacing
        resolver.lineHeightMultiplier = lineHeightMultiplier
        resolver.isJustificationEnabled = isJustificationEnabled
        resolver.justificationLevel = justificationLevel
        return resolver
    }

    func resolveTextFrame() async {
        guard let typesetter else { return }
        guard layoutWidth > .zero else { return }

        let resolver = makeFrameResolver()
        let string = typesetter.text.string

        textFrame = resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)
    }

    private func makeBoxRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.renderScale = renderScale
        renderer.fillColor = textColor
        return renderer
    }

    func measureLines(updatesBlock: @escaping LineUpdatesBlock) async {
        guard let lines = textFrame?.lines else { return }

        let renderer = makeBoxRenderer()
        var sections: SectionDictionary = [:]
        var lineBoxes: [CGRect] = []
        var lineCount = 0

        for (lineIndex, textLine) in lines.enumerated() {
            defer { lineCount += 1 }

            var boundingBox = textLine.computeBoundingBox(with: renderer)
            boundingBox = boundingBox.offsetBy(dx: textLine.origin.x, dy: textLine.origin.y)
            boundingBox = boundingBox.union(
                CGRect(
                    x: 0.0,
                    y: textLine.origin.y - textLine.ascent,
                    width: layoutWidth,
                    height: textLine.height
                )
            )
            boundingBox.origin.x.round(.down)
            boundingBox.origin.y.round(.down)
            boundingBox.size.width.round(.up)
            boundingBox.size.height.round(.up)

            lineBoxes.append(boundingBox)

            let startSection = Int(boundingBox.minY / sectionHeight)
            let endSection = Int(boundingBox.maxY / sectionHeight)
            for section in startSection...endSection {
                sections[section, default: []].append(lineIndex)
            }

            if lineCount == 64 {
                if Task.isCancelled { return }

                await updatesBlock(sections, lineBoxes)
                lineCount = 0
            }
        }

        if lineCount > 0 {
            await updatesBlock(sections, lineBoxes)
        }
    }
}

@available(iOS 15.0, *)
final class LazyTextManager: ObservableObject {
    let renderer = Renderer()
    private var properties = TextProperties()

    private(set) var scrollOffset: CGPoint = .zero
    private(set) var scrollWidth: CGFloat = .zero
    private(set) var scrollHeight: CGFloat = .zero

    private(set) var typesetter: Typesetter?
    @Published private(set) var textFrame: ComposedFrame?
    @Published private(set) var visibleIndices: [Int] = []

    private var textSections: SectionDictionary = [:]
    private(set) var lineBoxes: [CGRect] = []

    private var layoutTask: Task<Void, Never>?
    private var layoutID = LayoutID()

    @MainActor
    func setupProperties(_ initialProperties: TextProperties) {
        if initialProperties != properties {
            updateProperties(initialProperties)
        }
    }

    @MainActor
    func updateProperties(_ newProperties: TextProperties) {
        properties = newProperties
        updateRenderer()
        performTextLayout()
    }

    @MainActor
    func updateScrollOffset(_ newOffset: CGPoint) {
        if newOffset != scrollOffset {
            scrollOffset = newOffset
            updateVisibleIndices()
        }
    }

    @MainActor
    func updateScrollWidth(_ newWidth: CGFloat) {
        if newWidth != scrollWidth {
            scrollWidth = newWidth
            performTextLayout()
        }
    }

    @MainActor
    func updateScrollHeight(_ newHeight: CGFloat) {
        if newHeight != scrollHeight {
            scrollHeight = newHeight
            updateVisibleIndices()
        }
    }

    @MainActor
    private func updateRenderer() {
        renderer.renderScale = UIScreen.main.scale
        renderer.renderingStyle = properties.renderingStyle
        renderer.fillColor = UIColor(properties.textColor)
        renderer.strokeColor = UIColor(properties.strokeColor)
        renderer.strokeWidth = properties.strokeWidth
        renderer.strokeCap = properties.strokeCap
        renderer.strokeJoin = properties.strokeJoin
        renderer.strokeMiter = properties.strokeMiter
    }

    @MainActor
    private func updateVisibleIndices() {
        var indicesSet: Set<LineIndex> = []

        let visibleRect = CGRect(
            x: -scrollOffset.x,
            y: -scrollOffset.y,
            width: scrollWidth,
            height: scrollHeight
        )
        let startSection = Int(visibleRect.minY / sectionHeight)
        let endSection = Int(visibleRect.maxY / sectionHeight)

        for section in startSection...endSection {
            if let indices = textSections[section] {
                for index in indices {
                    if visibleRect.intersects(lineBoxes[index]) {
                        indicesSet.insert(index)
                    }
                }
            }
        }

        visibleIndices = indicesSet.sorted()
    }

    @MainActor
    private func performTextLayout() {
        layoutID = LayoutID()

        let context = TextContext(
            layoutID: layoutID,
            renderScale: UIScreen.main.scale,
            layoutWidth: scrollWidth,
            string: properties.string,
            attributedString: properties.attributedString,
            typesetter: typesetter ?? properties.typesetter,
            typeface: properties.typeface,
            textSize: properties.textSize,
            textAlignment: properties.textAlignment,
            textColor: UIColor(properties.textColor),
            extraLineSpacing: properties.extraLineSpacing,
            lineHeightMultiplier: properties.lineHeightMultiplier,
            isJustificationEnabled: properties.isJustificationEnabled,
            justificationLevel: properties.justificationLevel
        )

        layoutTask?.cancel()
        layoutTask = Task {
            if context.typesetter == nil {
                await context.performTypesetting()
                updateTypesetter(context.typesetter, forLayout: context.layoutID)
            }
            if Task.isCancelled { return }

            await context.resolveTextFrame()
            updateTextFrame(context.textFrame, forLayout: context.layoutID)
            if Task.isCancelled { return }

            await context.measureLines { [weak self] sections, boxes in
                self?.updateLines((sections, boxes), forLayout: context.layoutID)
            }
        }
    }

    @MainActor
    private func updateTypesetter(_ newTypesetter: Typesetter?, forLayout layoutID: LayoutID) {
        guard layoutID == self.layoutID else { return }
        typesetter = newTypesetter
    }

    @MainActor
    private func updateTextFrame(_ newFrame: ComposedFrame?, forLayout layoutID: LayoutID) {
        guard layoutID == self.layoutID else { return }

        textFrame = newFrame
        textSections = [:]
        lineBoxes = []
        updateVisibleIndices()
    }

    @MainActor
    private func updateLines(
        _ lines: (sections: SectionDictionary, boxes: [CGRect]),
        forLayout layoutID: LayoutID
    ) {
        guard layoutID == self.layoutID else { return }

        textSections = lines.sections
        lineBoxes = lines.boxes
        updateVisibleIndices()
    }
}
