//
// Copyright (C) 2025-2026 Muhammad Tayyab Akram
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

@available(iOS 13.0, *)
private struct TextContext: Sendable {
    let layoutID: LayoutID
    let renderScale: CGFloat
    let layoutWidth: CGFloat
    let string: String?
    // The string is immutable, since it is copied when the context is made, and is only read.
    nonisolated(unsafe) let attributedString: NSAttributedString?
    let typeface: Typeface?
    let textSize: CGFloat
    let textAlignment: TextAlignment
    let textColor: UIColor
    let extraLineSpacing: CGFloat
    let lineHeightMultiplier: CGFloat
    let isJustificationEnabled: Bool
    let justificationLevel: CGFloat

    let typesetter: Typesetter?

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
        self.attributedString = attributedString?.copy() as? NSAttributedString
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

    func performTypesetting() async -> Typesetter? {
        guard let params = typesetterParams() else { return nil }

        return Typesetter(
            text: params.attributedString,
            defaultAttributes: params.defaultAttributes
        )
    }

    private func makeFrameResolver(typesetter: Typesetter) -> FrameResolver {
        let resolver = FrameResolver()
        resolver.typesetter = typesetter
        resolver.frameWidth = layoutWidth
        resolver.frameHeight = .greatestFiniteMagnitude
        resolver.fitsHorizontally = false
        resolver.fitsVertically = true
        resolver.textAlignment = textAlignment
        resolver.extraLineSpacing = extraLineSpacing
        resolver.lineHeightMultiplier = lineHeightMultiplier
        resolver.isJustificationEnabled = isJustificationEnabled
        resolver.justificationLevel = justificationLevel
        return resolver
    }

    func resolveTextFrame(typesetter: Typesetter?) async -> ComposedFrame? {
        guard let typesetter else { return nil }
        guard layoutWidth > .zero else { return nil }

        let resolver = makeFrameResolver(typesetter: typesetter)
        let string = typesetter.text.string

        return resolver.makeFrame(characterRange: string.startIndex ..< string.endIndex)
    }

    private func makeBoxRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.renderScale = renderScale
        renderer.fillColor = textColor
        return renderer
    }

    func makeLineLocator(of textFrame: ComposedFrame?) async -> LineLocator? {
        return textFrame?.makeLineLocator(renderer: makeBoxRenderer())
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

    private var lineLocator: LineLocator?
    private var foundLines: [Int] = []

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
        renderer.drawStyle = properties.drawStyle
        renderer.fillColor = UIColor(properties.textColor)
        renderer.strokeColor = UIColor(properties.strokeColor)
        renderer.strokeRadius = properties.strokeRadius
        renderer.strokeCap = properties.strokeCap
        renderer.strokeJoin = properties.strokeJoin
        renderer.strokeMiter = properties.strokeMiter
    }

    /// The box of a line in the coordinates of the text frame, which is empty until the locator of
    /// the lines is ready.
    func lineBox(at lineIndex: Int) -> CGRect {
        guard let lineLocator, lineIndex < lineLocator.lineCount else {
            return .zero
        }

        return lineLocator.box(ofLineAt: lineIndex)
    }

    @MainActor
    private func updateVisibleIndices() {
        guard let lineLocator else {
            visibleIndices = []
            return
        }

        let visibleRect = CGRect(
            x: -scrollOffset.x,
            y: -scrollOffset.y,
            width: scrollWidth,
            height: scrollHeight
        )

        lineLocator.findLines(in: visibleRect, into: &foundLines)
        foundLines.sort()

        if visibleIndices != foundLines {
            visibleIndices = foundLines
        }
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
            var typesetter = context.typesetter
            if typesetter == nil {
                typesetter = await context.performTypesetting()
                updateTypesetter(typesetter, forLayout: context.layoutID)
            }
            if Task.isCancelled { return }

            let textFrame = await context.resolveTextFrame(typesetter: typesetter)
            updateTextFrame(textFrame, forLayout: context.layoutID)
            if Task.isCancelled { return }

            let lineLocator = await context.makeLineLocator(of: textFrame)
            updateLineLocator(lineLocator, forLayout: context.layoutID)
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
        lineLocator = nil
        updateVisibleIndices()
    }

    @MainActor
    private func updateLineLocator(_ newLocator: LineLocator?, forLayout layoutID: LayoutID) {
        guard layoutID == self.layoutID else { return }

        lineLocator = newLocator
        updateVisibleIndices()
    }
}
