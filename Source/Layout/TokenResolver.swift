//
// Copyright (C) 2020 Muhammad Tayyab Akram
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

struct TokenResolver {
    let string: String
    let runs: [IntrinsicRun]

    func makeTokenLine(range: Range<String.Index>,
                       truncationPlace: TruncationPlace,
                       tokenString: String?) -> ComposedLine {
        var truncationIndex: String.Index

        switch truncationPlace {
        case .start:
            truncationIndex = range.lowerBound
        case .middle:
            let count = string.distance(from: range.lowerBound, to: range.upperBound)
            truncationIndex = string.index(range.lowerBound, offsetBy: count / 2)
        case .end:
            truncationIndex = string.index(before: range.upperBound)
        }

        let runIndex = runs.binarySearchIndex(ofCharacterAt: truncationIndex)
        let suitableRun = runs[runIndex]
        let tokenTypeface = suitableRun.typeface
        let tokenTypeSize = suitableRun.typeSize
        var ellipsisStr = tokenString ?? ""

        if ellipsisStr.isEmpty {
            // Token string is not given. Use ellipsis character if available; fallback to three
            // dot characters.

            let ellipsisGlyphId = tokenTypeface.glyphID(forCodePoint: 0x2026)
            if ellipsisGlyphId == 0 {
                ellipsisStr = "..."
            } else {
                ellipsisStr = "\u{2026}"
            }
        }

        let typesetter = Typesetter(text: NSAttributedString(string: ellipsisStr),
                                    defaultAttributes: [
                                        .typeface: tokenTypeface,
                                        .typeSize: tokenTypeSize])
        let ellipsisRange = ellipsisStr.startIndex ..< ellipsisStr.endIndex

        return typesetter.makeSimpleLine(characterRange: ellipsisRange)
    }
}
