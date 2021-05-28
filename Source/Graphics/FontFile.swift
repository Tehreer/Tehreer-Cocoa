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
import FreeType

/// A `FontFile` object represents the file of a specific font format.
public class FontFile {
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

        for i in 0 ..< fontStream.faceCount {
            guard let firstFace = IntrinsicFace(fontStream: fontStream, faceIndex: i) else {
                continue
            }

            let ftFace = firstFace.renderableFace.ftFace
            var variation: UnsafeMutablePointer<FT_MM_Var>!

            if FT_Get_MM_Var(ftFace, &variation) == FT_Err_Ok {
                defer {
                    FreeType.withLibrary { (library) -> Void in
                        FT_Done_MM_Var(library, variation)
                    }
                }

                let numNamedStyles = variation.pointee.num_namedstyles
                var namedStyle = variation.pointee.namedstyle!

                for _ in 0 ..< numNamedStyles {
                    var coordinates: [CGFloat] = []

                    for i in 0 ..< variation.pointee.num_axis {
                        coordinates.append(CGFloat(f16Dot16: namedStyle.pointee.coords[Int(i)]))
                    }

                    if let namedFace = firstFace.variationInstance(forCoordinates: coordinates) {
                        defaultTypefaces.append(Typeface(instance: namedFace))
                    }

                    namedStyle = namedStyle.advanced(by: 1)
                }
            } else {
                defaultTypefaces.append(Typeface(instance: firstFace))
            }
        }
    }

    /// Named typefaces of this font file.
    public var typefaces: [Typeface] {
        return defaultTypefaces
    }
}
