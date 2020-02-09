//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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
    var codeUnitRange: Range<Int>
    var typeface: Typeface!
    var typeSize: CGFloat = 16
    var baselineOffset: CGFloat = .zero
    var obliqueness: CGFloat = .zero
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    init(codeUnitRange: Range<Int>) {
        self.codeUnitRange = codeUnitRange
    }
}

struct ShapingRunLocator {
    let text: NSAttributedString

    private let string: String
    private var chunkRange: Range<Int>
    private var initialRun: ShapingRun
    private var newRun: ShapingRun!

    init(text: NSAttributedString, defaultAttributes: [NSAttributedString.Key: Any]) {
        self.text = text
        self.string = text.string
        self.chunkRange = Range(uncheckedBounds: (0, string.utf16.count)) 
        self.initialRun = ShapingRun(codeUnitRange: chunkRange)

        resolveAttributes(shapingRun: &initialRun, attributes: defaultAttributes)
    }

    private mutating func resolveRun() -> ShapingRun? {
        if !chunkRange.isEmpty {
            var runRange = NSRange(chunkRange)
            let attributes = text.attributes(at: runRange.location,
                                             longestEffectiveRange: &runRange,
                                             in: runRange)

            var shapingRun = initialRun
            shapingRun.codeUnitRange = chunkRange

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
                if let number = value as? NSNumber, let typeSize = CGFloat(exactly: number) {
                    shapingRun.typeSize = typeSize
                }
            case .scaleX:
                if let number = value as? NSNumber, let scaleX = CGFloat(exactly: number) {
                    shapingRun.scaleX = scaleX
                }
            case .scaleY:
                if let number = value as? NSNumber, let scaleY = CGFloat(exactly: number) {
                    shapingRun.scaleY = scaleY
                }
            case .baselineOffset:
                if let number = value as? NSNumber, let baselineOffset = CGFloat(exactly: number) {
                    shapingRun.baselineOffset = baselineOffset
                }
            case .obliqueness:
                if let number = value as? NSNumber, let obliqueness = CGFloat(exactly: number) {
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

    mutating func reset(for codeUnitRange: Range<Int>) {
        self.chunkRange = codeUnitRange
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
                    && currentRun.obliqueness == nextRun.obliqueness
                    && currentRun.scaleX == nextRun.scaleX
                    && currentRun.scaleY == nextRun.scaleY {
                    let startIndex = currentRun.codeUnitRange.lowerBound
                    let endIndex = nextRun.codeUnitRange.upperBound
                    currentRun.codeUnitRange = Range(uncheckedBounds: (startIndex, endIndex))
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
