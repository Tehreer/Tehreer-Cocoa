//
// Copyright (C) 2026 Muhammad Tayyab Akram
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

extension String {
    /// Creates a string from a string view of Core, or an empty one for a missing view.
    init(_ view: UnsafePointer<TRStringView>?) {
        guard let view = view, let buffer = view.pointee.buffer else {
            self = ""
            return
        }

        let length = Int(view.pointee.length)

        switch view.pointee.encoding {
        case TRStringEncoding(TRStringEncodingUTF8):
            let units = buffer.assumingMemoryBound(to: UInt8.self)
            self = String(decoding: UnsafeBufferPointer(start: units, count: length), as: UTF8.self)

        case TRStringEncoding(TRStringEncodingUTF16):
            let units = buffer.assumingMemoryBound(to: UInt16.self)
            self = String(decoding: UnsafeBufferPointer(start: units, count: length), as: UTF16.self)

        case TRStringEncoding(TRStringEncodingUTF32):
            let units = buffer.assumingMemoryBound(to: UInt32.self)
            self = String(decoding: UnsafeBufferPointer(start: units, count: length), as: UTF32.self)

        default:
            self = ""
        }
    }

    /// Creates a string from the characters that Core copied into a buffer, which are not
    /// terminated.
    init(coreCharacters buffer: [CChar], length: Int) {
        self = String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Calls the body with the string as a view of Core that has UTF-8 encoding, which is valid
    /// only during the call.
    func withCoreView<Result>(_ body: (UnsafePointer<TRStringView>) -> Result) -> Result {
        return Array(utf8).withUnsafeBufferPointer { (buffer) in
            var view = TRStringView(buffer: buffer.baseAddress,
                                    length: TRUInteger(buffer.count),
                                    encoding: TRStringEncoding(TRStringEncodingUTF8))

            return withUnsafePointer(to: &view, body)
        }
    }
}
