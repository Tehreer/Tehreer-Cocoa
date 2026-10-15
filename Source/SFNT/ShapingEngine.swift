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

/// The `ShapingEngine` class represents text shaping engine.
public final class ShapingEngine {
    private let core: TRShapingEngineRef

    // Core does not retain the typeface for the caller, so the engine keeps it alive.
    private var currentTypeface: Typeface?

    // Core keeps a copy of the features, but they are read back as a dictionary only on demand.
    private var currentOpenTypeFeatures: [SFNTTag: Int] = [:]

    /// Creates a shaping engine.
    public init() {
        core = TRShapingEngineCreate()
    }

    deinit {
        TRShapingEngineRelease(core)
    }

    /// Returns the default writing direction of a script.
    ///
    /// - Parameter scriptTag: The tag of the script whose default direction is returned.
    /// - Returns: The default writing direction of the script identified by `scriptTag`.
    public static func defaultDirectionForScript(_ scriptTag: SFNTTag) -> WritingDirection {
        return WritingDirection(coreValue: TRShapingEngineGetScriptDefaultDirection(scriptTag.rawValue))
    }

    /// Returns the OpenType tag of a language that is given by its name.
    ///
    /// - Parameter languageName: The name of the language in the form of BCP 47, e.g. `ur-PK`.
    /// - Returns: The tag of the language, e.g. `URD `, or `dflt`, which is the default language, if
    ///            the name has no tag.
    public static func languageTag(forName languageName: String) -> SFNTTag {
        return SFNTTag(rawValue: TRShapingEngineGetLanguageTagForName(languageName))!
    }

    /// The typeface which this shaping engine will use for shaping text.
    public var typeface: Typeface! {
        get { return currentTypeface }
        set {
            currentTypeface = newValue
            TRShapingEngineSetTypeface(core, newValue?.core)
        }
    }

    /// The type size which this shaping engine will use for shaping text.
    public var typeSize: CGFloat {
        get { return CGFloat(TRShapingEngineGetTypeSize(core)) }
        set { TRShapingEngineSetTypeSize(core, TRFloat(newValue)) }
    }

    /// The script tag which this shaping engine will use for shaping text. Its default value is
    /// `DFLT`.
    public var scriptTag: SFNTTag {
        get { return SFNTTag(rawValue: TRShapingEngineGetScriptTag(core))! }
        set { TRShapingEngineSetScriptTag(core, newValue.rawValue) }
    }

    /// The language tag which this shaping engine will use for shaping text. Its default value is
    /// `dflt`.
    public var languageTag: SFNTTag {
        get { return SFNTTag(rawValue: TRShapingEngineGetLanguageTag(core))! }
        set { TRShapingEngineSetLanguageTag(core, newValue.rawValue) }
    }

    /// The user-specified open type feature settings.
    ///
    /// If the value of a feature is set to zero, it would be disabled provided that it is not a
    /// required feature of the chosen script. If the value of a feature is greater than zero, it
    /// would be enabled. In case of an alternate feature, this value would be used to pick the
    /// alternate glyph at this position.
    public var openTypeFeatures: [SFNTTag: Int] {
        get { return currentOpenTypeFeatures }
        set {
            currentOpenTypeFeatures = newValue

            let features = newValue.map { (key, value) in
                TROpenTypeFeature(tag: key.rawValue, value: UInt32(max(value, 0)))
            }

            _ = TRShapingEngineSetOpenTypeFeatures(core, features, TRUInteger(features.count))
        }
    }

    /// The direction in which this shaping engine will place the resultant glyphs. Its default
    /// value is `.leftToRight`.
    ///
    /// The value of writing direction must reflect the rendering direction of source script so that
    /// cursive and mark glyphs are placed at appropriate locations. It should not be confused with
    /// the direction of a bidirectional run as that may not reflect the script direction if
    /// overridden explicitly.
    public var writingDirection: WritingDirection {
        get { return WritingDirection(coreValue: TRShapingEngineGetWritingDirection(core)) }
        set { TRShapingEngineSetWritingDirection(core, newValue.coreValue) }
    }

    /// The order in which this shaping engine will process the text. Its default value is
    /// `.forward`.
    ///
    /// This method provides a convenient way to shape a bidirectional run whose direction is
    /// opposite to that of script. For example, if the direction of a run, 'car' is explicitly set
    /// as right-to-left, backward order will automatically read it as 'rac' without reordering the
    /// original text.
    public var shapingOrder: ShapingOrder {
        get { return ShapingOrder(coreValue: TRShapingEngineGetShapingOrder(core)) }
        set { TRShapingEngineSetShapingOrder(core, newValue.coreValue) }
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
        guard currentTypeface != nil else {
            fatalError("Typeface was not set")
        }

        let characterRange = string.characterRange(forUTF16Range: codeUnitRange)
        let codeUnits = Array(string[characterRange].utf16)

        let result = codeUnits.withUnsafeBufferPointer { (pointer) in
            TRShapingEngineCreateShapingResult(
                core,
                pointer.baseAddress,
                TRUInteger(pointer.count),
                TRStringEncoding(TRStringEncodingUTF16)
            )
        }

        guard let result = result else {
            fatalError("Could not shape the text")
        }

        return ShapingResult(core: result, string: string, codeUnitRange: codeUnitRange)
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
