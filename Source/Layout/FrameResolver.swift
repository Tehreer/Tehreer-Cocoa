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

/// This class resolves text frames by using a typesetter object. It is backed by the frame resolver
/// of Core, which gets every setting as it is set. It is a configuration object, so it must not be
/// used from several threads at a time.
public final class FrameResolver {
    private let core: TRFrameResolverRef

    /// The typesetter to use for resolving frames.
    public var typesetter: Typesetter! {
        didSet {
            TRFrameResolverSetTypesetter(core, typesetter?.core)
        }
    }

    /// A rectangle that specifies the frame bounds. Its default value is an infinite rectangle at
    /// zero origin.
    public var frameBounds: CGRect = .infinite {
        didSet {
            TRFrameResolverSetFrameSize(
                core,
                TRFloat(frameBounds.width),
                TRFloat(frameBounds.height)
            )
        }
    }

    /// A boolean value that indicates whether or not to tightly fit the lines horizontally in a
    /// frame. If enabled, the resulting frame will have a minimum width that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsHorizontally: Bool = false {
        didSet {
            TRFrameResolverSetFitsHorizontally(core, fitsHorizontally ? 1 : 0)
        }
    }

    /// A boolean value that indicates whether or not to tightly fit the lines vertically in a
    /// frame. If enabled, the resulting frame will have a minimum height that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsVertically: Bool = false {
        didSet {
            TRFrameResolverSetFitsVertically(core, fitsVertically ? 1 : 0)
        }
    }

    /// The text alignment to apply on each line of a frame. Its default value is `.leading`.
    public var textAlignment: TextAlignment = .leading {
        didSet {
            TRFrameResolverSetTextAlignment(core, textAlignment.coreValue)
        }
    }

    /// The vertical alignment to apply on the contents of a frame. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment = .top {
        didSet {
            TRFrameResolverSetVerticalAlignment(core, verticalAlignment.coreValue)
        }
    }

    /// The truncation mode to apply on the last line of a frame in case of overflow. Its default
    /// value is `.line`.
    public var truncationMode: BreakMode = .line {
        didSet {
            TRFrameResolverSetTruncationMode(core, truncationMode.coreValue)
        }
    }

    /// The truncation place for the last line of a frame. It takes effect only when the truncation
    /// is enabled. Its default value is `.end`.
    public var truncationPlace: TruncationPlace = .end {
        didSet {
            TRFrameResolverSetTruncationPlace(core, truncationPlace.coreValue)
        }
    }

    /// A boolean value that indicates whether or not to truncate the last line of a frame in case
    /// of overflow. Its default value is `false`.
    public var isTruncationEnabled: Bool = false {
        didSet {
            TRFrameResolverSetTruncationEnabled(core, isTruncationEnabled ? 1 : 0)
        }
    }

    /// A boolean value that indicates whether or not to justify the lines in a frame. Its default
    /// value is `false`.
    public var isJustificationEnabled: Bool = false {
        didSet {
            TRFrameResolverSetJustificationEnabled(core, isJustificationEnabled ? 1 : 0)
        }
    }

    /// The justification level which can range from `0.0` to `1.0`. A lower value increases the
    /// tightness between words while a higher value decreases it. Its default value is `1.0`.
    public var justificationLevel: CGFloat = 1.0 {
        didSet {
            TRFrameResolverSetJustificationLevel(core, TRFloat(justificationLevel))
        }
    }

    /// The maximum number of lines that a frame should consist of.
    public var maxLines: Int? = nil {
        didSet {
            TRFrameResolverSetMaxLines(core, TRUInteger(max(maxLines ?? 0, 0)))
        }
    }

    /// The extra spacing to add after each line of a frame. It is resolved before line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat = .zero {
        didSet {
            TRFrameResolverSetExtraLineSpacing(core, TRFloat(extraLineSpacing))
        }
    }

    /// The height multiplier to apply on each line of a frame. It is resolved after extra line
    /// spacing. Its default value is one.
    public var lineHeightMultiplier: CGFloat = 1.0 {
        didSet {
            TRFrameResolverSetLineHeightMultiplier(core, TRFloat(lineHeightMultiplier))
        }
    }

    /// Creates a frame resolver.
    public init() {
        core = TRFrameResolverCreate()!

        // Core has no getters, so it is told the defaults of the properties above.
        TRFrameResolverSetFrameSize(core, TRFloat(frameBounds.width), TRFloat(frameBounds.height))
        TRFrameResolverSetTextAlignment(core, textAlignment.coreValue)
        TRFrameResolverSetVerticalAlignment(core, verticalAlignment.coreValue)
        TRFrameResolverSetTruncationMode(core, truncationMode.coreValue)
        TRFrameResolverSetTruncationEnabled(core, 0)
        TRFrameResolverSetJustificationLevel(core, TRFloat(justificationLevel))
        TRFrameResolverSetExtraLineSpacing(core, TRFloat(extraLineSpacing))
        TRFrameResolverSetLineHeightMultiplier(core, TRFloat(lineHeightMultiplier))
    }

    deinit {
        TRFrameResolverRelease(core)
    }

    /// Creates a frame representing the specified UTF-16 range in source string.
    ///
    /// The resolver keeps on filling the frame until it either runs out of text or it finds that
    /// text no longer fits in frame bounds. The resulting frame consists of at least one line even
    /// if frame bounds are smaller.
    ///
    /// - Parameter codeUnitRange: The UTF-16 range of the frame in source string.
    /// - Returns: A new composed frame.
    public func makeFrame(codeUnitRange: Range<Int>) -> ComposedFrame? {
        guard let typesetter = typesetter else {
            return nil
        }

        let frame = TRFrameResolverCreateFrame(
            core,
            TRUInteger(codeUnitRange.lowerBound),
            TRUInteger(codeUnitRange.count)
        )

        guard let frame = frame else {
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
}
