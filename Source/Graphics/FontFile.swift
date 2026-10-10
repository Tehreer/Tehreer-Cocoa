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

/// A `FontFile` object represents the file of a specific font format.
public final class FontFile {
    private var defaultTypefaces: [Typeface]!

    /// Creates a font file instance representing the specified file path. The data of the font is
    /// directly read from the file when needed.
    ///
    /// - Parameter path: The path of the font file.
    public init?(path: String) {
        guard let fontStream = FontStream(path: path) else {
            return nil
        }

        loadTypefaces(from: fontStream)
    }

    /// Creates a font file instance representing the specified data.
    ///
    /// - Parameter data: The data of the font file.
    public init?(data: Data) {
        guard let fontStream = FontStream(data: data) else {
            return nil
        }

        loadTypefaces(from: fontStream)
    }

    /// Creates a font file instance from the specified input stream by copying its data into a
    /// memory buffer. It may take some time to create the instance if the stream holds larger data.
    ///
    /// - Parameter stream: The input stream that contains the data of the font.
    public init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream) else {
            return nil
        }

        loadTypefaces(from: fontStream)
    }

    private func loadTypefaces(from fontStream: FontStream) {
        defaultTypefaces = []

        for index in 0 ..< fontStream.typefaceCount {
            if let core = fontStream.coreTypeface(at: index) {
                defaultTypefaces.append(Typeface(retaining: core))
            }
        }
    }

    /// Named typefaces of this font file. A face having named styles gives a typeface for each of
    /// them, and any other face gives a single one.
    public var typefaces: [Typeface] {
        return defaultTypefaces
    }
}
