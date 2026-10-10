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

/// The typefaces and replacements of a text that has been given to Core, which Core hands back as
/// pointers.
struct CoreTextObjects: @unchecked Sendable {
    var typefaces: [TRTypefaceRef: Typeface] = [:]
    var replacements: [UnsafeRawPointer: TextReplacement] = [:]
}

/// The `TText` class represents the text of Core: UTF-16 code units along with the attributes of
/// their ranges, such as typeface, type size, colors, decorations, language and font features. A
/// typesetter lays out a text.
///
/// A text does not change once it is created, so it can be shared between threads. Use
/// `TMutableText` to edit a text.
// Unchecked because the objects are set when the attributes are, and only a mutable text sets them
// again.
public class TText: @unchecked Sendable {
    let core: TRTextRef
    var objects: CoreTextObjects

    // The attributed string that this text was made from, which has the attributes that Core does
    // not know, such as links. It is dropped when the text is edited.
    var source: NSAttributedString?
    private let attributedStringCache = Lazy<NSAttributedString>()
    private let stringCache = Lazy<String>()

    /// Takes over the reference of the text of Core.
    init(core: TRTextRef, objects: CoreTextObjects, source: NSAttributedString?) {
        self.core = core
        self.objects = objects
        self.source = source
    }

    deinit {
        TRTextRelease(core)
    }

    /// Creates a text of the string, which has no attributes.
    ///
    /// - Parameter string: The string of the text.
    public convenience init(string: String) {
        let units = Array(string.utf16)
        let core = units.withUnsafeBufferPointer { (pointer) in
            TRTextCreate(
                pointer.baseAddress,
                TRUInteger(pointer.count),
                TRStringEncoding(TRStringEncodingUTF16)
            )
        }

        self.init(core: core!, objects: CoreTextObjects(), source: nil)
    }

    /// Creates a text of the attributed string. The attributes that Core knows are set on the
    /// ranges: the keys of `NSAttributedString.Key` that are listed in `TMutableText.setAttribute`.
    ///
    /// - Parameter attributedString: The attributed string of the text.
    public convenience init(attributedString: NSAttributedString) {
        let mutableText = TMutableText(attributedString: attributedString)
        let core = TRTextCreateCopy(mutableText.core)

        self.init(core: core!, objects: mutableText.objects, source: attributedString)
    }

    /// Whether this text can be edited.
    public var isMutable: Bool {
        return false
    }

    /// The number of UTF-16 code units in this text.
    public var length: Int {
        return Int(TRTextGetLength(core))
    }

    /// The string of this text.
    public var string: String {
        // The string of a text that can change is not kept.
        if isMutable {
            return string(in: 0 ..< length) ?? ""
        }

        return stringCache.get { string(in: 0 ..< length) ?? "" }
    }

    /// Returns the string of a range of this text.
    ///
    /// - Parameter range: The UTF-16 range in this text.
    /// - Returns: The string of the range, or `nil` if the range is not within the text.
    public func string(in range: Range<Int>) -> String? {
        guard range.lowerBound >= 0 else {
            return nil
        }

        var units = [UInt16](repeating: 0, count: range.count)
        let isCopied = TRTextGetCodeUnits(
            core,
            TRUInteger(range.lowerBound),
            TRUInteger(range.count),
            &units
        )

        return isCopied != 0 ? String(decoding: units, as: UTF16.self) : nil
    }

    /// The attributed string of this text. It is the one that this text was made from, if it was,
    /// and otherwise it is made of the attributes of Core.
    public var attributedString: NSAttributedString {
        if let source = source {
            return source
        }

        return attributedStringCache.get { makeAttributedString() }
    }

    /// Returns the attributes at an index, and how many code units they apply to.
    ///
    /// - Parameter index: The index of a UTF-16 code unit.
    /// - Returns: The attributes that the code unit has, along with the length of the run, starting
    ///            at the index, over which they stay the same. It is `nil` if the index is not
    ///            within the text.
    public func attributes(at index: Int) -> (attributes: [NSAttributedString.Key: Any], length: Int)? {
        guard index >= 0 else {
            return nil
        }

        var length: TRUInteger = 0
        guard let list = TRTextCopyAttributes(core, TRUInteger(index), &length) else {
            return nil
        }
        defer { TRAttributeListRelease(list) }

        var attributes: [NSAttributedString.Key: Any] = [:]
        var paragraphStyle: NSMutableParagraphStyle?

        func style() -> NSMutableParagraphStyle {
            if paragraphStyle == nil {
                paragraphStyle = NSMutableParagraphStyle()
            }

            return paragraphStyle!
        }

        for itemIndex in 0 ..< TRAttributeListGetCount(list) {
            guard let item = TRAttributeListGetItem(list, itemIndex) else {
                continue
            }

            let value = item.pointee.value

            switch Int(item.pointee.type) {
            case Int(TRAttributeTypeface):
                attributes[.typeface] = objects.typefaces[value.typeface] ?? Typeface(retaining: value.typeface)
            case Int(TRAttributeTypeSize):
                attributes[.typeSize] = CGFloat(value.typeSize)
            case Int(TRAttributeScaleX):
                attributes[.scaleX] = CGFloat(value.scaleX)
            case Int(TRAttributeScaleY):
                attributes[.scaleY] = CGFloat(value.scaleY)
            case Int(TRAttributeBaselineOffset):
                attributes[.baselineOffset] = CGFloat(value.baselineOffset)
            case Int(TRAttributeObliqueness):
                attributes[.obliqueness] = CGFloat(value.obliqueness)
            case Int(TRAttributeReplacement):
                attributes[.replacement] = objects.replacements[UnsafeRawPointer(value.replacement)]
            case Int(TRAttributeForegroundColor):
                attributes[.foregroundColor] = UIColor(coreValue: value.foregroundColor)
            case Int(TRAttributeBackgroundColor):
                attributes[.backgroundColor] = UIColor(coreValue: value.backgroundColor)
            case Int(TRAttributeUnderline):
                attributes[.underlineStyle] = value.underline != 0 ? NSUnderlineStyle.single.rawValue : 0
            case Int(TRAttributeStrikethrough):
                attributes[.strikethroughStyle] = value.strikethrough != 0 ? NSUnderlineStyle.single.rawValue : 0
            case Int(TRAttributeDecorationColor):
                attributes[.underlineColor] = UIColor(coreValue: value.decorationColor)
                attributes[.strikethroughColor] = UIColor(coreValue: value.decorationColor)
            case Int(TRAttributeFontFeatures):
                attributes[.fontFeatures] = TText.makeFeatures(of: value.fontFeatures)
            case Int(TRAttributeTextAlignment):
                switch TextAlignment(coreValue: value.textAlignment) {
                case .left:
                    style().alignment = .left
                case .center:
                    style().alignment = .center
                case .right:
                    style().alignment = .right
                case .leading, .trailing:
                    style().alignment = .natural
                }
            case Int(TRAttributeFirstLineHeadIndent):
                style().firstLineHeadIndent = CGFloat(value.firstLineHeadIndent)
            case Int(TRAttributeHeadIndent):
                style().headIndent = CGFloat(value.headIndent)
            case Int(TRAttributeTailIndent):
                style().tailIndent = CGFloat(value.tailIndent)
            case Int(TRAttributeParagraphSpacingBefore):
                style().paragraphSpacingBefore = CGFloat(value.paragraphSpacingBefore)
            case Int(TRAttributeParagraphSpacing):
                style().paragraphSpacing = CGFloat(value.paragraphSpacing)
            case Int(TRAttributeLineHeightMultiple):
                style().lineHeightMultiple = CGFloat(value.lineHeightMultiple)
            case Int(TRAttributeMinimumLineHeight):
                style().minimumLineHeight = CGFloat(value.minimumLineHeight)
            case Int(TRAttributeMaximumLineHeight):
                style().maximumLineHeight = CGFloat(value.maximumLineHeight)
            case Int(TRAttributeLineSpacing):
                style().lineSpacing = CGFloat(value.lineSpacing)
            default:
                break
            }
        }

        if let paragraphStyle = paragraphStyle {
            attributes[.paragraphStyle] = paragraphStyle
        }

        return (attributes, Int(length))
    }

    /// Returns an immutable copy of this text.
    public func copy() -> TText {
        return TText(core: TRTextCreateCopy(core)!, objects: objects, source: source)
    }

    /// Returns a mutable copy of this text.
    public func mutableCopy() -> TMutableText {
        return TMutableText(core: TRTextCreateMutableCopy(core)!, objects: objects)
    }

    private func makeAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString(string: string)
        var index = 0

        while index < length, let run = attributes(at: index), run.length > 0 {
            result.addAttributes(
                run.attributes,
                range: NSRange(location: index, length: run.length)
            )
            index += run.length
        }

        return result
    }

    private static func makeFeatures(of features: TRFontFeaturesRef?) -> [SFNTTag: Int] {
        guard let features = features, let items = TRFontFeaturesGetItemsPtr(features) else {
            return [:]
        }

        var result: [SFNTTag: Int] = [:]
        for item in UnsafeBufferPointer(
            start: items,
            count: Int(TRFontFeaturesGetCount(features))
        ) {
            result[SFNTTag(rawValue: item.tag)!] = Int(item.value)
        }

        return result
    }
}

/// The `TMutableText` class is a text that can be edited: its code units can be appended, inserted,
/// deleted and replaced, and its attributes set and removed. It is not thread safe, so it must not
/// be edited while another thread uses it.
public final class TMutableText: TText, @unchecked Sendable {
    // The replacements of Core that are made for the replacements of the wrapper. One is made for
    // each of them, so that Core takes the ranges of it as a single run if nothing else changes.
    private var replacementCores: [ObjectIdentifier: TRReplacementRef] = [:]

    private var mutableCore: TRMutableTextRef {
        return core
    }

    init(core: TRMutableTextRef, objects: CoreTextObjects) {
        super.init(core: core, objects: objects, source: nil)
    }

    /// Creates an empty text.
    public convenience init() {
        self.init(
            core: TRTextCreateMutable(TRStringEncoding(TRStringEncodingUTF16))!,
            objects: CoreTextObjects()
        )
    }

    /// Creates a text of the attributed string. The attributes that Core knows are set on the
    /// ranges, see `setAttribute(_:value:in:)`.
    public convenience init(attributedString: NSAttributedString) {
        self.init()

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

    /// Begins a batch of edits, which Core handles together when `endEditing()` is called.
    public func beginEditing() {
        TRTextBeginEditing(mutableCore)
    }

    /// Ends a batch of edits.
    public func endEditing() {
        TRTextEndEditing(mutableCore)
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
        return edited(withUnits(string) { TRTextAppendCodeUnits(mutableCore, $0, $1) != 0 })
    }

    /// Inserts the string at an index of this text.
    ///
    /// - Returns: `true` if the string was inserted, `false` if the index is past the end.
    @discardableResult
    public func insert(_ string: String, at index: Int) -> Bool {
        guard index >= 0 else {
            return false
        }

        return edited(withUnits(string) { TRTextInsertCodeUnits(
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

        return edited(TRTextDeleteCodeUnits(
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
            TRTextReplaceCodeUnits(
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
        return edited(withUnits(string) { TRTextSetCodeUnits(mutableCore, $0, $1) != 0 })
    }

    private func set(_ attribute: TRAttribute, in range: Range<Int>) -> Bool {
        var attribute = attribute

        return TRTextSetAttribute(
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
                    value: UInt32(max($0.value, 0))
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
            TRTextRemoveAttribute(
                mutableCore,
                TRUInteger(range.lowerBound),
                TRUInteger(range.count),
                TRAttributeType($1)
            ) != 0 && $0
        })
    }
}
