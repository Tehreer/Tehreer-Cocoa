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

public class GlyphRun {
    public let startIndex: String.Index
    public let endIndex: String.Index
    public let startExtraLength: Int
    public let endExtraLength: Int
    public let isBackward: Bool
    public let bidiLevel: UInt8
    public let writingDirection: WritingDirection
    public let typeface: Typeface
    public let typeSize: CGFloat
    public let ascent: CGFloat
    public let descent: CGFloat
    public let leading: CGFloat
    public let glyphIDs: PrimitiveCollection<UInt16>
    public let glyphOffsets: PrimitiveCollection<CGPoint>
    public let glyphAdvances: PrimitiveCollection<CGFloat>
    public let clusterMap: PrimitiveCollection<Int>
    public let caretEdges: PrimitiveCollection<CGFloat>

    private(set) var extent: CGFloat = -.infinity

    init(string: String, startIndex: String.Index, endIndex: String.Index,
         startExtraLength: Int, endExtraLength: Int, isBackward: Bool,
         bidiLevel: UInt8, writingDirection: WritingDirection, typeface: Typeface,
         typeSize: CGFloat, ascent: CGFloat, descent: CGFloat, leading: CGFloat,
         glyphIDs: PrimitiveCollection<UInt16>, glyphOffsets: PrimitiveCollection<CGPoint>,
         glyphAdvances: PrimitiveCollection<CGFloat>,
         clusterMap: PrimitiveCollection<Int>, caretEdges: PrimitiveCollection<CGFloat>) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.startExtraLength = startExtraLength
        self.endExtraLength = endExtraLength
        self.isBackward = isBackward
        self.bidiLevel = bidiLevel
        self.writingDirection = writingDirection
        self.typeface = typeface
        self.typeSize = typeSize
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.glyphIDs = glyphIDs
        self.glyphOffsets = glyphOffsets
        self.glyphAdvances = glyphAdvances
        self.clusterMap = clusterMap
        self.caretEdges = caretEdges
    }

    public internal(set) var origin: CGPoint = .zero

    private var isRTL: Bool {
        return (bidiLevel & 1) == 1
    }

    private var glyphCount: Int {
        return glyphIDs.count
    }

    public var height: CGFloat {
        return ascent + descent + leading
    }
}
