//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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
import HarfBuzz

/// The `ShapingEngine` class represents text shaping engine.
public class ShapingEngine {
    /// Creates a shaping engine.
    public init() { }

    /// Returns the default writing direction of a script.
    ///
    /// - Parameter scriptTag: The tag of the script whose default direction is returned.
    /// - Returns: The default writing direction of the script identified by `scriptTag`.
    public static func defaultDirectionForScript(_ scriptTag: SFNTTag) -> WritingDirection {
        let script = hb_ot_tag_to_script(scriptTag.rawValue)
        let direction = hb_script_get_horizontal_direction(script)

        switch direction {
        case HB_DIRECTION_RTL:
            return .rightToLeft
        default:
            return .leftToRight
        }
    }

    /// The typeface which this shaping engine will use for shaping text.
    public var typeface: Typeface! = nil

    /// The type size which this shaping engine will use for shaping text.
    public var typeSize: CGFloat = 16

    /// The script tag which this shaping engine will use for shaping text. Its default value is
    /// `DFLT`.
    public var scriptTag: SFNTTag = "DFLT"

    /// The language tag which this shaping engine will use for shaping text. Its default value is
    /// `dflt`.
    public var languageTag: SFNTTag = "dflt"

    /// The user-specified open type feature settings.
    ///
    /// If the value of a feature is set to zero, it would be disabled provided that it is not a
    /// required feature of the chosen script. If the value of a feature is greater than zero, it
    /// would be enabled. In case of an alternate feature, this value would be used to pick the
    /// alternate glyph at this position.
    public var openTypeFeatures: [SFNTTag: Int] = [:]

    /// The direction in which this shaping engine will place the resultant glyphs. Its default
    /// value is `.leftToRight`.
    ///
    /// The value of writing direction must reflect the rendering direction of source script so that
    /// cursive and mark glyphs are placed at appropriate locations. It should not be confused with
    /// the direction of a bidirectional run as that may not reflect the script direction if
    /// overridden explicitly.
    public var writingDirection = WritingDirection.leftToRight

    /// The order in which this shaping engine will process the text. Its default value is
    /// `.forward`.
    ///
    /// This method provides a convenient way to shape a bidirectional run whose direction is
    /// opposite to that of script. For example, if the direction of a run, 'car' is explicitly set
    /// as right-to-left, backward order will automatically read it as 'rac' without reordering the
    /// original text.
    public var shapingOrder = ShapingOrder.forward

    private func isRTL() -> Bool {
        if (shapingOrder == .backward) {
            return writingDirection != .rightToLeft
        }

        return writingDirection == .rightToLeft
    }

    /// Shapes the specified UTF-16 range of text into glyphs.
    ///
    /// The output glyphs in the `ShapingResult` object flow visually in writing direction. For
    /// left-to-right direction, the position of pen is incremented with glyph's advance after
    /// rendering it. Similarly, for right-to-left direction, the position of pen is decremented
    /// with glyph's advance after rendering it.
    ///
    /// - Parameters:
    ///   - string: The text to shape into glyphs.
    ///   - codeUnitRange: The UTF-16 range of text to be shaped.
    /// - Returns: A new `ShapingResult` object.
    public func shape(string: String, codeUnitRange: Range<Int>) -> ShapingResult {
        guard typeface != nil else {
            fatalError("Typeface was not set")
        }

        let shapingResult = ShapingResult()

        let script = hb_ot_tag_to_script(scriptTag.rawValue)
        let language = hb_ot_tag_to_language(languageTag.rawValue)
        let direction: hb_direction_t

        switch (writingDirection) {
        case .leftToRight:
            direction = HB_DIRECTION_LTR

        case .rightToLeft:
            direction = HB_DIRECTION_RTL
        }

        let buffer = shapingResult.hbBuffer
        hb_buffer_clear_contents(buffer)
        hb_buffer_set_script(buffer, script)
        hb_buffer_set_language(buffer, language)
        hb_buffer_set_direction(buffer, direction)

        let characterRange = string.characterRange(forUTF16Range: codeUnitRange)
        var codeUnits = Array(string[characterRange].utf16)
        let length = codeUnits.count

        codeUnits.withUnsafeMutableBufferPointer { (pointer) -> Void in
            hb_buffer_add_utf16(buffer, pointer.baseAddress, Int32(length), 0, Int32(length))
        }

        let features = openTypeFeatures.map { (key, value) in
            hb_feature_t(tag: key.rawValue, value: UInt32(value), start: 0, end: UInt32(length))
        }

        typeface.withFreeTypeFace { (ftFace) in
            FT_Set_Char_Size(ftFace, 0, typeface.unitsPerEm, 0, 0)

            features.withUnsafeBufferPointer { (pointer) in
                hb_shape(typeface.hbFont, buffer, pointer.baseAddress, UInt32(pointer.count))
            }
        }

        shapingResult.setup(string: string,
                            codeUnitRange: codeUnitRange,
                            isBackward: shapingOrder == .backward,
                            isRTL: isRTL(),
                            sizeByEm: typeSize / CGFloat(typeface.unitsPerEm))

        return shapingResult
    }

    /// Shapes the specified range of text into glyphs.
    ///
    /// The output glyphs in the `ShapingResult` object flow visually in writing direction. For
    /// left-to-right direction, the position of pen is incremented with glyph's advance after
    /// rendering it. Similarly, for right-to-left direction, the position of pen is decremented
    /// with glyph's advance after rendering it.
    ///
    /// - Parameters:
    ///   - string: The text to shape into glyphs.
    ///   - characterRange: The character range of text to be shaped.
    /// - Returns: A new `ShapingResult` object.
    public func shape(string: String, characterRange: Range<String.Index>) -> ShapingResult {
        shape(string: string, codeUnitRange: string.utf16Range(forCharacterRange: characterRange))
    }
}

