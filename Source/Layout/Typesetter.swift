//
// Copyright (C) 2019-2023 Muhammad Tayyab Akram
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

import CoreGraphics
import Foundation

/// Represents a typesetter which performs text layout. It can be used to create lines, perform line
/// breaking, and do other contextual analysis based on the characters in the string.
public class Typesetter {
    /// The source text for which this typesetter object was created.
    public let text: NSAttributedString

    let defaultAttributes: [NSAttributedString.Key: Any]
    let breaks: BreakClassifier
    let paragraphs: [BidiParagraph]
    let runs: [IntrinsicRun]

    /// Creates a typesetter using the specified text and the default attributes.
    ///
    /// - Parameters:
    ///   - text: The text that needs to be typeset.
    ///   - defaultAttributes: The default attributes that should be applied on the text.
    public init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        let shapeResolver = ShapeResolver(text: text, defaultAttributes: defaultAttributes)
        let shapeResult = shapeResolver.makeParagraphsAndRuns()

        self.text = text
        self.defaultAttributes = defaultAttributes
        self.breaks = BreakClassifier(string: text.string)
        self.paragraphs = shapeResult.paragraphs
        self.runs = shapeResult.runs
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
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestForwardBreak(for: extent, in: codeUnitRange, with: breakMode)
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
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestBackwardBreak(for: extent, in: codeUnitRange, with: breakMode)
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

    /// Creates a simple line having the specified UTF-16 range.
    ///
    /// - Parameter codeUnitRange: The UTF-16 range of the line in source string.
    /// - Returns: The new line.
    public func makeSimpleLine(codeUnitRange: Range<Int>) -> ComposedLine {
        let lineResolver = LineResolver(text: text, defaultAttributes: defaultAttributes, paragraphs: paragraphs, runs: runs)
        return lineResolver.makeSimpleLine(codeUnitRange: codeUnitRange)
    }

    /// Creates a simple line having the specified character range.
    ///
    /// - Parameter characterRange: The character range of the line in source string.
    /// - Returns: The new line.
    public func makeSimpleLine(characterRange: Range<String.Index>) -> ComposedLine {
        let codeUnitRange: Range<Int> = text.string.utf16Range(forCharacterRange: characterRange)
        return makeSimpleLine(codeUnitRange: codeUnitRange)
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
        let characterRange = text.string.characterRange(forUTF16Range: codeUnitRange)
        let tokenResolver = TokenResolver(string: text.string, runs: runs)
        let tokenLine = tokenResolver.makeTokenLine(range: characterRange,
                                                    truncationPlace: truncationPlace,
                                                    tokenString: tokenString)

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
        let tokenResolver = TokenResolver(string: text.string, runs: runs)
        let tokenLine = tokenResolver.makeTokenLine(range: characterRange,
                                                    truncationPlace: truncationPlace,
                                                    tokenString: tokenString)

        return makeTruncatedLine(characterRange: characterRange, extent: extent,
                                 breakMode: breakMode,
                                 truncationPlace: truncationPlace,
                                 tokenLine: tokenLine)
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
        let lineResolver = LineResolver(text: text, defaultAttributes: defaultAttributes,
                                        paragraphs: paragraphs, runs: runs)
        let breakResolver = BreakResolver(string: text.string,
                                          paragraphs: paragraphs, runs: runs, breaks: breaks)

        return lineResolver.makeCompactLine(codeUnitRange: codeUnitRange, extent: extent,
                                            breaks: breakResolver, mode: breakMode,
                                            place: truncationPlace, token: tokenLine)
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
        let lineResolver = LineResolver(text: text, defaultAttributes: defaultAttributes,
                                        paragraphs: paragraphs, runs: runs)

        return lineResolver.makeJustifiedLine(codeUnitRange: codeUnitRange,
                                              justificationFactor: justificationFactor,
                                              justificationExtent: justificationExtent)
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
