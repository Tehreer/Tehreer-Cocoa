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
import SheenFigure

/// The `ShapingEngine` class represents text shaping engine.
public class ShapingEngine {
    let sfArtist: SFArtistRef
    let sfScheme: SFSchemeRef

    private var featureTags: [SFUInt32] = []
    private var featureValues: [SFUInt16] = []

    /// Creates a shaping engine.
    public init() {
        sfArtist = SFArtistCreate()
        sfScheme = SFSchemeCreate()
    }

    deinit {
        SFArtistRelease(sfArtist)
        SFSchemeRelease(sfScheme)
    }

    /// Returns the default writing direction of a script.
    ///
    /// - Parameter scriptTag: The tag of the script whose default direction is returned.
    /// - Returns: The default writing direction of the script identified by `scriptTag`.
    public static func defaultDirectionForScript(_ scriptTag: SFNTTag) -> WritingDirection {
        return WritingDirection(rawValue: Int(SFScriptGetDefaultDirection(scriptTag.rawValue))) ?? .leftToRight
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
    public var openTypeFeatures: [SFNTTag: Int] = [:] {
        didSet {
            featureTags = openTypeFeatures.keys.map { SFUInt32($0.rawValue) }
            featureValues = openTypeFeatures.values.map { SFUInt16($0) }
        }
    }

    /// The direction in which this shaping engine will place the resultant glyphs. Its default
    /// value is `.leftToRight`.
    ///
    /// The value of writing direction must reflect the rendering direction of source script so that
    /// cursive and mark glyphs are placed at appropriate locations. It should not be confused with
    /// the direction of a bidirectional run as that may not reflect the script direction if
    /// overridden explicitly.
    public var writingDirection = WritingDirection.leftToRight {
        didSet {
            SFArtistSetTextDirection(sfArtist, SFTextDirection(writingDirection.rawValue))
        }
    }

    /// The order in which this shaping engine will process the text. Its default value is
    /// `.forward`.
    ///
    /// This method provides a convenient way to shape a bidirectional run whose direction is
    /// opposite to that of script. For example, if the direction of a run, 'car' is explicitly set
    /// as right-to-left, backward order will automatically read it as 'rac' without reordering the
    /// original text.
    public var shapingOrder = ShapingOrder.forward {
        didSet {
            SFArtistSetTextMode(sfArtist, SFTextMode(shapingOrder.rawValue))
        }
    }

    /// Shapes the specified UTF-16 range of text into glyphs.
    ///
    /// The output glyphs in the `ShapingResult` object flow visually in writing direction. For
    /// left-to-right direction, the position of pen is incremented with glyph's advance after
    /// rendering it. Similarly, for right-to-left direction, the position of pen is decremented
    /// with glyph's advance after rendering it.
    ///
    /// - Parameters:
    ///   - text: The text to shape into glyphs.
    ///   - codeUnitRange: The UTF-16 range of text to be shaped.
    /// - Returns: A new `ShapingResult` object.
    public func shape(text: String, codeUnitRange: Range<Int>) -> ShapingResult {
        guard typeface != nil else {
            fatalError("Typeface was not set")
        }

        let shapingResult = ShapingResult()

        let cache = typeface.patternCache
        let key = PatternKey(scriptTag: scriptTag, languageTag: languageTag,
                             featureTags: featureTags, featureValues: featureValues)
        var pattern = cache[key]

        if pattern == nil {
            SFSchemeSetFont(sfScheme, typeface.sfFont)
            SFSchemeSetScriptTag(sfScheme, scriptTag.rawValue)
            SFSchemeSetLanguageTag(sfScheme, languageTag.rawValue)
            SFSchemeSetFeatureValues(sfScheme, &featureTags, &featureValues, SFUInteger(featureTags.count))

            pattern = SFSchemeBuildPattern(sfScheme)
            cache[key] = pattern

            SFPatternRelease(pattern)
        }

        let characterRange = text.characterRange(forUTF16Range: codeUnitRange)
        var codeUnits = Array(text[characterRange].utf16)
        let length = SFUInteger(codeUnits.count)

        codeUnits.withUnsafeMutableBufferPointer { (pointer) -> Void in
            let encoding = SFStringEncoding(SFStringEncodingUTF16)
            let buffer = UnsafeMutableRawPointer(pointer.baseAddress!)

            SFArtistSetPattern(sfArtist, pattern)
            SFArtistSetString(sfArtist, encoding, buffer, length)
            SFArtistFillAlbum(sfArtist, shapingResult.sfAlbum)
        }

        shapingResult.setup(string: text,
                            codeUnitRange: codeUnitRange,
                            isBackward: shapingOrder == .backward,
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
    ///   - text: The text to shape into glyphs.
    ///   - characterRange: The character range of text to be shaped.
    /// - Returns: A new `ShapingResult` object.
    public func shape(text: String, characterRange: Range<String.Index>) -> ShapingResult {
        shape(text: text, codeUnitRange: text.utf16Range(forCharacterRange: characterRange))
    }
}

