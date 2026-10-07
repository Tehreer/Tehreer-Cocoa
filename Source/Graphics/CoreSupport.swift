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
}

extension UIColor {
    /// Creates a color from the value of Core, which is in ARGB order with 8 bits for each part.
    convenience init(coreColor: TRColor) {
        self.init(red: CGFloat((coreColor >> 16) & 0xFF) / 255.0,
                  green: CGFloat((coreColor >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(coreColor & 0xFF) / 255.0,
                  alpha: CGFloat((coreColor >> 24) & 0xFF) / 255.0)
    }

    /// The value of this color for Core, which is in ARGB order with 8 bits for each part.
    var coreColor: TRColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (TRColor(alpha * 255) << 24)
             | (TRColor(red * 255) << 16)
             | (TRColor(green * 255) << 8)
             | TRColor(blue * 255)
    }
}
