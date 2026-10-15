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

internal import Tehreer

import CoreGraphics
import Foundation
import UIKit

extension TRAttribute {
    /// Creates an attribute of the type, whose value is set by the closure.
    init(type: Int, _ assign: (inout TRAttributeValue) -> Void) {
        self.init()
        self.type = TRAttributeType(type)

        assign(&value)
    }

    static func typeface(_ typeface: TRTypefaceRef) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeTypeface)) { $0.typeface = typeface }
    }

    static func typeSize(_ size: CGFloat) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeTypeSize)) { $0.typeSize = TRFloat(max(size, 0.0)) }
    }

    static func scaleX(_ scale: CGFloat) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeScaleX)) { $0.scaleX = TRFloat(scale) }
    }

    static func scaleY(_ scale: CGFloat) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeScaleY)) { $0.scaleY = TRFloat(scale) }
    }

    static func baselineOffset(_ offset: CGFloat) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeBaselineOffset)) { $0.baselineOffset = TRFloat(offset) }
    }

    static func obliqueness(_ skew: CGFloat) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeObliqueness)) { $0.obliqueness = TRFloat(skew) }
    }

    static func replacement(_ replacement: TRReplacementRef) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeReplacement)) { $0.replacement = replacement }
    }

    static func foregroundColor(_ color: UIColor) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeForegroundColor)) { $0.foregroundColor = color.coreValue }
    }

    static func backgroundColor(_ color: UIColor) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeBackgroundColor)) { $0.backgroundColor = color.coreValue }
    }

    static func underline() -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeUnderline)) { $0.underline = 1 }
    }

    static func strikethrough() -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeStrikethrough)) { $0.strikethrough = 1 }
    }

    static func decorationColor(_ color: UIColor) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeDecorationColor)) { $0.decorationColor = color.coreValue }
    }

    static func language(_ name: String) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeLanguage)) {
            $0.language = TRShapingEngineGetLanguageTagForName(name)
        }
    }

    static func fontFeatures(_ features: TRFontFeaturesRef) -> TRAttribute {
        return TRAttribute(type: Int(TRAttributeFontFeatures)) { $0.fontFeatures = features }
    }

    /// The attributes of Core that stand for a paragraph style. The alignment is always there, as
    /// the default is the natural one, while the others are left out when they are zero.
    static func attributes(of style: NSParagraphStyle) -> [TRAttribute] {
        var attributes = [
            TRAttribute(type: Int(TRAttributeTextAlignment)) {
                switch style.alignment {
                case .left:
                    $0.textAlignment = TextAlignment.left.coreValue
                case .center:
                    $0.textAlignment = TextAlignment.center.coreValue
                case .right:
                    $0.textAlignment = TextAlignment.right.coreValue
                default:
                    $0.textAlignment = TextAlignment.leading.coreValue
                }
            }
        ]

        func add(_ type: Int, _ amount: CGFloat, _ assign: @escaping (inout TRAttributeValue, TRFloat) -> Void) {
            guard amount != 0.0 else {
                return
            }

            attributes.append(TRAttribute(type: type) { assign(&$0, TRFloat(amount)) })
        }

        add(
            Int(TRAttributeFirstLineHeadIndent),
            style.firstLineHeadIndent
        ) { $0.firstLineHeadIndent = $1 }
        add(Int(TRAttributeHeadIndent), style.headIndent) { $0.headIndent = $1 }
        add(Int(TRAttributeTailIndent), style.tailIndent) { $0.tailIndent = $1 }
        add(
            Int(TRAttributeParagraphSpacingBefore),
            style.paragraphSpacingBefore
        ) { $0.paragraphSpacingBefore = $1 }
        add(Int(TRAttributeParagraphSpacing), style.paragraphSpacing) { $0.paragraphSpacing = $1 }
        add(
            Int(TRAttributeLineHeightMultiple),
            style.lineHeightMultiple
        ) { $0.lineHeightMultiple = $1 }
        add(
            Int(TRAttributeMinimumLineHeight),
            style.minimumLineHeight
        ) { $0.minimumLineHeight = $1 }
        add(
            Int(TRAttributeMaximumLineHeight),
            style.maximumLineHeight
        ) { $0.maximumLineHeight = $1 }
        add(Int(TRAttributeLineSpacing), style.lineSpacing) { $0.lineSpacing = $1 }

        return attributes
    }

    /// The types of the attributes that stand for a paragraph style.
    static let paragraphTypes: [Int] = [
        Int(TRAttributeTextAlignment), Int(TRAttributeFirstLineHeadIndent),
        Int(TRAttributeHeadIndent), Int(TRAttributeTailIndent),
        Int(TRAttributeParagraphSpacingBefore), Int(TRAttributeParagraphSpacing),
        Int(TRAttributeLineHeightMultiple), Int(TRAttributeMinimumLineHeight),
        Int(TRAttributeMaximumLineHeight), Int(TRAttributeLineSpacing)
    ]

    /// The default attributes of Core from those of the wrapper, noting the typeface.
    static func defaults(from attributes: [NSAttributedString.Key: Any],
                         objects: inout CoreTextObjects) -> [TRAttribute] {
        var result: [TRAttribute] = []

        func number(_ value: Any) -> CGFloat? {
            return (value as? NSNumber).flatMap { CGFloat(exactly: $0) }
        }

        for (key, value) in attributes {
            switch key {
            case .typeface:
                if let typeface = value as? Typeface {
                    result.append(.typeface(typeface.core))
                    objects.typefaces[typeface.core] = typeface
                }
            case .typeSize:
                result.append(contentsOf: number(value).map { [.typeSize($0)] } ?? [])
            case .scaleX:
                result.append(contentsOf: number(value).map { [.scaleX($0)] } ?? [])
            case .scaleY:
                result.append(contentsOf: number(value).map { [.scaleY($0)] } ?? [])
            case .baselineOffset:
                result.append(contentsOf: number(value).map { [.baselineOffset($0)] } ?? [])
            case .obliqueness:
                result.append(contentsOf: number(value).map { [.obliqueness($0)] } ?? [])
            default:
                break
            }
        }

        return result
    }
}
