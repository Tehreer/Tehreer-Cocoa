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
import UIKit

@available(iOS 15.0, *)
final class StyledTextManager: ObservableObject {
    let renderer = Renderer()
    private let resolver = FrameResolver()

    private var fixedWidth: Bool?
    private var fixedHeight: Bool?

    private(set) var inputSize: CGSize = .zero
    @Published private(set) var idealWidth: CGFloat = .zero
    @Published private(set) var idealHeight: CGFloat = .zero

    @Published private(set) var textFrame: ComposedFrame?

    private var typesetter: Typesetter? {
        return resolver.typesetter
    }

    var textWidth: CGFloat? {
        return textFrame?.width.rounded(.up)
    }

    var textHeight: CGFloat? {
        return textFrame?.height.rounded(.up)
    }

    var maxWidth: CGFloat? {
        return (fixedWidth == true) ? nil : textWidth ?? .infinity
    }

    var maxHeight: CGFloat? {
        return (fixedHeight == true) ? nil : textHeight ?? .infinity
    }

    @MainActor
    func setupProperties(_ properties: TextProperties, initialSize: CGSize) {
        let typesetter = updatedTypesetter(for: properties)

        properties.updateFrameResolver(resolver)
        properties.updateRenderer(renderer)

        resolver.typesetter = typesetter
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true
        renderer.renderScale = UIScreen.main.scale

        updateLayout(forSize: initialSize, forceUpdate: true)
    }

    private func updatedTypesetter(for properties: TextProperties) -> Typesetter? {
        switch properties.textSource() {
        case .none:
            return nil
        case .typesetter(let typesetter):
            return typesetter
        case .attributedString(let attributedString, let defaultAttributes):
            if let typesetter = resolver.typesetter {
                let existingAttributes = typesetter.defaultAttributes

                if typesetter.text == attributedString
                    && existingAttributes.count == defaultAttributes.count
                    && existingAttributes[.typeface] as? Typeface === defaultAttributes[.typeface] as? Typeface
                    && existingAttributes[.typeSize] as? CGFloat == defaultAttributes[.typeSize] as? CGFloat {
                    return typesetter
                }
            }

            return Typesetter(text: attributedString, defaultAttributes: defaultAttributes)
        }
    }

    func updateLayout(forSize proposedSize: CGSize, forceUpdate: Bool = false) {
        if !forceUpdate && proposedSize == inputSize {
            return
        }

        inputSize = proposedSize

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
