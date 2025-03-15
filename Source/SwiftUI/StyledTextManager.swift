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

    @Published private(set) var geometryID = UUID()

    @Published private(set) var idealWidth: CGFloat = .zero
    @Published private(set) var idealHeight: CGFloat = .zero

    @Published private(set) var maxWidth: CGFloat?
    @Published private(set) var maxHeight: CGFloat?

    @Published private(set) var textFrame: ComposedFrame?

    private var typesetter: Typesetter? {
        return resolver.typesetter
    }

    @MainActor
    func setupProperties(_ properties: TextProperties) {
        updateProperties(properties)
    }

    @MainActor
    func updateProperties(_ properties: TextProperties) {
        let typesetter = updatedTypesetter(for: properties)

        properties.updateFrameResolver(resolver)
        properties.updateRenderer(renderer)

        resolver.typesetter = typesetter
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true
        renderer.renderScale = UIScreen.main.scale
        
        refreshLayout()
    }

    @MainActor
    func refreshLayout(forSize proposedSize: CGSize? = nil) {
        if let proposedSize {
            if proposedSize.width != maxWidth {
                idealWidth = .zero
                maxWidth = nil
                textFrame = nil
            }
            if proposedSize.height != maxHeight {
                idealHeight = .zero
                maxHeight = nil
                textFrame = nil
            }

            updateLayout(forSize: proposedSize)
        } else {
            geometryID = UUID()
            idealWidth = .zero
            idealHeight = .zero
            maxWidth = nil
            maxHeight = nil
            textFrame = nil
        }
    }

    @MainActor
    func updateLayout(forSize proposedSize: CGSize) {
        if (maxWidth == nil || maxHeight == nil)
            || (proposedSize.width != idealWidth || proposedSize.height != idealHeight) {
            updateTextFrame(forSize: proposedSize)
        }
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

    private func updateTextFrame(forSize proposedSize: CGSize) {
        guard let typesetter else { return }

        let isWidthPass = maxWidth == nil
        var layoutSize = proposedSize

        if proposedSize.width.isZero {
            // Determine Width.
            layoutSize.width = .greatestFiniteMagnitude
        }
        if proposedSize.height.isZero {
            // Determine Height.
            layoutSize.height = .greatestFiniteMagnitude
        }

        guard layoutSize.width > .zero && layoutSize.height > .zero else {
            textFrame = nil
            idealWidth = .zero
            idealHeight = .zero
            maxWidth = .zero
            maxHeight = .zero
            return
        }

        resolver.frameBounds = CGRect(
            x: 0.0, y: 0.0, width: layoutSize.width, height: layoutSize.height
        )

        let string = typesetter.text.string
        textFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )

        if let textFrame {
            idealWidth = textFrame.width.rounded(.up)
            maxWidth = idealWidth

            if !isWidthPass {
                idealHeight = textFrame.height.rounded(.up)
                maxHeight = idealHeight
            }
        } else {
            idealWidth = .zero
            idealHeight = .zero
            maxWidth = .zero
            maxHeight = .zero
        }
    }
}
