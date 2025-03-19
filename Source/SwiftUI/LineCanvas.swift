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

import CoreGraphics
import SwiftUI

@available(iOS 15.0, *)
struct LineCanvas: View {
    private static let pixelPadding: CGFloat = 1.0

    private let textLine: ComposedLine
    private let asyncDrawing: Bool
    private let defaultRenderer: Renderer
    private let canvasFrame: CGRect
    private let lineBox: CGRect
    private let contentFrame: CGRect
    private let separatorColor: Color?

    @State private var contentImage: Image?
    @State private var contentShown = false

    init(
        _ textLine: ComposedLine,
        asyncDrawing: Bool,
        defaultRenderer: Renderer,
        canvasFrame: CGRect,
        lineBox: CGRect,
        separatorColor: Color?
    ) {
        self.textLine = textLine
        self.asyncDrawing = asyncDrawing
        self.defaultRenderer = defaultRenderer
        self.canvasFrame = canvasFrame
        self.lineBox = lineBox
        self.contentFrame = lineBox
            .offsetBy(dx: -canvasFrame.minX, dy: -canvasFrame.minY)
            .insetBy(dx: -Self.pixelPadding, dy: -Self.pixelPadding)
        self.separatorColor = separatorColor
    }

    var body: some View {
        Group {
            if asyncDrawing {
                if let contentImage {
                    separator
                        .opacity(contentShown ? 1.0 : 0.0)

                    contentImage
                        .position(x: contentFrame.midX, y: contentFrame.midY)
                        .opacity(contentShown ? 1.0 : 0.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                contentShown = true
                            }
                        }
                } else {
                    Color.clear
                        .task {
                            let renderer = makeRenderer()
                            await makeImage(renderer: renderer)
                        }
                }
            } else {
                separator

                Canvas { graphicsContext, size in
                    graphicsContext.withCGContext { context in
                        drawLine(with: defaultRenderer, in: context)
                    }
                }
                .frame(width: contentFrame.width, height: contentFrame.height)
                .position(x: contentFrame.midX, y: contentFrame.midY)
            }
        }
    }

    @ViewBuilder
    private var separator: some View {
        separatorColor?
            .frame(width: canvasFrame.width, height: 1)
            .position(x: canvasFrame.width / 2.0, y: canvasFrame.height)
    }

    private func makeRenderer() -> Renderer {
        let renderer = Renderer()
        renderer.renderScale = defaultRenderer.renderScale
        renderer.renderingStyle = defaultRenderer.renderingStyle
        renderer.fillColor = defaultRenderer.fillColor
        renderer.strokeColor = defaultRenderer.strokeColor
        renderer.strokeWidth = defaultRenderer.strokeWidth
        renderer.strokeCap = defaultRenderer.strokeCap
        renderer.strokeJoin = defaultRenderer.strokeJoin
        renderer.strokeMiter = defaultRenderer.strokeMiter
        return renderer
    }

    private func makeImage(renderer: Renderer) async {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.preferredRange = .extended

        let imageRenderer = UIGraphicsImageRenderer(
            size: contentFrame.size,
            format: format
        )
        if Task.isCancelled { return }

        let uiImage = imageRenderer.image { rendererContext in
            drawLine(with: renderer, in: rendererContext.cgContext)
        }
        if Task.isCancelled { return }

        await MainActor.run {
            contentImage = Image(uiImage: uiImage)
        }
    }

    private func drawLine(with renderer: Renderer, in context: CGContext) {
        let offset = CGPoint(
            x: textLine.origin.x - lineBox.minX + Self.pixelPadding,
            y: textLine.origin.y - lineBox.minY + Self.pixelPadding
        )

        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.setBlendMode(.normal)

        context.translateBy(x: offset.x, y: offset.y)
        textLine.draw(with: renderer, in: context)
    }
}
