//
// Copyright (C) 2021 Muhammad Tayyab Akram
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
import UIKit

class GlyphAttributes {
    private let _dataKey = GlyphKey.Data()
    private let _colorKey = GlyphKey.Color()
    private let _strokeKey = GlyphKey.Stroke()

    func setTypeface(_ typeface: Typeface) {
        _dataKey.typeface = typeface
    }

    func setPixelWidth(_ pixelWidth: CGFloat) {
        _dataKey.pixelWidth = Int((pixelWidth * 64.0) + 0.5)
    }

    func setPixelHeight(_ pixelHeight: CGFloat) {
        _dataKey.pixelHeight = Int((pixelHeight * 64.0) + 0.5)
    }

    func setSkewX(_ skewX: CGFloat) {
        _dataKey.skewX = Int((skewX * 0x10000) + 0.5)
    }

    func setForegroundColor(_ foregroundColor: FT_Color) {
        _colorKey.foregroundColor = foregroundColor
    }

    func setLineRadius(_ lineRadius: CGFloat) {
        _strokeKey.lineRadius = Int((lineRadius * 64.0) + 0.5)
    }

    func setLineCap(_ lineCap: FT_Stroker_LineCap) {
        _strokeKey.lineCap = lineCap
    }

    func setLineJoin(_ lineJoin: FT_Stroker_LineJoin) {
        _strokeKey.lineJoin = lineJoin
    }

    func setMiterLimit(_ miterLimit: CGFloat) {
        _strokeKey.miterLimit = Int((miterLimit * 0x10000) + 0.5)
    }

    var isRenderable: Bool {
        // Minimum size supported by FreeType is 64x64.
        return (_dataKey.pixelWidth >= 64 && _dataKey.pixelHeight >= 64)
    }

    var dataKey: GlyphKey.Data {
        return _dataKey
    }

    var colorKey: GlyphKey.Color {
        _colorKey.set(from: _dataKey)
        return _colorKey
    }

    var strokeKey: GlyphKey.Stroke {
        _strokeKey.set(from: _dataKey)
        return _strokeKey
    }
}
