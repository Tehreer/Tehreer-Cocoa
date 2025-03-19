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
    @Published private(set) var textFrame: ComposedFrame?

    private var typesetter: Typesetter? {
        return resolver.typesetter
    }

    @MainActor
    func setupProperties(_ properties: TextProperties) {
        let typesetter = updatedTypesetter(for: properties)

        properties.updateFrameResolver(resolver)
        properties.updateRenderer(renderer)

        resolver.typesetter = typesetter
        resolver.fitsHorizontally = true
        resolver.fitsVertically = true
        renderer.renderScale = UIScreen.main.scale
    }

    @MainActor
    func updateProperties(_ properties: TextProperties) {
        setupProperties(properties)
        refreshLayout()
    }

    @MainActor
    func refreshLayout(forSize proposedSize: CGSize? = nil) {
        if let proposedSize {
            updateTextFrame(forSize: proposedSize)
        } else {
            // Force re-layout by resetting the related properties.
            geometryID = UUID()
            textFrame = nil
        }
    }

    @MainActor
    func determineFrameSize(for containerSize: CGSize) -> CGSize? {
        guard let typesetter else { return nil }
        guard containerSize.width > .zero && containerSize.height > .zero else { return .zero }

        resolver.frameBounds = CGRect(
            x: 0.0, y: 0.0, width: containerSize.width, height: containerSize.height
        )

        let string = typesetter.text.string
        let resolvedFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )

        guard let resolvedFrame else { return nil }

        return CGSize(
            width: resolvedFrame.width.rounded(.up),
            height: resolvedFrame.height.rounded(.up)
        )
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

    private func updateTextFrame(forSize containerSize: CGSize) {
        guard let typesetter,
              containerSize.width > .zero && containerSize.height > .zero else {
            textFrame = nil
            return
        }

        resolver.frameBounds = CGRect(
            x: 0.0, y: 0.0, width: containerSize.width, height: containerSize.height
        )

        let string = typesetter.text.string
        textFrame = resolver.makeFrame(
            characterRange: string.startIndex ..< string.endIndex
        )
    }
}
