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

class Glyph {
    let glyphID: UInt16

    private var _left: Int = 0
    private var _top: Int = 0

    private(set) var image: CGImage? = nil
    private(set) var outline: FT_Glyph? = nil
    private(set) var path: CGPath? = nil

    init(glyphID: UInt16) {
        self.glyphID = glyphID
    }

    deinit {
        FT_Done_Glyph(outline)
    }

    var lsb: Int {
        return _left
    }

    var tsb: Int {
        return _top
    }

    func own(image: CGImage?, left: Int, top: Int) {
        self.image = image
        _left = left
        _top = top
    }

    func own(outline: FT_Glyph?) {
        self.outline = outline
    }

    func own(path: CGPath?) {
        self.path = path
    }
}
