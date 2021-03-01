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

import Foundation
import FreeType

class GlyphKey: Hashable {
    var typeface: Typeface! = nil
    var pixelWidth: FT_F26Dot6 = 0  // 26.6 fixed-point value.
    var pixelHeight: FT_F26Dot6 = 0 // 26.6 fixed-point value.
    var skewX: FT_Fixed = 0         // 16.16 fixed-point value.

    fileprivate init() { }

    func copy() -> GlyphKey {
        fatalError()
    }

    fileprivate func set(from key: GlyphKey) {
        typeface = key.typeface
        pixelWidth = key.pixelWidth
        pixelHeight = key.pixelHeight
        skewX = key.skewX
    }

    fileprivate func equals(_ key: GlyphKey) -> Bool {
        return typeface === key.typeface
            && pixelWidth == key.pixelWidth
            && pixelHeight == key.pixelHeight
            && skewX == key.skewX
    }

    static func ==(lhs: GlyphKey, rhs: GlyphKey) -> Bool {
        return lhs.equals(rhs)
    }

    func hash(into hasher: inout Hasher) {
        if typeface != nil {
            hasher.combine(ObjectIdentifier(typeface))
        }

        hasher.combine(pixelWidth)
        hasher.combine(pixelHeight)
        hasher.combine(skewX)
    }
}

extension GlyphKey {
    final class Data: GlyphKey {
        override init() { }

        override func copy() -> Data {
            let key = Data()
            key.set(from: self)

            return key
        }

        override func equals(_ key: GlyphKey) -> Bool {
            if self === key {
                return true
            }
            guard let key = key as? Data else {
                return false
            }

            return super.equals(key)
        }
    }

    final class Color: GlyphKey {
        var foregroundColor: FT_Color = FT_Color(blue: 0, green: 0, red: 0, alpha: 0)

        override init() { }

        func set(from key: Data) {
            super.set(from: key)
        }

        override func copy() -> Color {
            let key = Color()
            key.set(from: self)
            key.foregroundColor = foregroundColor

            return key
        }

        override func equals(_ key: GlyphKey) -> Bool {
            if self === key {
                return true
            }
            guard let key = key as? Color else {
                return false
            }

            return super.equals(key)
                && foregroundColor.blue == key.foregroundColor.blue
                && foregroundColor.green == key.foregroundColor.green
                && foregroundColor.red == key.foregroundColor.red
                && foregroundColor.alpha == key.foregroundColor.alpha
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(foregroundColor.blue)
            hasher.combine(foregroundColor.green)
            hasher.combine(foregroundColor.red)
            hasher.combine(foregroundColor.alpha)
        }
    }

    final class Stroke: GlyphKey {
        var lineRadius: FT_Fixed = 0
        var lineCap = FT_Stroker_LineCap(rawValue: 0)
        var lineJoin = FT_Stroker_LineJoin(rawValue: 0)
        var miterLimit: FT_Fixed = 0

        override init() { }

        func set(from key: Data) {
            super.set(from: key)
        }

        override func copy() -> Stroke {
            let key = Stroke()
            key.set(from: self)
            key.lineRadius = lineRadius
            key.lineCap = lineCap
            key.lineJoin = lineJoin
            key.miterLimit = miterLimit

            return key
        }

        override func equals(_ key: GlyphKey) -> Bool {
            if self === key {
                return true
            }
            guard let key = key as? Stroke else {
                return false
            }

            return super.equals(key)
                && lineRadius == key.lineRadius
                && lineCap == key.lineCap
                && lineJoin == key.lineJoin
                && miterLimit == key.miterLimit
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(lineRadius)
            hasher.combine(lineCap.rawValue)
            hasher.combine(lineJoin.rawValue)
            hasher.combine(miterLimit)
        }
    }
}
