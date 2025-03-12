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

import SwiftUI

@available(iOS 15.0, *)
public struct ScrollableText: View {
    private let coordinateSpaceName = UUID()
    private var properties: TextProperties

    @State private var scrollHeight: CGFloat = .zero

    public init(_ string: String) {
        properties = TextProperties(string: string)
    }

    public init(_ attributedString: NSAttributedString) {
        properties = TextProperties(attributedString: attributedString)
    }

    public init(_ typesetter: Typesetter) {
        properties = TextProperties(typesetter: typesetter)
    }

    public var body: some View {
        ScrollView([.vertical], showsIndicators: true) {
            LazyText(
                properties: properties,
                coordinateSpace: .named(coordinateSpaceName),
                scrollHeight: $scrollHeight
            )
        }
        .coordinateSpace(name: coordinateSpaceName)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        scrollHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { newHeight in
                        scrollHeight = newHeight
                    }
            }
            .ignoresSafeArea(.all, edges: .vertical)
            .frame(width: .zero)
        )
    }

    /// Sets the typeface in which the text is displayed.
    public func typeface(_ typeface: Typeface?) -> Self {
        var scrollableText = self
        scrollableText.properties.typeface = typeface
        return scrollableText
    }

    /// Sets the default size of the text.
    public func textSize(_ size: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.textSize = size
        return scrollableText
    }

    /// Sets the text alignment to apply on each line.
    public func textAlignment(_ alignment: TextAlignment) -> Self {
        var scrollableText = self
        scrollableText.properties.textAlignment = alignment
        return scrollableText
    }

    /// Sets the default color of the text.
    public func textColor(_ color: Color) -> Self {
        var scrollableText = self
        scrollableText.properties.textColor = color
        return scrollableText
    }

    /// Sets the extra spacing that is added after each text line. It is resolved before line
    /// height multiplier.
    public func extraLineSpacing(_ spacing: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.extraLineSpacing = spacing
        return scrollableText
    }

    /// Sets the height multiplier that is applied on each text line. It is resolved after extra
    /// line spacing. The additional spacing is adjusted in such a way that text remains in the
    /// middle of the line.
    public func lineHeightMultiplier(_ multiplier: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.lineHeightMultiplier = multiplier
        return scrollableText
    }

    /// Sets whether or not to justify the text lines.
    public func justificationEnabled(_ enabled: Bool) -> Self {
        var scrollableText = self
        scrollableText.properties.isJustificationEnabled = enabled
        return scrollableText
    }

    /// Sets the justification level which can range from `0.0` to `1.0`. A lower value increases
    /// the tightness between words while a higher value decreases it.
    public func justificationLevel(_ level: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.justificationLevel = level
        return scrollableText
    }

    /// Sets the color to display a separator line below each rendered text line.
    public func separatorColor(_ color: Color?) -> Self {
        var scrollableText = self
        scrollableText.properties.separatorColor = color
        return scrollableText
    }

    /// Sets the rendering style, used for controlling how text should appear while drawing.
    public func renderingStyle(_ style: Renderer.RenderingStyle) -> Self {
        var scrollableText = self
        scrollableText.properties.renderingStyle = style
        return scrollableText
    }

    /// Sets the stroke color for text.
    public func strokeColor(_ color: Color) -> Self {
        var scrollableText = self
        scrollableText.properties.strokeColor = color
        return scrollableText
    }

    /// Sets the stroke width for text.
    public func strokeWidth(_ width: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.strokeWidth = width
        return scrollableText
    }

    /// Sets the stroke cap style which controls how the start and end of stroked lines and paths
    /// are treated.
    public func strokeCap(_ cap: Renderer.StrokeCap) -> Self {
        var scrollableText = self
        scrollableText.properties.strokeCap = cap
        return scrollableText
    }

    /// Sets the stroke join type.
    public func strokeJoin(_ join: Renderer.StrokeJoin) -> Self {
        var scrollableText = self
        scrollableText.properties.strokeJoin = join
        return scrollableText
    }

    /// Sets the stroke miter limit in pixels. This is used to control the behavior of miter joins
    /// when the joins angle is sharp.
    public func strokeMiter(_ miter: CGFloat) -> Self {
        var scrollableText = self
        scrollableText.properties.strokeMiter = miter
        return scrollableText
    }
}
