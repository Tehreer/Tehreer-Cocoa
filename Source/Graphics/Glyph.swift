//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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

class Glyph {
    let glyphID: GlyphID

    private(set) var lsb: Int = .zero
    private(set) var tsb: Int = .zero
    private(set) var image: CGLayer?
    private(set) var outline: FT_Glyph?

    private(set) var path: CGPath?

    init(glyphID: GlyphID) {
        self.glyphID = glyphID
    }

    deinit {
        FT_Done_Glyph(outline)
    }

    func own(image: CGLayer?, left: Int, top: Int) {
        self.image = image
        self.lsb = left
        self.tsb = top
    }

    func own(outline: FT_Glyph?) {
        self.outline = outline
    }

    func own(path: CGPath?) {
        self.path = path
    }
}
