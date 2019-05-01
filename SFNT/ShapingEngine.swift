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

/// The `ShapingEngine` class represents text shaping engine.
public class ShapingEngine {
    let sfArtist: SFArtistRef
    let sfScheme: SFSchemeRef

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

    public var typeface: Typeface! = nil

    public var typeSize: CGFloat = 16

    public var scriptTag: SFNTTag = "DFLT"

    public var languageTag: SFNTTag = "dflt"

    public var writingDirection = WritingDirection.leftToRight {
        didSet(newValue) {
            SFArtistSetTextDirection(sfArtist, SFTextDirection(newValue.rawValue))
        }
    }

    public var shapingOrder = ShapingOrder.forward {
        didSet(newValue) {
            SFArtistSetTextMode(sfArtist, SFTextMode(newValue.rawValue))
        }
    }

    public func shape(text: String, range: Range<String.Index>) -> ShapingResult {
        guard typeface != nil else {
            fatalError("Typeface was not set")
        }

        let shapingResult = ShapingResult()

        let cache = typeface.patternCache
        let key = PatternKey(scriptTag: scriptTag, languageTag: languageTag)
        var pattern = cache[key]

        if pattern == nil {
            SFSchemeSetFont(sfScheme, typeface.sfFont)
            SFSchemeSetScriptTag(sfScheme, scriptTag.rawValue)
            SFSchemeSetLanguageTag(sfScheme, languageTag.rawValue)

            pattern = SFSchemeBuildPattern(sfScheme)
            cache[key] = pattern

            SFPatternRelease(pattern)
        }

        var codeUnits = Array(text[range].utf16)
        let length = SFUInteger(codeUnits.count)

        codeUnits.withUnsafeMutableBufferPointer { (pointer) -> Void in
            let encoding = SFStringEncoding(SFStringEncodingUTF16)
            let buffer = UnsafeMutableRawPointer(pointer.baseAddress!)

            SFArtistSetPattern(sfArtist, pattern)
            SFArtistSetString(sfArtist, encoding, buffer, length)
            SFArtistFillAlbum(sfArtist, shapingResult.sfAlbum)
        }

        shapingResult.setAdditionalInfo(sizeByEm: typeSize / CGFloat(typeface.unitsPerEm),
                                        isBackward: shapingOrder == .backward,
                                        stringRange: range,
                                        codeUnitCount: codeUnits.count)

        return shapingResult
    }
}

