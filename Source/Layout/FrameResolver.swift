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
/// of Core, which holds every setting. It is a configuration object, so it must not be
/// used from several threads at a time.
public final class FrameResolver {
    private let core: TRFrameResolverRef

    /// The typesetter to use for resolving frames.
    public var typesetter: Typesetter! {
        didSet {
            TRFrameResolverSetTypesetter(core, typesetter?.core)
        }
    }

    /// The width of the frame. Its default value is unbounded.
    public var frameWidth: CGFloat {
        get { CGFloat(TRFrameResolverGetFrameSize(core).width) }
        set {
            var size = TRFrameResolverGetFrameSize(core)
            size.width = TRFloat(newValue)
            TRFrameResolverSetFrameSize(core, size)
        }
    }

    /// The height of the frame. Its default value is unbounded.
    public var frameHeight: CGFloat {
        get { CGFloat(TRFrameResolverGetFrameSize(core).height) }
        set {
            var size = TRFrameResolverGetFrameSize(core)
            size.height = TRFloat(newValue)
            TRFrameResolverSetFrameSize(core, size)
        }
    }

    /// A boolean value that indicates whether or not to tightly fit the lines horizontally in a
    /// frame. If enabled, the resulting frame will have a minimum width that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsHorizontally: Bool {
        get { TRFrameResolverGetFitsHorizontally(core) != 0 }
        set { TRFrameResolverSetFitsHorizontally(core, newValue ? 1 : 0) }
    }

    /// A boolean value that indicates whether or not to tightly fit the lines vertically in a
    /// frame. If enabled, the resulting frame will have a minimum height that tightly encloses all
    /// the lines of specified text. Its default value is `false`.
    public var fitsVertically: Bool {
        get { TRFrameResolverGetFitsVertically(core) != 0 }
        set { TRFrameResolverSetFitsVertically(core, newValue ? 1 : 0) }
    }

    /// The text alignment to apply on each line of a frame. Its default value is `.leading`.
    public var textAlignment: TextAlignment {
        get { TextAlignment(coreValue: TRFrameResolverGetTextAlignment(core)) }
        set { TRFrameResolverSetTextAlignment(core, newValue.coreValue) }
    }

    /// The vertical alignment to apply on the contents of a frame. Its default value is `.top`.
    public var verticalAlignment: VerticalAlignment {
        get { VerticalAlignment(coreValue: TRFrameResolverGetVerticalAlignment(core)) }
        set { TRFrameResolverSetVerticalAlignment(core, newValue.coreValue) }
    }

    /// The truncation mode to apply on the last line of a frame in case of overflow. Its default
    /// value is `.line`.
    public var truncationMode: BreakMode {
        get { BreakMode(coreValue: TRFrameResolverGetTruncationMode(core)) }
        set { TRFrameResolverSetTruncationMode(core, newValue.coreValue) }
    }

    /// The truncation place for the last line of a frame. It takes effect only when the truncation
    /// is enabled. Its default value is `.end`.
    public var truncationPlace: TruncationPlace {
        get { TruncationPlace(coreValue: TRFrameResolverGetTruncationPlace(core)) }
        set { TRFrameResolverSetTruncationPlace(core, newValue.coreValue) }
    }

    /// A boolean value that indicates whether or not to truncate the last line of a frame in case
    /// of overflow. Its default value is `false`.
    public var isTruncationEnabled: Bool {
        get { TRFrameResolverIsTruncationEnabled(core) != 0 }
        set { TRFrameResolverSetTruncationEnabled(core, newValue ? 1 : 0) }
    }

    /// A boolean value that indicates whether or not to justify the lines in a frame. Its default
    /// value is `false`.
    public var isJustificationEnabled: Bool {
        get { TRFrameResolverIsJustificationEnabled(core) != 0 }
        set { TRFrameResolverSetJustificationEnabled(core, newValue ? 1 : 0) }
    }

    /// The justification level which can range from `0.0` to `1.0`. A lower value increases the
    /// tightness between words while a higher value decreases it. Its default value is `1.0`.
    public var justificationLevel: CGFloat {
        get { CGFloat(TRFrameResolverGetJustificationLevel(core)) }
        set { TRFrameResolverSetJustificationLevel(core, TRFloat(newValue)) }
    }

    /// The maximum number of lines that a frame should consist of. Its default value is `nil`,
    /// which means that the number of lines is not limited. A value must be at least one.
    public var maxLines: Int? {
        get {
            let count = TRFrameResolverGetMaxLines(core)

            return (count == 0 ? nil : Int(count))
        }
        set {
            if let lineCount = newValue {
                precondition(lineCount >= 1, "The maximum number of lines is less than one")
            }

            TRFrameResolverSetMaxLines(core, TRUInteger(newValue ?? 0))
        }
    }

    /// The extra spacing to add after each line of a frame. It is resolved after line height
    /// multiplier. Its default value is zero.
    public var extraLineSpacing: CGFloat {
        get { CGFloat(TRFrameResolverGetExtraLineSpacing(core)) }
        set { TRFrameResolverSetExtraLineSpacing(core, TRFloat(newValue)) }
    }

    /// The height multiplier to apply on each line of a frame. It is resolved before extra line
    /// spacing, and it is ignored if it is not positive. Its default value is one.
    public var lineHeightMultiplier: CGFloat {
        get { CGFloat(TRFrameResolverGetLineHeightMultiplier(core)) }
        set { TRFrameResolverSetLineHeightMultiplier(core, TRFloat(newValue)) }
    }

    /// Creates a frame resolver.
    public init() {
        core = TRFrameResolverCreate()!
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
