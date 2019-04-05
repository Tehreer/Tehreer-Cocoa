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
/// A `BidiAlgorithm` object provides information related to individual paragraphs in source text by
/// applying rule P1. It can be used to create paragraph objects by explicitly specifying the
/// paragraph level or deriving it from rules P2 and P3. Once a paragraph object is created,
/// embedding levels of characters can be queried from it.
public class BidiAlgorithm {
    /// Maximum explicit embedding level.
    public static let maxLevel: UInt8 = 125

    private let buffer: BidiBuffer
    private let algorithm: SBAlgorithmRef

    /// Creates a bidi algorithm object for the given text.
    ///
    /// - Parameter text: The text to apply unicode bidirectional algorithm on.
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

    /// Returns the boundary of the first paragraph within the specified range.
    ///
    /// The boundary of the paragraph occurs after a character whose bidirectional type is Paragraph
    /// Separator (B), or the `range.upperLimit` if no such character exists before it. The
    /// exception to this rule is when a Carriage Return (CR) is followed by a Line Feed (LF). Both
    /// CR and LF are paragraph separators, but in that case, the boundary of the paragraph is
    /// considered after LF character.
    ///
    /// - Parameter range: The suggested range of the paragraph in source text.
    /// - Returns: The boundary of the first paragraph within the specified range.
    public func paragraphBoundary(in range: Range<String.Index>) -> String.Index {
        let string = buffer.string
        let utf16Range: NSRange = string.utf16Range(forCharacterRange: range)
        let paragraphOffset = SBUInteger(utf16Range.location)
        let suggestedLength = SBUInteger(utf16Range.length)
        var actualLength: SBUInteger = 0

        SBAlgorithmGetParagraphBoundary(algorithm,
                                        paragraphOffset, suggestedLength,
                                        &actualLength, nil)

        return string.characterIndex(forUTF16Index: Int(paragraphOffset + actualLength))
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
    ///   - range: The suggested range of the paragraph in source text.
    ///   - direction: The base direction of the paragraph.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(range: Range<String.Index>, direction: BaseDirection) -> BidiParagraph? {
        return makeParagraph(range: range, baseLevel: direction.level)
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
    ///   - range: The suggested range of the paragraph in source text.
    ///   - baseLevel: Base level to override.
    /// - Returns: A paragraph object processed with Unicode Bidirectional Algorithm.
    public func makeParagraph(range: Range<String.Index>, baseLevel: UInt8) -> BidiParagraph? {
        let string = buffer.string
        let clampedRange = range.clamped(to: string.startIndex ..< string.endIndex)
        if clampedRange.isEmpty {
            return nil
        }

        let utf16Range: NSRange = string.utf16Range(forCharacterRange: clampedRange)
        let paragraphOffset = SBUInteger(utf16Range.location)
        let suggestedLength = SBUInteger(utf16Range.length)
        let inputLevel = SBLevel(baseLevel)
        let paragraph = SBAlgorithmCreateParagraph(algorithm, paragraphOffset, suggestedLength, inputLevel)

        return BidiParagraph(buffer: buffer, paragraph: paragraph!)
    }
}
