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

@available(iOS 15.0, *)
public struct StyledText: View {
    @StateObject private var manager: StyledTextManager

    private var properties: TextProperties
    private var layoutID: AnyHashable?

    public init(_ string: String) {
        _manager = StateObject(wrappedValue: StyledTextManager())
        properties = TextProperties(string: string)
    }

    public init(_ attributedString: NSAttributedString) {
        _manager = StateObject(wrappedValue: StyledTextManager())
        properties = TextProperties(attributedString: attributedString)
    }

    public init(_ typesetter: Typesetter) {
        _manager = StateObject(wrappedValue: StyledTextManager())
        properties = TextProperties(typesetter: typesetter)
    }

    public var body: some View {
        ZStack {
            Canvas { graphicsContext, size in
                if let textFrame = manager.textFrame {
                    graphicsContext.withCGContext { context in
                        context.interpolationQuality = .none
                        context.setShouldAntialias(false)
                        context.setBlendMode(.normal)

                        textFrame.draw(with: manager.renderer, in: context, at: .zero)
                    }
                }
            }
        }
        .frame(
            idealWidth: manager.frameWidth ?? .zero,
            maxWidth: manager.frameWidth,
            idealHeight: manager.frameHeight ?? .zero,
            maxHeight: manager.frameHeight
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        manager.refreshLayout(forSize: geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        manager.refreshLayout(forSize: newSize)
                    }
            }
            .id(manager.geometryID)
        )
        .onAppear {
            manager.setupProperties(properties)
        }
        .onChange(of: properties) { newProperties in
            manager.updateProperties(newProperties)
        }
        .onChange(of: layoutID) { newID in
            manager.refreshLayout()
        }
    }

    /// Sets the typeface in which the text is displayed.
    public func typeface(_ typeface: Typeface?) -> Self {
        var styledText = self
        styledText.properties.typeface = typeface
        return styledText
    }

    /// Sets the default size of the text.
    public func textSize(_ size: CGFloat) -> Self {
        var styledText = self
        styledText.properties.textSize = size
        return styledText
    }

    /// Sets the text alignment to apply on each line.
    public func textAlignment(_ textAlignment: TextAlignment) -> StyledText {
        var styledText = self
        styledText.properties.textAlignment = textAlignment
        return styledText
    }

    /// Sets the color of the text.
    public func textColor(_ textColor: Color) -> StyledText {
        var styledText = self
        styledText.properties.textColor = textColor
        return styledText
    }

    /// Sets the truncation mode that should be used on the last line of the text in case of
    /// overflow.
    public func truncationMode(_ truncationMode: BreakMode) -> StyledText {
        var styledText = self
        styledText.properties.truncationMode = truncationMode
        return styledText
    }

    /// Sets the truncation place for the last line of the text. The truncation is disabled if its
    /// value is `.nil`
    public func truncationPlace(_ truncationPlace: TruncationPlace?) -> StyledText {
        var styledText = self
        styledText.properties.truncationPlace = truncationPlace
        return styledText
    }

    /// Sets the maximum number of lines to use for rendering text.
    public func maxLines(_ maxLines: Int?) -> StyledText {
        var styledText = self
        styledText.properties.maxLines = maxLines
        return styledText
    }

    /// Sets the extra spacing that is added after each text line. It is resolved before line
    /// height multiplier.
    public func extraLineSpacing(_ extraLineSpacing: CGFloat) -> StyledText {
        var styledText = self
        styledText.properties.extraLineSpacing = extraLineSpacing
        return styledText
    }

    /// Sets the height multiplier that is applied on each text line. It is resolved after extra
    /// line spacing. The additional spacing is adjusted in such a way that text remains in the
    /// middle of the line.
    public func lineHeightMultiplier(_ lineHeightMultiplier: CGFloat) -> StyledText {
        var styledText = self
        styledText.properties.lineHeightMultiplier = lineHeightMultiplier
        return styledText
    }

    /// Sets the rendering style, used for controlling how text should appear while drawing.
    public func renderingStyle(_ renderingStyle: Renderer.RenderingStyle) -> StyledText {
        var styledText = self
        styledText.properties.renderingStyle = renderingStyle
        return styledText
    }

    /// Sets the stroke color for text.
    public func strokeColor(_ strokeColor: Color) -> StyledText {
        var styledText = self
        styledText.properties.strokeColor = strokeColor
        return styledText
    }

    /// Sets the stroke width for text.
    public func strokeWidth(_ strokeWidth: CGFloat) -> StyledText {
        var styledText = self
        styledText.properties.strokeWidth = strokeWidth
        return styledText
    }

    /// Sets the stroke cap style which controls how the start and end of stroked lines and paths
    /// are treated.
    public func strokeCap(_ strokeCap: Renderer.StrokeCap) -> StyledText {
        var styledText = self
        styledText.properties.strokeCap = strokeCap
        return styledText
    }

    /// Sets the stroke join type.
    public func strokeJoin(_ strokeJoin: Renderer.StrokeJoin) -> StyledText {
        var styledText = self
        styledText.properties.strokeJoin = strokeJoin
        return styledText
    }

    /// Sets the stroke miter limit in pixels. This is used to control the behavior of miter joins
    /// when the joins angle is sharp.
    public func strokeMiter(_ strokeMiter: CGFloat) -> StyledText {
        var styledText = self
        styledText.properties.strokeMiter = strokeMiter
        return styledText
    }

    public func layoutID<ID: Hashable>(_ layoutID: ID) -> StyledText {
        var styledText = self
        styledText.layoutID = layoutID
        return styledText
    }
}
