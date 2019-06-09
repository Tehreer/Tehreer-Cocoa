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

public class Typesetter {
    let text: NSAttributedString
    let breaks: BreakClassifier
    let paragraphs: [BidiParagraph]
    let runs: [IntrinsicRun]

    public init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        let shapeResolver = ShapeResolver(text: text, defaultAttributes: defaultAttributes)
        let shapeResult = shapeResolver.makeParagraphsAndRuns()

        self.text = text
        self.breaks = BreakClassifier(string: text.string)
        self.paragraphs = shapeResult.paragraphs
        self.runs = shapeResult.runs
    }

    public func suggestForwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestForwardBreak(for: extent, in: range, with: mode)
    }

    public func suggestBackwardBreak(for extent: CGFloat, in range: Range<String.Index>, with mode: BreakMode) -> String.Index {
        let breakResolver = BreakResolver(string: text.string, paragraphs: paragraphs, runs: runs, breaks: breaks)
        return breakResolver.suggestBackwardBreak(for: extent, in: range, with: mode)
    }

    public func makeSimpleLine(range: Range<String.Index>) -> ComposedLine {
        let lineResolver = LineResolver(text: text, paragraphs: paragraphs, runs: runs)
        return lineResolver.makeSimpleLine(range: range)
    }
}
