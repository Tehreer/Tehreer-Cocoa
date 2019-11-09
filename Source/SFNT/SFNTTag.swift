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

private func isValidByte(_ byte: UInt8) -> Bool {
    return byte >= 0x32 && byte <= 0x7E
}

/// An SFNT tag value type.
public struct SFNTTag: RawRepresentable {
    /// The corresponding value of the raw type.
    public let rawValue: UInt32

    /// Creates a new instance with the specified raw value.
    ///
    /// - Parameter rawValue: The raw value to use for the new instance.
    public init?(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Creates a new instance with the specified tag string.
    ///
    /// - Parameter string: The tag string.
    public init?(string: String) {
        var counter: Int = 0
        var bytes: [UInt8] = [0, 0, 0, 0]

        for codeUnit in string.utf8 {
            defer { counter += 1 }

            guard counter < 4 else {
                break
            }

            bytes[counter] = codeUnit
        }

        guard counter == 4
           && isValidByte(bytes[0])
           && isValidByte(bytes[1])
           && isValidByte(bytes[2])
           && isValidByte(bytes[3]) else {
            return nil
        }

        rawValue = (UInt32(bytes[0]) << 24)
                 | (UInt32(bytes[1]) << 16)
                 | (UInt32(bytes[2]) << 8)
                 | UInt32(bytes[3])
    }
}

extension SFNTTag: ExpressibleByStringLiteral {
    /// Creates an instance initialized to the specified tag string.
    ///
    /// - Parameter value: The tag string.
    public init(stringLiteral value: String) {
        guard let tag = SFNTTag(string: value) else {
            fatalError("Invalid tag string")
        }

        self = tag
    }
}

extension SFNTTag: CustomStringConvertible {
    /// A textual representation of this tag.
    public var description: String {
        let bytes = [
            UInt8(rawValue >> 24),
            UInt8((rawValue >> 16) & 0xFF),
            UInt8((rawValue >> 8) & 0xFF),
            UInt8(rawValue & 0xFF), 0]

        return String(cString: bytes)
    }
}

extension SFNTTag: Hashable {
}
