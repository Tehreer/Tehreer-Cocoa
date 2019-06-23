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

struct ShapingRun {
    var startIndex: String.Index
    var endIndex: String.Index

    var typeface: Typeface!
    var typeSize: CGFloat = 16
    var baselineOffset: CGFloat = .zero
    var obliqueness: CGFloat = .zero

    init(startIndex: String.Index, endIndex: String.Index) {
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

struct ShapingRunLocator {
    let text: NSAttributedString

    private let string: String
    private var chunkRange: Range<String.Index>
    private var initialRun: ShapingRun
    private var newRun: ShapingRun!

    init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        self.text = text
        self.string = text.string
        self.chunkRange = string.startIndex ..< string.endIndex
        self.initialRun = ShapingRun(startIndex: string.startIndex, endIndex: string.endIndex)

        resolveAttributes(shapingRun: &initialRun, attributes: defaultAttributes)
    }

    private mutating func resolveRun() -> ShapingRun? {
        if !chunkRange.isEmpty {
            var utf16Range: NSRange = string.utf16Range(forCharacterRange: chunkRange)
            let attributes = text.attributes(at: utf16Range.location,
                                             longestEffectiveRange: &utf16Range,
                                             in: utf16Range)

            let runRange = string.characterRange(forUTF16Range: utf16Range)

            var shapingRun = initialRun
            shapingRun.startIndex = runRange.lowerBound
            shapingRun.endIndex = runRange.upperBound

            resolveAttributes(shapingRun: &shapingRun, attributes: attributes)

            chunkRange = runRange.upperBound ..< chunkRange.upperBound

            return shapingRun
        }

        newRun = nil
        return nil
    }

    private func resolveAttributes(shapingRun: inout ShapingRun,
                                   attributes: [NSAttributedString.Key: Any]) {
        for (key, value) in attributes {
            switch key {
            case .typeface:
                if let typeface = value as? Typeface {
                    shapingRun.typeface = typeface
                }
            case .typeSize:
                if let typeSize = value as? CGFloat {
                    shapingRun.typeSize = typeSize
                }
            case .baselineOffset:
                if let baselineOffset = value as? CGFloat {
                    shapingRun.baselineOffset = baselineOffset
                }
            case .obliqueness:
                if let obliqueness = value as? CGFloat {
                    shapingRun.obliqueness = obliqueness
                }
            default:
                break
            }
        }

        if shapingRun.typeSize < 0.0 {
            shapingRun.typeSize = 0.0
        }
    }

    mutating func reset(for range: Range<String.Index>) {
        self.chunkRange = range
        self.newRun = resolveRun()
    }

    mutating func next() -> ShapingRun? {
        if let nextRun = newRun {
            var currentRun = nextRun

            // Merge runs of similar style.
            while let nextRun = resolveRun() {
                if currentRun.typeface === nextRun.typeface
                    && currentRun.typeSize == nextRun.typeSize
                    && currentRun.baselineOffset == nextRun.baselineOffset
                    && currentRun.obliqueness == nextRun.obliqueness {
                    currentRun.endIndex = nextRun.endIndex
                } else {
                    break
                }

                newRun = nextRun
            }

            return currentRun
        }

        return nil
    }
}
