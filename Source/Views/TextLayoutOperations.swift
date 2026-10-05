//
// Copyright (C) 2026 Muhammad Tayyab Akram
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
import UIKit

final class TextLayoutContext {
    var layoutID: NSObject!
    var renderScale: CGFloat = 1.0
    var layoutWidth: CGFloat = .zero
    var typeface: Typeface?
    var text: String!
    var attributedText: NSAttributedString!
    var textSize: CGFloat = 16.0
    var textAlignment: TextAlignment = .leading
    var textColor: UIColor = .black
    var extraLineSpacing: CGFloat = .zero
    var lineHeightMultiplier: CGFloat = 1.0
    var isJustificationEnabled: Bool = false
    var justificationLevel: CGFloat = 1.0
    var renderingStyle: Renderer.RenderingStyle = .fill
    var strokeColor: UIColor = .black
    var strokeWidth: CGFloat = 1.0
    var strokeCap: Renderer.StrokeCap = .butt
    var strokeJoin: Renderer.StrokeJoin = .round
    var strokeMiter: CGFloat = 1.0
    var typesetter: Typesetter?
    var textFrame: ComposedFrame?

    func updateRenderer(_ renderer: Renderer) {
        renderer.renderScale = renderScale
        if let typeface = typeface {
            renderer.typeface = typeface
        }
        renderer.typeSize = textSize
        renderer.fillColor = textColor
        renderer.renderingStyle = renderingStyle
        renderer.strokeColor = strokeColor
        renderer.strokeWidth = strokeWidth
        renderer.strokeCap = strokeCap
        renderer.strokeJoin = strokeJoin
        renderer.strokeMiter = strokeMiter
    }
}

// Unchecked as `Operation` itself is; the context is shared as `TextLayoutContext` describes.
final class TypesettingOperation: Operation, @unchecked Sendable {
    private let context: TextLayoutContext
    private let updateBlock: ((Typesetter?) -> Void)

    init(_ context: TextLayoutContext, updateBlock: @escaping ((Typesetter?) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func typesetterParams() -> (text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any])? {
        if let text = context.text {
            if let typeface = context.typeface, !text.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: context.textSize]

                return (NSAttributedString(string: text), defaultAttributes)
            }
        } else if let attributedText = context.attributedText {
            if !attributedText.string.isEmpty {
                var defaultAttributes: [NSAttributedString.Key: Any] = [.typeSize: context.textSize]
                if let typeface = context.typeface {
                    defaultAttributes[.typeface] = typeface
                }

                return (attributedText, defaultAttributes)
            }
        }

        return nil
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        DispatchQueue.main.async {
            self.updateBlock(self.context.typesetter)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let params = typesetterParams() else {
            return
        }

        context.typesetter = Typesetter(text: params.text, defaultAttributes: params.defaultAttributes)
    }
}

// Unchecked as `Operation` itself is; the context is shared as `TextLayoutContext` describes.
final class FrameResolvingOperation: Operation, @unchecked Sendable {
    private let context: TextLayoutContext
    private let updateBlock: ((ComposedFrame?) -> Void)

    init(_ context: TextLayoutContext, updateBlock: @escaping ((ComposedFrame?) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        DispatchQueue.main.async {
            self.updateBlock(self.context.textFrame)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let typesetter = context.typesetter else {
            return
        }

        let resolver = FrameResolver()
        resolver.typesetter = typesetter
        resolver.frameBounds = CGRect(
            x: .zero, y: .zero,
            width: context.layoutWidth, height: .greatestFiniteMagnitude
        )
        resolver.fitsHorizontally = false
        resolver.fitsVertically = true
        resolver.textAlignment = context.textAlignment
        resolver.extraLineSpacing = context.extraLineSpacing
        resolver.lineHeightMultiplier = context.lineHeightMultiplier
        resolver.isJustificationEnabled = context.isJustificationEnabled
        resolver.justificationLevel = context.justificationLevel

        let string = typesetter.text.string
        context.textFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )
    }
}

// Unchecked as `Operation` itself is; the context is shared as `TextLayoutContext` describes.
final class LineBoxesOperation: Operation, @unchecked Sendable {
    private let context: TextLayoutContext
    private let updateBlock: ((LineBoxes) -> Void)

    private var lineBoxes = LineBoxes()

    init(_ context: TextLayoutContext, updateBlock: @escaping ((LineBoxes) -> Void)) {
        self.context = context
        self.updateBlock = updateBlock
    }

    private func notifyUpdateIfNeeded() {
        guard !isCancelled else { return }

        let lineBoxes = self.lineBoxes

        DispatchQueue.main.async {
            self.updateBlock(lineBoxes)
        }
    }

    override func main() {
        defer { notifyUpdateIfNeeded() }

        guard let lines = context.textFrame?.lines else {
            return
        }

        let renderer = Renderer()
        context.updateRenderer(renderer)

        var lineCount = 0

        for textLine in lines {
            defer { lineCount += 1 }

            var boundingBox = CGRect(
                x: 0.0,
                y: textLine.origin.y - textLine.ascent,
                width: context.layoutWidth,
                height: textLine.height
            )

            var inkBox = textLine.computeBoundingBox(with: renderer)
            if !inkBox.isNull {
                inkBox = inkBox.offsetBy(dx: textLine.origin.x, dy: textLine.origin.y)
                boundingBox = boundingBox.union(inkBox)
            }

            lineBoxes.append(boundingBox.integral)

            if isCancelled {
                return
            }

            if lineCount == 64 {
                notifyUpdateIfNeeded()
                lineCount = 0
            }
        }
    }
}
