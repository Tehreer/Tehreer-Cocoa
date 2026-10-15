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

/// Represents a typesetter which performs text layout. It can be used to create lines, perform line
/// breaking, and do other contextual analysis based on the characters in the string.
///
/// A typesetter does not change once it is created, so it can be shared between threads, and lines
/// can be made from it by several of them at a time.
// Unchecked because the attributes are `Any` values, which the compiler cannot prove immutable.
public final class Typesetter: @unchecked Sendable {
    /// The source text for which this typesetter object was created. It is an immutable copy, so
    /// editing the text that was given to the typesetter does not change it.
    public let text: TText

    let core: TRTypesetterRef
    let defaultAttributes: [NSAttributedString.Key: Any]

    /// The typefaces and replacements of the text, which the runs of the lines point to.
    let objects: CoreTextObjects

    /// Creates a typesetter using the specified text and the default attributes.
    ///
    /// - Parameters:
    ///   - text: The text that needs to be typeset.
    ///   - defaultAttributes: The default attributes that should be applied on the text. Only
    ///                        `.typeface`, `.typeSize`, `.scaleX`, `.scaleY`, `.baselineOffset` and
    ///                        `.obliqueness` are looked at.
    public init(text: TText, defaultAttributes: [NSAttributedString.Key: Any]) {
        let snapshot = text.isMutable ? text.copy() : text
        var objects = snapshot.objects

        let defaults = TRAttribute.defaults(from: defaultAttributes, objects: &objects)

        guard let core = TRTypesetterCreate(
            snapshot.core,
            defaults,
            TRUInteger(defaults.count)
        ) else {
            fatalError("Typeface is not specified")
        }

        self.text = snapshot
        self.defaultAttributes = defaultAttributes
        self.core = core
        self.objects = objects
    }

    /// Creates a typesetter using the specified attributed string and the default attributes.
    ///
    /// - Parameters:
    ///   - text: The text that needs to be typeset.
    ///   - defaultAttributes: The default attributes that should be applied on the text.
    public convenience init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        self.init(text: TText(attributedString: text), defaultAttributes: defaultAttributes)
    }

    deinit {
        TRTypesetterRelease(core)
    }

    private func makeLine(_ line: TRComposedLineRef?) -> ComposedLine {
        guard let line = line else {
            fatalError("Could not make the line")
        }

        return ComposedLine(core: line, string: text.string, objects: objects)
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
        let string = text.string
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
        let string = text.string
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
        let codeUnitRange: Range<Int> = text.string.utf16Range(forCharacterRange: characterRange)

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
        let codeUnitRange: Range<Int> = text.string.utf16Range(forCharacterRange: characterRange)

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
        let codeUnitRange: Range<Int> = text.string.utf16Range(forCharacterRange: characterRange)

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
        let codeUnitRange: Range<Int> = text.string.utf16Range(forCharacterRange: characterRange)

        return makeJustifiedLine(codeUnitRange: codeUnitRange,
                                 justificationFactor: justificationFactor,
                                 justificationExtent: justificationExtent)
    }
}
