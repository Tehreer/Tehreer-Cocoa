//
// Copyright (C) 2019 Muhammad Tayyab Akram
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
import SheenBidi

/// Specifies the base direction of a paragraph.
public enum BaseDirection: UInt8 {
    /// Base direction is left-to-right.
    case leftToRight = 0
    /// Base direction is right-to-left.
    case rightToLeft = 1
    /// Base direction depends on the first strong directional character of the paragraph according
    /// to Unicode Bidirectional Algorithm. If no strong directional character is present, the base
    /// direction is left-to-right.
    case defaultLeftToRight = 0xFE
    /// Base direction depends on the first strong directional character of the paragraph according
    /// to Unicode Bidirectional Algorithm. If no strong directional character is present, the base
    /// direction is right-to-left.
    case defaultRightToLeft = 0xFD
}

extension BaseDirection {
    var level: UInt8 {
        return self.rawValue
    }
}

/// This class implements Unicode Bidirectional Algorithm available at
/// [http://www.unicode.org/reports/tr9](http://www.unicode.org/reports/tr9).
///
/// A `BidiAlgorithm` object provides information related to individual paragraphs in source string
/// by applying rule P1. It can be used to create paragraph objects by explicitly specifying the
/// paragraph level or deriving it from rules P2 and P3. Once a paragraph object is created,
/// embedding levels of characters can be queried from it.
public class BidiAlgorithm {
    /// Maximum explicit embedding level.
    public static let maxLevel: UInt8 = 125

    private let buffer: BidiBuffer
    private let algorithm: SBAlgorithmRef

    /// Creates a bidi algorithm object for the specified string.
    ///
    /// - Parameter string: The string to apply unicode bidirectional algorithm on.
    public init?(string: String) {
        guard !string.isEmpty else {
            return nil
        }

        buffer = BidiBuffer(string)

        var codepointSequence = SBCodepointSequence(
            stringEncoding: SBStringEncoding(SBStringEncodingUTF16),
            stringBuffer: UnsafeMutableRawPointer(mutating: buffer.data),
            stringLength: SBUInteger(buffer.length))

        algorithm = SBAlgorithmCreate(&codepointSequence)
    }

    deinit {
        SBAlgorithmRelease(algorithm)
    }

    /// Returns the boundary of the first paragraph within the specified UTF-16 range.
    ///
    /// The boundary of the paragraph occurs after a character whose bidirectional type is Paragraph
    /// Separator (B), or the `codeUnitRange.upperLimit` if no such character exists before it. The
    /// exception to this rule is when a Carriage Return (CR) is followed by a Line Feed (LF). Both
    /// CR and LF are paragraph separators, but in that case, the boundary of the paragraph is
    /// considered after LF character.
    ///
    /// - Parameter codeUnitRange: The suggested UTF-16 range of the paragraph in source string.
    /// - Returns: The boundary of the first paragraph within the specified code unit range.
    public func paragraphBoundary(inCodeUnitRange codeUnitRange: Range<Int>) -> Int {
        let paragraphOffset = SBUInteger(codeUnitRange.lowerBound)
        let suggestedLength = SBUInteger(codeUnitRange.count)
        var actualLength: SBUInteger = 0

        SBAlgorithmGetParagraphBoundary(algorithm,
                                        paragraphOffset, suggestedLength,
                                        &actualLength, nil)

        return Int(paragraphOffset + actualLength)
    }

    /// Returns the boundary of the first paragraph within the specified character range.
    ///
    /// The boundary of the paragraph occurs after a character whose bidirectional type is Paragraph
    /// Separator (B), or the `characterRange.upperLimit` if no such character exists before it. The
    /// exception to this rule is when a Carriage Return (CR) is followed by a Line Feed (LF). Both
    /// CR and LF are paragraph separators, but in that case, the boundary of the paragraph is
    /// considered after LF character.
    ///
    /// - Parameter characterRange: The suggested character range of the paragraph in source string.
    /// - Returns: The boundary of the first paragraph within the specified character range.
    public func paragraphBoundary(inCharacterRange characterRange: Range<String.Index>) -> String.Index {
        let string = buffer.string
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)
        let boundaryIndex = paragraphBoundary(inCodeUnitRange: codeUnitRange)

        return string.characterIndex(forUTF16Index: boundaryIndex)
    }

    /// Creates a paragraph object processed with Unicode Bidirectional Algorithm.
    ///
    /// This method processes only first paragraph starting at `codeUnitRange.lowerBound` and ending
    /// at either `codeUnitRange.upperBound` or some character before it, in accordance with Rule P1
    /// of Unicode Bidirectional Algorithm.
    ///
    /// The paragraph level is determined by applying Rules P2-P3 and embedding levels are resolved
    /// by applying Rules X1-I2.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The suggested UTF-16 range of the paragraph in source string.
    ///   - direction: The base direction of the paragraph.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(codeUnitRange: Range<Int>, direction: BaseDirection) -> BidiParagraph? {
        return makeParagraph(codeUnitRange: codeUnitRange, baseLevel: direction.level)
    }

    /// Creates a paragraph object processed with Unicode Bidirectional Algorithm.
    ///
    /// This method processes only first paragraph starting at `codeUnitRange.lowerBound` and ending
    /// at either `codeUnitRange.upperBound` or some character before it, in accordance with Rule P1
    /// of Unicode Bidirectional Algorithm.
    ///
    /// The paragraph level is overridden by `baseLevel` parameter and embedding levels are resolved
    /// by applying Rules X1-I2.
    ///
    /// - Parameters:
    ///   - codeUnitRange: The suggested UTF-16 range of the paragraph in source string.
    ///   - baseLevel: Base level to override.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(codeUnitRange: Range<Int>, baseLevel: UInt8) -> BidiParagraph? {
        let bufferRange = Range(uncheckedBounds: (0, buffer.length))
        let clampedRange = codeUnitRange.clamped(to: bufferRange)
        if clampedRange.isEmpty {
            return nil
        }

        let paragraphOffset = SBUInteger(codeUnitRange.lowerBound)
        let suggestedLength = SBUInteger(codeUnitRange.count)
        let inputLevel = SBLevel(baseLevel)
        let paragraph = SBAlgorithmCreateParagraph(algorithm, paragraphOffset, suggestedLength, inputLevel)

        return BidiParagraph(buffer: buffer, paragraph: paragraph!)
    }

    /// Creates a paragraph object processed with Unicode Bidirectional Algorithm.
    ///
    /// This method processes only first paragraph starting at `range.lowerBound` and ending at
    /// either `range.upperBound` or some character before it, in accordance with Rule P1 of Unicode
    /// Bidirectional Algorithm.
    ///
    /// The paragraph level is determined by applying Rules P2-P3 and embedding levels are resolved
    /// by applying Rules X1-I2.
    ///
    /// - Parameters:
    ///   - characterRange: The suggested range of the paragraph in source string.
    ///   - direction: The base direction of the paragraph.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(characterRange: Range<String.Index>, direction: BaseDirection) -> BidiParagraph? {
        return makeParagraph(characterRange: characterRange, baseLevel: direction.level)
    }

    /// Creates a paragraph object processed with Unicode Bidirectional Algorithm.
    ///
    /// This method processes only first paragraph starting at `range.lowerBound` and ending at
    /// either `range.upperBound` or some character before it, in accordance with Rule P1 of Unicode
    /// Bidirectional Algorithm.
    ///
    /// The paragraph level is overridden by `baseLevel` parameter and embedding levels are resolved
    /// by applying Rules X1-I2.
    ///
    /// - Parameters:
    ///   - characterRange: The suggested range of the paragraph in source string.
    ///   - baseLevel: Base level to override.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(characterRange: Range<String.Index>, baseLevel: UInt8) -> BidiParagraph? {
        if characterRange.isEmpty {
            return nil
        }

        let string = buffer.string
        let completeRange = Range(uncheckedBounds: (string.startIndex, string.endIndex))
        let clampedRange = characterRange.clamped(to: completeRange)
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: clampedRange)

        return makeParagraph(codeUnitRange: codeUnitRange, baseLevel: baseLevel)
    }
}
