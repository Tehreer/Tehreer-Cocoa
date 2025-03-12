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

enum TextSource {
    case none
    case attributedString(
        _ attributedString: NSAttributedString,
        _ defaultAttributes: [NSAttributedString.Key: Any]
    )
    case typesetter(_ typesetter: Typesetter)
}

@available(iOS 15.0, *)
struct TextProperties: Equatable {
    var string: String?
    var attributedString: NSAttributedString?
    var typesetter: Typesetter?
    var typeface: Typeface?
    var textSize: CGFloat = 16.0
    var textAlignment: TextAlignment = .leading
    var textColor: Color = .black
    var truncationMode: BreakMode = .line
    var truncationPlace: TruncationPlace? = nil
    var isJustificationEnabled: Bool = false
    var justificationLevel: CGFloat = 1.0
    var maxLines: Int? = nil
    var extraLineSpacing: CGFloat = 0.0
    var lineHeightMultiplier: CGFloat = 1.0
    var separatorColor: Color?
    var renderingStyle: Renderer.RenderingStyle = .fill
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 1.0
    var strokeCap: Renderer.StrokeCap = .butt
    var strokeJoin: Renderer.StrokeJoin = .round
    var strokeMiter: CGFloat = 1.0

    func textSource() -> TextSource {
        if let typesetter {
            return .typesetter(typesetter)
        }

        if let attributedString {
            if let typeface, !attributedString.string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize
                ]
                return .attributedString(attributedString, defaultAttributes)
           }
        }

        if let string {
            if let typeface, !string.isEmpty {
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .typeface: typeface,
                    .typeSize: textSize
                ]
                return .attributedString(
                    NSAttributedString(string: string),
                    defaultAttributes
                )
           }
        }

        return .none
    }

    func updateFrameResolver(_ resolver: FrameResolver) {
        resolver.typesetter = typesetter
        resolver.textAlignment = textAlignment
        resolver.truncationMode = truncationMode
        resolver.truncationPlace = truncationPlace
        resolver.isJustificationEnabled = isJustificationEnabled
        resolver.justificationLevel = justificationLevel
        resolver.maxLines = maxLines
        resolver.extraLineSpacing = extraLineSpacing
        resolver.lineHeightMultiplier = lineHeightMultiplier
    }

    func updateRenderer(_ renderer: Renderer) {
        renderer.renderingStyle = renderingStyle
        renderer.fillColor = UIColor(textColor)
        renderer.strokeColor = UIColor(strokeColor)
        renderer.strokeWidth = strokeWidth
        renderer.strokeCap = strokeCap
        renderer.strokeJoin = strokeJoin
        renderer.strokeMiter = strokeMiter
    }

    static func == (lhs: TextProperties, rhs: TextProperties) -> Bool {
        return lhs.string == rhs.string &&
        lhs.attributedString == rhs.attributedString &&
        lhs.typesetter === rhs.typesetter &&
        lhs.typeface === rhs.typeface &&
        lhs.textSize == rhs.textSize &&
        lhs.textAlignment == rhs.textAlignment &&
        lhs.textColor == rhs.textColor &&
        lhs.truncationMode == rhs.truncationMode &&
        lhs.truncationPlace == rhs.truncationPlace &&
        lhs.isJustificationEnabled == rhs.isJustificationEnabled &&
        lhs.justificationLevel == rhs.justificationLevel &&
        lhs.maxLines == rhs.maxLines &&
        lhs.extraLineSpacing == rhs.extraLineSpacing &&
        lhs.lineHeightMultiplier == rhs.lineHeightMultiplier &&
        lhs.separatorColor == rhs.separatorColor &&
        lhs.renderingStyle == rhs.renderingStyle &&
        lhs.strokeColor == rhs.strokeColor &&
        lhs.strokeWidth == rhs.strokeWidth &&
        lhs.strokeCap == rhs.strokeCap &&
        lhs.strokeJoin == rhs.strokeJoin &&
        lhs.strokeMiter == rhs.strokeMiter
    }
}
