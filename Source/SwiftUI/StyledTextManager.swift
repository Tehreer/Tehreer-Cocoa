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

    private var lastProposedWidth: CGFloat?
    private var lastProposedHeight: CGFloat?

    @Published private(set) var geometryID = UUID()

    @Published private(set) var textFrame: ComposedFrame?
    @Published private(set) var frameWidth: CGFloat?
    @Published private(set) var frameHeight: CGFloat?

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
            if proposedSize.width == frameWidth {
                // Update the last proposed width if the system has adopted the actual frame width.
                lastProposedWidth = proposedSize.width
            }
            if proposedSize.height == frameHeight {
                // Update the last proposed height if the system has adopted the actual frame
                // height.
                lastProposedHeight = proposedSize.height
            }

            if proposedSize.width != lastProposedWidth {
                // Update the text frame by passing `zero` as proposed height in order to determine
                // the actual height.
                updateTextFrame(
                    forSize: CGSize(width: proposedSize.width, height: .zero)
                )

                // Assign another geometry ID to ensure a second layout pass for determining the
                // actual frame height.
                geometryID = UUID()

                // Update the last proposed with and the height.
                lastProposedWidth = proposedSize.width
                lastProposedHeight = nil
            } else if proposedSize.height != lastProposedHeight {
                // Update the text frame respecting the passed-in proposed size.
                updateTextFrame(forSize: proposedSize)
                // Update the last proposed height.
                lastProposedHeight = proposedSize.height
            }
        } else {
            // Force layout by resetting the related properties.
            lastProposedWidth = nil
            lastProposedHeight = nil
            geometryID = UUID()
            textFrame = nil
            frameWidth = nil
            frameHeight = nil
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

        let isWidthPass = frameWidth == nil
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
            frameWidth = .zero
            frameHeight = .zero
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
            frameWidth = textFrame.width.rounded(.up)

            if !isWidthPass {
                frameHeight = textFrame.height.rounded(.up)
            }
        } else {
            frameWidth = .zero
            frameHeight = .zero
        }
    }
}
