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

import CoreGraphics
import Foundation

/// Represents a typesetter which performs text layout. It can be used to create lines, perform line
/// breaking, and do other contextual analysis based on the characters in the string.
public class Typesetter {
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
    /// proceeds from first character to last character. If there is still room after measuring all
    /// characters, then last index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - extent: The requested break extent.
    ///   - range: The string range for break calculations.
    ///   - mode: The requested break mode.
    /// - Returns: The index (exclusive) that would cause the break.
    public func suggestForwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestForwardBreak(for: extent, in: range, with: mode)
    }

    /// Suggests a backward break index based on the specified range and the extent. The measurement
    /// proceeds from last character to first character. If there is still room after measuring all
    /// characters, then start index is returned. Otherwise, break index is returned.
    ///
    /// - Parameters:
    ///   - extent: The requested break extent.
    ///   - range: The string range for break calculations.
    ///   - mode: The requested break mode.
    /// - Returns: The index (inclusive) that would cause the break.
    public func suggestBackwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestBackwardBreak(for: extent, in: range, with: mode)
    }

    /// Creates a simple line having the specified string range.
    ///
    /// - Parameter range: The range of the line in source string.
    /// - Returns: The new line.
    public func makeSimpleLine(range: Range<String.Index>) -> ComposedLine {
        let lineResolver = LineResolver(text: text, defaultAttributes: defaultAttributes, paragraphs: paragraphs, runs: runs)
        return lineResolver.makeSimpleLine(range: range)
    }
}
