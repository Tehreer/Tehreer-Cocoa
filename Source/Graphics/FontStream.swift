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

import Foundation

/// The font file of Core that is behind a font file and its typefaces.
final class FontStream {
    /// The font file of Core.
    let coreFile: TRFontFileRef

    /// The number of default typefaces in the font file.
    var typefaceCount: Int {
        return Int(TRFontFileGetTypefaceCount(coreFile))
    }

    /// Returns a default typeface of the font file, which stays valid as long as the font file does.
    func coreTypeface(at index: Int) -> TRTypefaceRef? {
        return TRFontFileGetTypeface(coreFile, TRUInteger(index))
    }

    init?(path: String) {
        guard let coreFile = TRFontFileCreateFromPath(path) else {
            return nil
        }

        self.coreFile = coreFile
    }

    init?(data: Data) {
        let coreFile = data.withUnsafeBytes { (bytes) in
            TRFontFileCreateFromMemory(bytes.baseAddress, TRUInteger(bytes.count))
        }
        guard let coreFile = coreFile else {
            return nil
        }

        self.coreFile = coreFile
    }

    convenience init?(stream: InputStream) {
        stream.open()

        let chunkLength = 4096
        let chunkBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkLength)

        var data = Data()

        while true {
            let bytesRead = stream.read(chunkBuffer, maxLength: chunkLength)
            guard bytesRead > 0 else {
                break
            }

            data.append(chunkBuffer, count: bytesRead)
        }

        chunkBuffer.deallocate()
        stream.close()

        self.init(data: data)
    }

    deinit {
        TRFontFileRelease(coreFile)
    }
}
