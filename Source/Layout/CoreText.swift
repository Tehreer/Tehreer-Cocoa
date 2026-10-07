//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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

/// The replacement of Core for a `TextReplacement` of the wrapper, which keeps the object that
/// decides the room.
private final class ReplacementBox {
    let replacement: TextReplacement

    init(_ replacement: TextReplacement) {
        self.replacement = replacement
    }

    func room(layoutWidth: CGFloat) -> TRReplacementRoom {
        if let attachment = replacement as? ViewAttachment {
            let room = attachment.computeRoom(layoutWidth: layoutWidth)

            return TRReplacementRoom(ascent: TRFloat(room.ascent),
                                     descent: TRFloat(room.descent),
                                     extent: TRFloat(room.extent))
        }

        return TRReplacementRoom(ascent: TRFloat(replacement.ascent),
                                 descent: TRFloat(replacement.descent),
                                 extent: TRFloat(replacement.width))
    }
}

/// The typefaces and replacements of a text that has been given to Core, which Core hands back as
/// pointers.
struct CoreTextObjects: @unchecked Sendable {
    var typefaces: [TRTypefaceRef: Typeface] = [:]
    var replacements: [UnsafeRawPointer: TextReplacement] = [:]
}

enum CoreText {
    private static func number(_ value: Any) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(exactly: number)
        }

        return nil
    }

    private static func makeAttribute(_ type: Int) -> TRAttribute {
        var attribute = TRAttribute()
        attribute.type = TRAttributeType(type)

        return attribute
    }

    private static func makeReplacement(_ replacement: TextReplacement) -> TRReplacementRef? {
        var callbacks = TRReplacementCallbacks()
        callbacks.computeRoom = { (user, layoutWidth, room) in
            let box = Unmanaged<ReplacementBox>.fromOpaque(user!).takeUnretainedValue()
            room!.pointee = box.room(layoutWidth: CGFloat(layoutWidth))
        }
        callbacks.finalize = { (user) in
            Unmanaged<ReplacementBox>.fromOpaque(user!).release()
        }

        let isBlock = (replacement as? ViewAttachment)?.isBlock == true
        let box = Unmanaged.passRetained(ReplacementBox(replacement))

        guard let core = TRReplacementCreate(&callbacks, box.toOpaque(), TRFloat(replacement.leading),
                                             isBlock ? 1 : 0) else {
            box.release()
            return nil
        }

        return core
    }

    private static func alignment(of style: NSParagraphStyle) -> TRTextAlignment {
        switch style.alignment {
        case .left:
            return TRTextAlignment(TRTextAlignmentLeft)
        case .center:
            return TRTextAlignment(TRTextAlignmentCenter)
        case .right:
            return TRTextAlignment(TRTextAlignmentRight)
        default:
            return TRTextAlignment(TRTextAlignmentLeading)
        }
    }

    private static func setParagraphStyle(_ style: NSParagraphStyle, in range: NSRange, of text: TRMutableTextRef) {
        func set(_ attribute: TRAttribute) {
            var attribute = attribute
            TRTextSetAttribute(text, TRUInteger(range.location), TRUInteger(range.length), &attribute)
        }

        // The alignment of a paragraph style is always taken, as the default is the natural one.
        var value = makeAttribute(TRAttributeTextAlignment)
        value.value.textAlignment = alignment(of: style)
        set(value)

        func setFloat(_ type: Int, _ amount: CGFloat, _ assign: (inout TRAttributeValue, TRFloat) -> Void) {
            guard amount != 0.0 else { return }

            var value = makeAttribute(type)
            assign(&value.value, TRFloat(amount))
            set(value)
        }

        setFloat(TRAttributeFirstLineHeadIndent, style.firstLineHeadIndent) { $0.firstLineHeadIndent = $1 }
        setFloat(TRAttributeHeadIndent, style.headIndent) { $0.headIndent = $1 }
        setFloat(TRAttributeTailIndent, style.tailIndent) { $0.tailIndent = $1 }
        setFloat(TRAttributeParagraphSpacingBefore, style.paragraphSpacingBefore) { $0.paragraphSpacingBefore = $1 }
        setFloat(TRAttributeParagraphSpacing, style.paragraphSpacing) { $0.paragraphSpacing = $1 }
        setFloat(TRAttributeLineHeightMultiple, style.lineHeightMultiple) { $0.lineHeightMultiple = $1 }
        setFloat(TRAttributeMinimumLineHeight, style.minimumLineHeight) { $0.minimumLineHeight = $1 }
        setFloat(TRAttributeMaximumLineHeight, style.maximumLineHeight) { $0.maximumLineHeight = $1 }
        setFloat(TRAttributeLineSpacing, style.lineSpacing) { $0.lineSpacing = $1 }
    }

    /// Makes the text of Core for an attributed string, and notes the typefaces and replacements
    /// that it uses.
    static func makeText(from text: NSAttributedString, objects: inout CoreTextObjects) -> TRMutableTextRef {
        let units = Array(text.string.utf16)
        let core = TRTextCreateMutable(TRStringEncoding(TRStringEncodingUTF16))!

        TRTextBeginEditing(core)
        units.withUnsafeBufferPointer { (pointer) in
            TRTextAppendCodeUnits(core, pointer.baseAddress, TRUInteger(pointer.count))
        }

        var replacements: [ObjectIdentifier: TRReplacementRef] = [:]
        var typefaces: [TRTypefaceRef: Typeface] = [:]
        var found: [UnsafeRawPointer: TextReplacement] = [:]

        text.enumerateAttributes(in: NSRange(location: 0, length: units.count), options: []) { (attributes, range, _) in
            var pending: [TRAttribute] = []

            for (key, value) in attributes {
                switch key {
                case .typeface:
                    if let typeface = value as? Typeface {
                        var attribute = makeAttribute(TRAttributeTypeface)
                        attribute.value.typeface = typeface.core
                        pending.append(attribute)
                        typefaces[typeface.core] = typeface
                    }

                case .typeSize:
                    if let size = number(value) {
                        var attribute = makeAttribute(TRAttributePointSize)
                        attribute.value.pointSize = TRFloat(max(size, 0.0))
                        pending.append(attribute)
                    }

                case .scaleX:
                    if let scale = number(value) {
                        var attribute = makeAttribute(TRAttributeScaleX)
                        attribute.value.scaleX = TRFloat(scale)
                        pending.append(attribute)
                    }

                case .scaleY:
                    if let scale = number(value) {
                        var attribute = makeAttribute(TRAttributeScaleY)
                        attribute.value.scaleY = TRFloat(scale)
                        pending.append(attribute)
                    }

                case .baselineOffset:
                    if let offset = number(value) {
                        var attribute = makeAttribute(TRAttributeBaselineOffset)
                        attribute.value.baselineOffset = TRFloat(offset)
                        pending.append(attribute)
                    }

                case .obliqueness:
                    if let skew = number(value) {
                        var attribute = makeAttribute(TRAttributeObliqueness)
                        attribute.value.obliqueness = TRFloat(skew)
                        pending.append(attribute)
                    }

                case .foregroundColor:
                    if let color = value as? UIColor {
                        var attribute = makeAttribute(TRAttributeForegroundColor)
                        attribute.value.foregroundColor = color.coreColor
                        pending.append(attribute)
                    }

                case .replacement:
                    if let replacement = value as? TextReplacement {
                        let identifier = ObjectIdentifier(replacement)
                        let core = replacements[identifier] ?? makeReplacement(replacement)

                        if let core = core {
                            replacements[identifier] = core
                            found[UnsafeRawPointer(core)] = replacement

                            var attribute = makeAttribute(TRAttributeReplacement)
                            attribute.value.replacement = core
                            pending.append(attribute)
                        }
                    }

                case .paragraphStyle:
                    if let style = value as? NSParagraphStyle {
                        setParagraphStyle(style, in: range, of: core)
                    }

                default:
                    break
                }
            }

            for var attribute in pending {
                TRTextSetAttribute(core, TRUInteger(range.location), TRUInteger(range.length), &attribute)
            }
        }

        TRTextEndEditing(core)

        // The text holds the replacements now.
        for replacement in replacements.values {
            TRReplacementRelease(replacement)
        }

        objects.typefaces.merge(typefaces) { (first, _) in first }
        objects.replacements.merge(found) { (first, _) in first }

        return core
    }

    /// Makes the default attributes of Core from those of the wrapper, and notes the typeface.
    static func makeDefaultAttributes(from attributes: [NSAttributedString.Key: Any],
                                      objects: inout CoreTextObjects) -> [TRAttribute] {
        var result: [TRAttribute] = []

        for (key, value) in attributes {
            switch key {
            case .typeface:
                if let typeface = value as? Typeface {
                    var attribute = makeAttribute(TRAttributeTypeface)
                    attribute.value.typeface = typeface.core
                    result.append(attribute)
                    objects.typefaces[typeface.core] = typeface
                }

            case .typeSize:
                if let size = number(value) {
                    var attribute = makeAttribute(TRAttributePointSize)
                    attribute.value.pointSize = TRFloat(max(size, 0.0))
                    result.append(attribute)
                }

            case .scaleX:
                if let scale = number(value) {
                    var attribute = makeAttribute(TRAttributeScaleX)
                    attribute.value.scaleX = TRFloat(scale)
                    result.append(attribute)
                }

            case .scaleY:
                if let scale = number(value) {
                    var attribute = makeAttribute(TRAttributeScaleY)
                    attribute.value.scaleY = TRFloat(scale)
                    result.append(attribute)
                }

            case .baselineOffset:
                if let offset = number(value) {
                    var attribute = makeAttribute(TRAttributeBaselineOffset)
                    attribute.value.baselineOffset = TRFloat(offset)
                    result.append(attribute)
                }

            case .obliqueness:
                if let skew = number(value) {
                    var attribute = makeAttribute(TRAttributeObliqueness)
                    attribute.value.obliqueness = TRFloat(skew)
                    result.append(attribute)
                }

            default:
                break
            }
        }

        return result
    }
}
