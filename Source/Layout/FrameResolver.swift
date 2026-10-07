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
import UIKit

/// This class resolves text frames by using a typesetter object.
public final class FrameResolver {
    /// The typesetter to use for resolving frames.
    public var typesetter: Typesetter!

    /// A rectangle that specifies the frame bounds. Its default value is an infinite rectangle at
    /// zero origin.
    public var frameBounds: CGRect = .infinite

    /// A boolean value that indicates whether or not to tightly fit the lines horizontally in a
    /// frame. If enabled, the resulting frame will have a minimum width that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsHorizontally: Bool = false

    /// A boolean value that indicates whether or not to tightly fit the lines vertically in a
    /// frame. If enabled, the resulting frame will have a minimum height that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsVertically: Bool = false

    /// The text alignment to apply on each line of a frame. Its default value is `.leading`.
    public var textAlignment: TextAlignment = .leading

    /// The vertical alignment to apply on the contents of a frame. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment = .top

    /// The truncation mode to apply on the last line of a frame in case of overflow. Its default
    /// value is `.line`.
    public var truncationMode: BreakMode = .line

    /// The truncation place for the last line of a frame. The truncation is disabled if its value
    /// is `nil`.
    public var truncationPlace: TruncationPlace? = nil

    /// A boolean value that indicates whether or not to justify the lines in a frame. Its default
    /// value is `false`.
    public var isJustificationEnabled: Bool = false

    /// The justification level which can range from `0.0` to `1.0`. A lower value increases the
    /// tightness between words while a higher value decreases it. Its default value is `1.0`.
    public var justificationLevel: CGFloat = 1.0

    /// The maximum number of lines that a frame should consist of.
    public var maxLines: Int? = nil

    /// The extra spacing to add after each line of a frame. It is resolved before line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat = .zero

    /// The height multiplier to apply on each line of a frame. It is resolved after extra line
    /// spacing. Its default value is one.
    public var lineHeightMultiplier: CGFloat = 1.0

    public init() { }

    /// Creates a frame representing the specified UTF-16 range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter codeUnitRange: The UTF-16 range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(codeUnitRange: Range<Int>) -> ComposedFrame? {
        guard let typesetter = typesetter, let resolver = TRFrameResolverCreate() else {
            return nil
        }
        defer { TRFrameResolverRelease(resolver) }

        TRFrameResolverSetTypesetter(resolver, typesetter.core)
        TRFrameResolverSetFrameSize(resolver, TRFloat(frameBounds.width), TRFloat(frameBounds.height))
        TRFrameResolverSetFitsHorizontally(resolver, fitsHorizontally ? 1 : 0)
        TRFrameResolverSetFitsVertically(resolver, fitsVertically ? 1 : 0)
        TRFrameResolverSetTextAlignment(resolver, textAlignmentValue)
        TRFrameResolverSetVerticalAlignment(resolver, verticalAlignmentValue)
        TRFrameResolverSetTruncationMode(resolver, truncationModeValue)
        TRFrameResolverSetJustificationEnabled(resolver, isJustificationEnabled ? 1 : 0)
        TRFrameResolverSetJustificationLevel(resolver, TRFloat(justificationLevel))
        TRFrameResolverSetMaxLines(resolver, TRUInteger(max(maxLines ?? 0, 0)))
        TRFrameResolverSetExtraLineSpacing(resolver, TRFloat(extraLineSpacing))
        TRFrameResolverSetLineHeightMultiplier(resolver, TRFloat(lineHeightMultiplier))

        if let truncationPlace = truncationPlace {
            TRFrameResolverSetTruncationPlace(resolver, truncationPlaceValue(truncationPlace))
        } else {
            TRFrameResolverDisableTruncation(resolver)
        }

        let range = TRRange(index: TRUInteger(codeUnitRange.lowerBound),
                            length: TRUInteger(codeUnitRange.count))

        guard let frame = TRFrameResolverCreateFrame(resolver, range) else {
            return nil
        }

        return ComposedFrame(core: frame, string: typesetter.text.string, objects: typesetter.objects)
    }

    /// Creates a frame representing the specified character range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter characterRange: The character range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(characterRange: Range<String.Index>) -> ComposedFrame? {
        let string = typesetter.text.string
        let codeUnitRange: Range<Int> = string.utf16Range(forCharacterRange: characterRange)

        return makeFrame(codeUnitRange: codeUnitRange)
    }

    private var textAlignmentValue: TRTextAlignment {
        switch textAlignment {
        case .left:
            return TRTextAlignment(TRTextAlignmentLeft)
        case .center:
            return TRTextAlignment(TRTextAlignmentCenter)
        case .right:
            return TRTextAlignment(TRTextAlignmentRight)
        case .leading:
            return TRTextAlignment(TRTextAlignmentLeading)
        case .trailing:
            return TRTextAlignment(TRTextAlignmentTrailing)
        }
    }

    private var verticalAlignmentValue: TRVerticalAlignment {
        switch verticalAlignment {
        case .top:
            return TRVerticalAlignment(TRVerticalAlignmentTop)
        case .middle:
            return TRVerticalAlignment(TRVerticalAlignmentCenter)
        case .bottom:
            return TRVerticalAlignment(TRVerticalAlignmentBottom)
        }
    }

    private var truncationModeValue: TRBreakMode {
        switch truncationMode {
        case .character:
            return TRBreakMode(TRBreakModeCharacter)
        case .line:
            return TRBreakMode(TRBreakModeLine)
        }
    }

    private func truncationPlaceValue(_ place: TruncationPlace) -> TRTruncationPlace {
        switch place {
        case .start:
            return TRTruncationPlace(TRTruncationPlaceStart)
        case .middle:
            return TRTruncationPlace(TRTruncationPlaceMiddle)
        case .end:
            return TRTruncationPlace(TRTruncationPlaceEnd)
        }
    }
}
