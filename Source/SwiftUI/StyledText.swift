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

import CoreFoundation
import SwiftUI

@available(iOS 15.0, *)
public struct StyledText: View {
    private let typesetter: Typesetter?
    private let renderer = Renderer()
    private let resolver = FrameResolver()
    
    @State private var textFrame: ComposedFrame?
    
    @State private var fixedWidth: Bool?
    @State private var fixedHeight: Bool?
    
    @State private var inputSize: CGSize = .zero
    @State private var idealWidth: CGFloat = .zero
    @State private var idealHeight: CGFloat = .zero
    
    public init(
        _ string: String,
        typeface: Typeface,
        textSize: CGFloat
    ) {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .typeface: typeface,
            .typeSize: textSize
        ]

        self.init(
            NSAttributedString(string: string),
            defaultAttributes: defaultAttributes
        )
    }
    
    public init(
        _ attributedString: NSAttributedString,
        defaultAttributes: [NSAttributedString.Key: Any]
    ) {
        if attributedString.string.isEmpty {
            self.init(typesetter: nil)
        } else {
            let typesetter = Typesetter(
                text: attributedString,
                defaultAttributes: defaultAttributes
            )

            self.init(typesetter: typesetter)
        }
    }
    
    public init(_ typesetter: Typesetter) {
        self.init(typesetter: typesetter)
    }
    
    private init(typesetter: Typesetter?) {
        self.typesetter = typesetter
        
        resolver.typesetter = typesetter
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true
    }
    
    private var textWidth: CGFloat? {
        return textFrame?.width.rounded(.up)
    }
    
    private var textHeight: CGFloat? {
        return textFrame?.height.rounded(.up)
    }
    
    private var maxWidth: CGFloat? {
        return (fixedWidth == true) ? nil : textWidth ?? .infinity
    }
    
    private var maxHeight: CGFloat? {
        return (fixedHeight == true) ? nil : textHeight ?? .infinity
    }
    
    public var body: some View {
        ZStack {
            Canvas { graphicsContext, size in
                graphicsContext.withCGContext { context in
                    if let textFrame {
                        renderer.renderScale = UIScreen.main.scale
                        textFrame.draw(with: renderer, in: context, at: .zero)
                    }
                }
            }
            .frame(width: textFrame?.width, height: textFrame?.height)
            .background(Color.cyan)
        }
        .frame(
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            idealHeight: idealHeight,
            maxHeight: maxHeight
        )
        .background(
            GeometryReader { geometry in
                Color.orange
                    .onAppear {
                        inputSize = geometry.size
                        updateLayout()
                    }
                    .onChange(of: geometry.size) { newSize in
                        if newSize != inputSize {
                            inputSize = newSize
                            updateLayout()
                        }
                    }
            }
        )
    }
    
    private func updateLayout() {
        if fixedWidth == nil {
            fixedWidth = inputSize.width.isZero
        }
        if fixedHeight == nil {
            fixedHeight = inputSize.height.isZero
        }
        
        determineIdealSizeIfNeeded()
        makeTextFrameIfNeeded()
    }
    
    private func determineIdealSizeIfNeeded() {
        guard let typesetter else { return }
        
        guard let determineWidth = fixedWidth,
              let determineHeight = fixedHeight,
              (determineWidth || determineHeight) else { return }
        
        let maxWidth = inputSize.width.isZero
                        ? .infinity // This is the first time the ideal width is being determined.
                        : inputSize.width // Ideal width has already been determined and imposed.
        let maxHeight = inputSize.height.isZero
                        ? .infinity  // This is the first time the ideal height is being determined.
                        : (
                            inputSize.width != idealWidth
                            ? .infinity // Input width has changed, so re-calcualte the height.
                            : inputSize.height // Otherwise, use the imposed height.
                          )
        
        if maxWidth == idealWidth && maxHeight == idealHeight {
            return
        }
        
        resolver.frameBounds = CGRect(x: 0.0, y: 0.0, width: maxWidth, height: maxHeight)
        
        let string = typesetter.text.string
        let idealFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )
        
        idealWidth = determineWidth ? idealFrame?.width.rounded(.up) ?? .zero : .zero
        idealHeight = determineHeight ? idealFrame?.height.rounded(.up) ?? .zero : .zero
    }
    
    private func makeTextFrameIfNeeded() {
        guard let typesetter else { return }
        guard inputSize.width > .zero && inputSize.height > .zero else { return }

        resolver.frameBounds = CGRect(
            x: 0.0, y: 0.0, width: inputSize.width, height: inputSize.height
        )
        
        let string = typesetter.text.string
        textFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )
    }
}
