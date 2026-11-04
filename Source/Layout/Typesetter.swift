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

/// The typefaces and replacements of a text that has been given to Core, which Core hands back as
/// pointers.
struct CoreTextObjects: @unchecked Sendable {
    var typefaces: [TRTypefaceRef: Typeface] = [:]
    var replacements: [UnsafeRawPointer: TextReplacement] = [:]
}

/// The `Typesetter` class represents the text of Core: UTF-16 code units along with the attributes of
/// their ranges, such as typeface, type size, colors, decorations, language and font features. A
/// typesetter lays out a text.
///
/// A text does not change once it is created, so it can be shared between threads. Use
/// `MutableTypesetter` to edit a text.
// Unchecked because the objects are set when the attributes are, and only a mutable text sets them
// again.
public class Typesetter: @unchecked Sendable {
    let core: TRTypesetterRef
    var objects: CoreTextObjects

    /// The default attributes that fill in what the text does not set. Only `.typeface`,
    /// `.typeSize`, `.scaleX`, `.scaleY`, `.baselineOffset` and `.obliqueness` are looked at.
    public let defaultAttributes: [NSAttributedString.Key: Any]

    // The attributed string that this text was made from, which has the attributes that Core does
    // not know, such as links. It is dropped when the text is edited.
    var source: NSAttributedString?
    private let attributedStringCache = Lazy<NSAttributedString>()
    private let stringCache = Lazy<String>()

    /// Takes over the reference of the typesetter of Core.
    init(
        core: TRTypesetterRef,
        objects: CoreTextObjects,
        defaultAttributes: [NSAttributedString.Key: Any],
        source: NSAttributedString?
    ) {
        self.core = core
        self.objects = objects
        self.defaultAttributes = defaultAttributes
        self.source = source
    }

    deinit {
        TRTypesetterRelease(core)
    }

    /// Creates a typesetter of the string, which has no attributes.
    ///
    /// - Parameters:
    ///   - string: The string of the text.
    ///   - defaultAttributes: The default attributes that should be applied on the text.
    public convenience init(string: String, defaultAttributes: [NSAttributedString.Key: Any]) {
        var objects = CoreTextObjects()
        let defaults = TRAttribute.defaults(from: defaultAttributes, objects: &objects)
        let units = Array(string.utf16)
        let core = units.withUnsafeBufferPointer { (pointer) in
            TRTypesetterCreate(
                pointer.baseAddress,
                TRUInteger(pointer.count),
                TRStringEncoding(TRStringEncodingUTF16),
                defaults,
                TRUInteger(defaults.count)
            )
        }

        self.init(core: core!, objects: objects, defaultAttributes: defaultAttributes, source: nil)
    }

    /// Creates a typesetter of the attributed string. The attributes that Core knows are set on the
    /// ranges: the keys of `NSAttributedString.Key` that are listed in
    /// `MutableTypesetter.setAttribute`.
    ///
    /// - Parameters:
    ///   - text: The text that needs to be typeset.
    ///   - defaultAttributes: The default attributes that should be applied on the text.
    public convenience init(
        text attributedString: NSAttributedString,
        defaultAttributes: [NSAttributedString.Key: Any]
    ) {
        let mutable = MutableTypesetter(
            attributedString: attributedString,
            defaultAttributes: defaultAttributes
        )
        let core = TRTypesetterCreateCopy(mutable.core)

        self.init(
            core: core!,
            objects: mutable.objects,
            defaultAttributes: defaultAttributes,
            source: attributedString.copy() as? NSAttributedString
        )
    }

    /// Whether the text of this typesetter can be edited.
    public var isMutable: Bool {
        return false
    }

    /// The number of UTF-16 code units in this text.
    public var length: Int {
        return Int(TRTypesetterGetLength(core))
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
        guard range.lowerBound >= 0 && range.upperBound <= length else {
            return nil
        }

        var units = [UInt16](repeating: 0, count: range.count)
        let isCopied = TRTypesetterGetCodeUnits(
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

        // The attributed string of a text that can change is not kept.
        if isMutable {
            return makeAttributedString()
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
        guard let list = TRTypesetterCopyAttributes(core, TRUInteger(index), &length) else {
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
                attributes[.fontFeatures] = Typesetter.makeFeatures(of: value.fontFeatures)
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

    /// Finds the boundary of a given type that is next to a code unit index, according to Unicode
    /// Standard Annex #29 for graphemes and words, and the paragraph separators of the text for
    /// paragraphs. The start and the end of the text are boundaries of every type. It needs no
    /// typeface, and it is not available while a mutable typesetter is in an editing batch.
    ///
    /// - Parameters:
    ///   - index: The UTF-16 index to search from, which may be the length of the text.
    ///   - type: The type of the boundary.
    ///   - direction: The direction of the search.
    /// - Returns: The UTF-16 index of the boundary, or `nil` if there is none in that direction.
    public func findBoundary(
        from index: Int,
        type: BoundaryType,
        direction: BoundaryDirection
    ) -> Int? {
        guard index >= 0 else {
            return nil
        }

        let boundary = TRTypesetterFindBoundary(
            core,
            TRUInteger(index),
            type.coreValue,
            direction.coreValue
        )

        return boundary != TRUInteger.max ? Int(boundary) : nil
    }

    /// Gets the range of the segment of a given boundary type that contains a code unit, for
    /// example the word under a caret.
    ///
    /// - Parameters:
    ///   - index: The UTF-16 index that the segment contains, which may be the length of the text
    ///            and has an empty segment.
    ///   - type: The type of the boundary.
    /// - Returns: The range of the segment, or `nil` if the index is past the end of the text.
    public func boundaryRange(at index: Int, type: BoundaryType) -> Range<Int>? {
        guard index >= 0 else {
            return nil
        }

        let range = TRTypesetterGetBoundaryRange(core, TRUInteger(index), type.coreValue)

        return range.index != TRUInteger.max
            ? Int(range.index) ..< Int(range.index + range.length)
            : nil
    }

    /// Returns an immutable copy of this text.
    public func copy() -> Typesetter {
        return Typesetter(
            core: TRTypesetterCreateCopy(core)!,
            objects: objects,
            defaultAttributes: defaultAttributes,
            source: source
        )
    }

    /// Returns a mutable copy of this text.
    public func mutableCopy() -> MutableTypesetter {
        return MutableTypesetter(
            core: TRTypesetterCreateMutableCopy(core)!,
            objects: objects,
            defaultAttributes: defaultAttributes
        )
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

    private func makeLine(_ line: TRComposedLineRef?) -> ComposedLine {
        guard let line = line else {
            fatalError("Could not make the line")
        }

        return ComposedLine(core: line, string: string, objects: objects)
    }

    /// Suggests a forward break index based on the specified range and the extent. The measurement
    /// proceeds from first UTF-16 code unit to last code unit. If there is still room after
    /// measuring all characters, then last index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range for break calculations.
    ///   - extent: The requested break extent.
    ///   - mode: The requested break mode.
    /// - Returns: The index (exclusive) that would cause the break.
    public func suggestForwardBreak(inCodeUnitRange codeUnitRange: Range<Int>, extent: CGFloat, breakMode: BreakMode) -> Int {
        precondition(!codeUnitRange.isEmpty, "The range to break is empty")
        precondition(codeUnitRange.lowerBound >= 0 && codeUnitRange.upperBound <= length, String.indexOutOfRange)

        return Int(TRTypesetterSuggestForwardBreak(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            TRFloat(extent),
            breakMode.coreValue
        ))
    }

    /// Suggests a forward break index based on the specified range and the extent. The measurement
    /// proceeds from first character to last character. If there is still room after measuring all
    /// characters, then last index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - characterRange: The character range for break calculations.
    ///   - extent: The requested break extent.
    ///   - mode: The requested break mode.
    /// - Returns: The index (exclusive) that would cause the break.
    public func suggestForwardBreak(inCharacterRange characterRange: Range<String.Index>, extent: CGFloat, breakMode: BreakMode) -> String.Index {
        let string = string
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = suggestForwardBreak(inCodeUnitRange: codeUnitRange,
                                             extent: extent, breakMode: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }

    /// Suggests a backward break index based on the specified range and the extent. The measurement
    /// proceeds from last UTF-16 code unit to first code unit. If there is still room after
    /// measuring all characters, then start index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range for break calculations.
    ///   - extent: The requested break extent.
    ///   - mode: The requested break mode.
    /// - Returns: The index (inclusive) that would cause the break.
    public func suggestBackwardBreak(inCodeUnitRange codeUnitRange: Range<Int>, extent: CGFloat, breakMode: BreakMode) -> Int {
        precondition(!codeUnitRange.isEmpty, "The range to break is empty")
        precondition(codeUnitRange.lowerBound >= 0 && codeUnitRange.upperBound <= length, String.indexOutOfRange)

        return Int(TRTypesetterSuggestBackwardBreak(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            TRFloat(extent),
            breakMode.coreValue
        ))
    }

    /// Suggests a backward break index based on the specified range and the extent. The measurement
    /// proceeds from last character to first character. If there is still room after measuring all
    /// characters, then start index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - characterRange: The character range for break calculations.
    ///   - extent: The requested break extent.
    ///   - mode: The requested break mode.
    /// - Returns: The index (inclusive) that would cause the break.
    public func suggestBackwardBreak(inCharacterRange characterRange: Range<String.Index>, extent: CGFloat, breakMode: BreakMode) -> String.Index {
        let string = string
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let breakIndex = suggestBackwardBreak(inCodeUnitRange: codeUnitRange,
                                              extent: extent, breakMode: breakMode)

        return string.characterIndex(forUTF16Index: breakIndex)
    }

    /// Creates a simple line having the specified UTF-16 range, with all of its text in the order
    /// that it is shown.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range of the line in source string.
    ///   - layoutWidth: The width of the frame that the line is made for, or zero if there is none.
    ///                  The replacements that decide their room by the width of the frame get it
    ///                  from here.
    /// - Returns: The new line.
    public func makeSimpleLine(codeUnitRange: Range<Int>, layoutWidth: CGFloat = 0.0) -> ComposedLine {
        precondition(!codeUnitRange.isEmpty, "The range of a line is empty")

        return makeLine(TRTypesetterCreateSimpleLine(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            TRFloat(layoutWidth)
        ))
    }

    /// Creates a simple line having the specified character range.
    ///
    /// - Parameters:
    ///   - characterRange: The character range of the line in source string.
    ///   - layoutWidth: The width of the frame that the line is made for, or zero if there is none.
    /// - Returns: The new line.
    public func makeSimpleLine(characterRange: Range<String.Index>, layoutWidth: CGFloat = 0.0) -> ComposedLine {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeSimpleLine(codeUnitRange: codeUnitRange, layoutWidth: layoutWidth)
    }

    /// Creates a line of specified UTF-16 range, truncating it if it overflows the specified extent.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range of the line in source string.
    ///   - extent: The extent at which truncation will begin.
    ///   - breakMode: The truncation mode to be used on the line.
    ///   - truncationPlace: The place of truncation for the line.
    ///   - tokenString: The token string to indicate the line truncation.
    /// - Returns: The new line which is truncated if it overflows the `extent`.
    public func makeTruncatedLine(codeUnitRange: Range<Int>, extent: CGFloat,
                                  breakMode: BreakMode, truncationPlace: TruncationPlace,
                                  tokenString: String?) -> ComposedLine {
        precondition(!codeUnitRange.isEmpty, "The range of a line is empty")

        let units = tokenString.map { Array($0.utf16) }
        let token = units.map { (units) in
            units.withUnsafeBufferPointer { (pointer) in
                TRTypesetterCreateTruncationToken(
                    core,
                    TRUInteger(codeUnitRange.lowerBound),
                    TRUInteger(codeUnitRange.count),
                    truncationPlace.coreValue,
                    pointer.baseAddress,
                    TRUInteger(pointer.count),
                    TRStringEncoding(TRStringEncodingUTF16)
                )
            }
        } ?? TRTypesetterCreateTruncationToken(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            truncationPlace.coreValue,
            nil,
            0,
            TRStringEncoding(TRStringEncodingUTF16)
        )

        let tokenLine = makeLine(token)

        return makeTruncatedLine(codeUnitRange: codeUnitRange, extent: extent,
                                 breakMode: breakMode,
                                 truncationPlace: truncationPlace,
                                 tokenLine: tokenLine)
    }

    /// Creates a line of specified string range, truncating it if it overflows the specified extent.
    ///
    /// - Parameters:
    ///   - characterRange: The range of the line in source string.
    ///   - extent: The extent at which truncation will begin.
    ///   - breakMode: The truncation mode to be used on the line.
    ///   - truncationPlace: The place of truncation for the line.
    ///   - tokenString: The token string to indicate the line truncation.
    /// - Returns: The new line which is truncated if it overflows the `extent`.
    public func makeTruncatedLine(characterRange: Range<String.Index>, extent: CGFloat,
                                  breakMode: BreakMode, truncationPlace: TruncationPlace,
                                  tokenString: String?) -> ComposedLine {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeTruncatedLine(codeUnitRange: codeUnitRange, extent: extent,
                                 breakMode: breakMode, truncationPlace: truncationPlace,
                                 tokenString: tokenString)
    }

    /// Creates a line of specified UTF-16 range, truncating it if it overflows the specified extent.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range of the line in source string.
    ///   - extent: The extent at which truncation will begin.
    ///   - breakMode: The truncation mode to be used on the line.
    ///   - truncationPlace: The place of truncation for the line.
    ///   - tokenLine: The token line to indicate the line truncation.
    /// - Returns: The new line which is truncated if it overflows the `extent`.
    public func makeTruncatedLine(codeUnitRange: Range<Int>, extent: CGFloat,
                                  breakMode: BreakMode, truncationPlace: TruncationPlace,
                                  tokenLine: ComposedLine) -> ComposedLine {
        precondition(!codeUnitRange.isEmpty, "The range of a line is empty")

        return makeLine(TRTypesetterCreateTruncatedLine(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            TRFloat(extent),
            breakMode.coreValue,
            truncationPlace.coreValue,
            tokenLine.core
        ))
    }

    /// Creates a line of specified character range, truncating it if it overflows the specified extent.
    ///
    /// - Parameters:
    ///   - characterRange: The character range of the line in source string.
    ///   - extent: The extent at which truncation will begin.
    ///   - breakMode: The truncation mode to be used on the line.
    ///   - truncationPlace: The place of truncation for the line.
    ///   - tokenLine: The token line to indicate the line truncation.
    /// - Returns: The new line which is truncated if it overflows the `extent`.
    public func makeTruncatedLine(characterRange: Range<String.Index>, extent: CGFloat,
                                  breakMode: BreakMode, truncationPlace: TruncationPlace,
                                  tokenLine: ComposedLine) -> ComposedLine {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeTruncatedLine(codeUnitRange: codeUnitRange, extent: extent, breakMode: breakMode,
                                 truncationPlace: truncationPlace, tokenLine: tokenLine)
    }

    /// Creates a justified line of specified UTF-16 range.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The UTF-16 range of the line in source string.
    ///   - justificationFactor: The factor that specifies the full or partial justification. When
    ///                          set to 1.0 or greater, full justification is performed. If this
    ///                          parameter is set to less than 1.0, varying degrees of partial
    ///                          justification are performed. If it is set to 0 or less, no
    ///                          justification is performed.
    ///   - justificationExtent: The extent at which the line should be justified. If it is less
    ///                          than the actual width of the line, then negative justification is
    ///                          performed (that is, words are squeezed together).
    /// - Returns: The new justified line.
    public func makeJustifiedLine(codeUnitRange: Range<Int>,
                                  justificationFactor: CGFloat,
                                  justificationExtent: CGFloat) -> ComposedLine {
        precondition(!codeUnitRange.isEmpty, "The range of a line is empty")

        return makeLine(TRTypesetterCreateJustifiedLine(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count),
            TRFloat(justificationFactor),
            TRFloat(justificationExtent)
        ))
    }

    /// Creates a justified line of specified character range.
    ///
    /// - Parameters:
    ///   - characterRange: The character range of the line in source string.
    ///   - justificationFactor: The factor that specifies the full or partial justification. When
    ///                          set to 1.0 or greater, full justification is performed. If this
    ///                          parameter is set to less than 1.0, varying degrees of partial
    ///                          justification are performed. If it is set to 0 or less, no
    ///                          justification is performed.
    ///   - justificationExtent: The extent at which the line should be justified. If it is less
    ///                          than the actual width of the line, then negative justification is
    ///                          performed (that is, words are squeezed together).
    /// - Returns: The new justified line.
    public func makeJustifiedLine(characterRange: Range<String.Index>,
                                  justificationFactor: CGFloat,
                                  justificationExtent: CGFloat) -> ComposedLine {
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeJustifiedLine(codeUnitRange: codeUnitRange,
                                 justificationFactor: justificationFactor,
                                 justificationExtent: justificationExtent)
    }
}
