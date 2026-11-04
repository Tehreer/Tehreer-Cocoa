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

/// The `MutableTypesetter` class is a text that can be edited: its code units can be appended, inserted,
/// deleted and replaced, and its attributes set and removed. It is not thread safe, so it must not
/// be edited while another thread uses it.
public final class MutableTypesetter: Typesetter, @unchecked Sendable {
    // The replacements of Core that are made for the replacements of the wrapper. One is made for
    // each of them, so that Core takes the ranges of it as a single run if nothing else changes.
    private var replacementCores: [ObjectIdentifier: TRReplacementRef] = [:]

    private var mutableCore: TRMutableTypesetterRef {
        return core
    }

    init(
        core: TRMutableTypesetterRef,
        objects: CoreTextObjects,
        defaultAttributes: [NSAttributedString.Key: Any]
    ) {
        super.init(core: core, objects: objects, defaultAttributes: defaultAttributes, source: nil)
    }

    /// Creates a typesetter of an empty text.
    ///
    /// - Parameter defaultAttributes: The default attributes that should be applied on the text.
    public convenience init(defaultAttributes: [NSAttributedString.Key: Any]) {
        var objects = CoreTextObjects()
        let defaults = TRAttribute.defaults(from: defaultAttributes, objects: &objects)

        self.init(
            core: TRTypesetterCreateMutable(
                TRStringEncoding(TRStringEncodingUTF16),
                defaults,
                TRUInteger(defaults.count)
            )!,
            objects: objects,
            defaultAttributes: defaultAttributes
        )
    }

    /// Creates a typesetter of the attributed string. The attributes that Core knows are set on the
    /// ranges, see `setAttribute(_:value:in:)`.
    public convenience init(
        attributedString: NSAttributedString,
        defaultAttributes: [NSAttributedString.Key: Any]
    ) {
        self.init(defaultAttributes: defaultAttributes)

        // A change of an attribute shapes its paragraph again unless it is made in a batch, which
        // shapes each paragraph once, at the end.
        beginEditing()
        append(attributedString.string)

        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { (attributes, range, _) in
            setAttributes(attributes, in: range.location ..< NSMaxRange(range))
        }

        endEditing()
    }

    deinit {
        // The text holds the replacements too.
        for replacement in replacementCores.values {
            TRReplacementRelease(replacement)
        }
    }

    public override var isMutable: Bool {
        return true
    }

    /// Begins a batch of edits, which Core handles together when `endEditing()` is called. No line
    /// can be made until it ends. The attributes can be set and removed in a batch, and each
    /// paragraph that they change is shaped once, at its end, so a text with many attributes is
    /// built in a batch.
    public func beginEditing() {
        TRTypesetterBeginEditing(mutableCore)
    }

    /// Ends a batch of edits.
    public func endEditing() {
        TRTypesetterEndEditing(mutableCore)
    }

    private func edited<Result>(_ result: Result) -> Result {
        source = nil

        return result
    }

    private func withUnits<Result>(_ string: String, _ body: (UnsafePointer<UInt16>?, TRUInteger) -> Result) -> Result {
        return Array(string.utf16).withUnsafeBufferPointer { (pointer) in
            body(pointer.baseAddress, TRUInteger(pointer.count))
        }
    }

    /// Appends the string to the end of this text.
    ///
    /// - Returns: `true` if the string was appended.
    @discardableResult
    public func append(_ string: String) -> Bool {
        return edited(withUnits(string) { TRTypesetterAppendCodeUnits(mutableCore, $0, $1) != 0 })
    }

    /// Inserts the string at an index of this text.
    ///
    /// - Returns: `true` if the string was inserted, `false` if the index is past the end.
    @discardableResult
    public func insert(_ string: String, at index: Int) -> Bool {
        guard index >= 0 else {
            return false
        }

        return edited(withUnits(string) { TRTypesetterInsertCodeUnits(
            mutableCore,
            TRUInteger(index),
            $0,
            $1
        ) != 0 })
    }

    /// Deletes a range of this text.
    ///
    /// - Returns: `true` if the range was deleted, `false` if it is not within the text.
    @discardableResult
    public func delete(in range: Range<Int>) -> Bool {
        guard range.lowerBound >= 0 else {
            return false
        }

        return edited(TRTypesetterDeleteCodeUnits(
            mutableCore,
            TRUInteger(range.lowerBound),
            TRUInteger(range.count)
        ) != 0)
    }

    /// Replaces a range of this text with the string.
    ///
    /// - Returns: `true` if the range was replaced, `false` if it is not within the text.
    @discardableResult
    public func replace(_ range: Range<Int>, with string: String) -> Bool {
        guard range.lowerBound >= 0 else {
            return false
        }

        return edited(withUnits(string) {
            TRTypesetterReplaceCodeUnits(
                mutableCore,
                TRUInteger(range.lowerBound),
                TRUInteger(range.count),
                $0,
                $1
            ) != 0
        })
    }

    /// Replaces the whole content of this text with the string, removing all of its attributes.
    ///
    /// - Returns: `true` if the content was replaced.
    @discardableResult
    public func setString(_ string: String) -> Bool {
        return edited(withUnits(string) { TRTypesetterSetCodeUnits(mutableCore, $0, $1) != 0 })
    }

    private func set(_ attribute: TRAttribute, in range: Range<Int>) -> Bool {
        var attribute = attribute

        return TRTypesetterSetAttribute(
            mutableCore,
            TRUInteger(range.lowerBound),
            TRUInteger(range.count),
            &attribute
        ) != 0
    }

    private func number(_ value: Any) -> CGFloat? {
        return (value as? NSNumber).flatMap { CGFloat(exactly: $0) }
    }

    /// Sets an attribute on a range of this text. These keys are known: `.typeface`, `.typeSize`,
    /// `.scaleX`, `.scaleY`, `.baselineOffset`, `.obliqueness`, `.replacement`, `.foregroundColor`,
    /// `.backgroundColor`, `.underlineStyle`, `.strikethroughStyle`, `.underlineColor` and
    /// `.strikethroughColor` (which both set the color of the decorations), `.language`,
    /// `.fontFeatures` and `.paragraphStyle`. A zero underline or strikethrough style removes it.
    ///
    /// - Returns: `true` if the attribute was set, `false` if the key or the value is not known, or
    ///            the range is not within the text.
    @discardableResult
    public func setAttribute(_ key: NSAttributedString.Key, value: Any, in range: Range<Int>) -> Bool {
        var attributes: [TRAttribute] = []
        var features: TRFontFeaturesRef?

        switch key {
        case .typeface:
            if let typeface = value as? Typeface {
                attributes.append(.typeface(typeface.core))
                objects.typefaces[typeface.core] = typeface
            }
        case .typeSize:
            attributes = number(value).map { [.typeSize($0)] } ?? []
        case .scaleX:
            attributes = number(value).map { [.scaleX($0)] } ?? []
        case .scaleY:
            attributes = number(value).map { [.scaleY($0)] } ?? []
        case .baselineOffset:
            attributes = number(value).map { [.baselineOffset($0)] } ?? []
        case .obliqueness:
            attributes = number(value).map { [.obliqueness($0)] } ?? []
        case .replacement:
            if let replacement = value as? TextReplacement {
                let identifier = ObjectIdentifier(replacement)
                let core = replacementCores[identifier] ?? replacement.makeCoreReplacement()

                if let core = core {
                    replacementCores[identifier] = core
                    objects.replacements[UnsafeRawPointer(core)] = replacement
                    attributes.append(.replacement(core))
                }
            }
        case .foregroundColor:
            attributes = (value as? UIColor).map { [.foregroundColor($0)] } ?? []
        case .backgroundColor:
            attributes = (value as? UIColor).map { [.backgroundColor($0)] } ?? []
        case .underlineStyle:
            if let style = number(value) {
                if style != 0 {
                    attributes.append(.underline())
                } else {
                    return removeAttribute(key, in: range)
                }
            }
        case .strikethroughStyle:
            if let style = number(value) {
                if style != 0 {
                    attributes.append(.strikethrough())
                } else {
                    return removeAttribute(key, in: range)
                }
            }
        case .underlineColor, .strikethroughColor:
            attributes = (value as? UIColor).map { [.decorationColor($0)] } ?? []
        case .language:
            attributes = (value as? String).map { [.language($0)] } ?? []
        case .fontFeatures:
            if let dictionary = value as? [SFNTTag: Int] {
                let items = dictionary.map { TROpenTypeFeature(
                    tag: $0.key.rawValue,
                    value: UInt32(clamping: max($0.value, 0))
                ) }

                features = TRFontFeaturesCreate(items, TRUInteger(items.count))
                attributes = features.map { [.fontFeatures($0)] } ?? []
            }
        case .paragraphStyle:
            if let style = value as? NSParagraphStyle {
                attributes = TRAttribute.attributes(of: style)
            }
        default:
            break
        }

        defer {
            // The text holds the font features now.
            features.map { TRFontFeaturesRelease($0) }
        }

        guard !attributes.isEmpty else {
            return false
        }

        if key == .paragraphStyle && range.lowerBound >= 0 {
            // The fields that the style leaves out are zero, so the old ones must not stay.
            let kept = Set(attributes.map { Int($0.type) })

            for type in TRAttribute.paragraphTypes where !kept.contains(type) {
                TRTypesetterRemoveAttribute(
                    mutableCore,
                    TRUInteger(range.lowerBound),
                    TRUInteger(range.count),
                    TRAttributeType(type)
                )
            }
        }

        return edited(attributes.reduce(true) { set($1, in: range) && $0 })
    }

    /// Sets the attributes that are known on a range of this text, as `setAttribute(_:value:in:)`
    /// does. The color of the decorations comes from `.underlineColor`, or else from
    /// `.strikethroughColor`.
    public func setAttributes(_ attributes: [NSAttributedString.Key: Any], in range: Range<Int>) {
        for (key, value) in attributes where key != .underlineColor {
            setAttribute(key, value: value, in: range)
        }

        if let color = attributes[.underlineColor] {
            setAttribute(.underlineColor, value: color, in: range)
        }
    }

    /// Removes an attribute from a range of this text.
    ///
    /// - Returns: `true` if the attribute was removed, `false` if the key is not known or the range
    ///            is not within the text.
    @discardableResult
    public func removeAttribute(_ key: NSAttributedString.Key, in range: Range<Int>) -> Bool {
        let types: [Int]

        switch key {
        case .typeface:
            types = [Int(TRAttributeTypeface)]
        case .typeSize:
            types = [Int(TRAttributeTypeSize)]
        case .scaleX:
            types = [Int(TRAttributeScaleX)]
        case .scaleY:
            types = [Int(TRAttributeScaleY)]
        case .baselineOffset:
            types = [Int(TRAttributeBaselineOffset)]
        case .obliqueness:
            types = [Int(TRAttributeObliqueness)]
        case .replacement:
            types = [Int(TRAttributeReplacement)]
        case .foregroundColor:
            types = [Int(TRAttributeForegroundColor)]
        case .backgroundColor:
            types = [Int(TRAttributeBackgroundColor)]
        case .underlineStyle:
            types = [Int(TRAttributeUnderline)]
        case .strikethroughStyle:
            types = [Int(TRAttributeStrikethrough)]
        case .underlineColor, .strikethroughColor:
            types = [Int(TRAttributeDecorationColor)]
        case .language:
            types = [Int(TRAttributeLanguage)]
        case .fontFeatures:
            types = [Int(TRAttributeFontFeatures)]
        case .paragraphStyle:
            types = TRAttribute.paragraphTypes
        default:
            return false
        }

        guard range.lowerBound >= 0 else {
            return false
        }

        return edited(types.reduce(true) {
            TRTypesetterRemoveAttribute(
                mutableCore,
                TRUInteger(range.lowerBound),
                TRUInteger(range.count),
                TRAttributeType($1)
            ) != 0 && $0
        })
    }
}
