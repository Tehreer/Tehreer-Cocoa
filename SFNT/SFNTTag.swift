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

import Foundation

public struct SFNTTag: RawRepresentable {
    public typealias RawValue = UInt32

    public let rawValue: UInt32

    public init?(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension SFNTTag: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    static func isValidByte(_ byte: UInt8) -> Bool {
        return byte >= 0x32 && byte <= 0x7E
    }

    public init(stringLiteral: String) {
        var counter: Int = 0
        var codeUnits: [UInt8] = [0, 0, 0, 0]

        for c in stringLiteral.utf8 {
            defer {
                counter += 1
            }

            if counter >= 4 {
                break
            }

            codeUnits[counter] = c
        }

        guard counter == 4
            && SFNTTag.isValidByte(codeUnits[0])
            && SFNTTag.isValidByte(codeUnits[1])
            && SFNTTag.isValidByte(codeUnits[2])
            && SFNTTag.isValidByte(codeUnits[3]) else {
                fatalError("Invalid tag string")
        }

        rawValue = UInt32(codeUnits[0] << 24)
                 | UInt32(codeUnits[1] << 16)
                 | UInt32(codeUnits[2] << 8)
                 | UInt32(codeUnits[3])
    }
}

extension SFNTTag: CustomStringConvertible {
    public var description: String {
        let codeUnits: [UInt8] = [
            UInt8(rawValue >> 24),
            UInt8((rawValue >> 16) & 0xFF),
            UInt8((rawValue >> 8) & 0xFF),
            UInt8(rawValue & 0xFF), 0]

        return codeUnits.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }
}
