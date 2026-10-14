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

import CoreGraphics

extension CGRect {
    /// Creates a rectangle from the one of Core.
    init(_ rect: TRRect) {
        self.init(
            x: CGFloat(rect.origin.x),
            y: CGFloat(rect.origin.y),
            width: CGFloat(rect.size.width),
            height: CGFloat(rect.size.height)
        )
    }

    /// Creates a rectangle from the one of Core, or a null rectangle if the one of Core is empty,
    /// as it has no place in the space of the glyphs.
    init(inkBox rect: TRRect) {
        if rect.size.width == 0 && rect.size.height == 0 {
            self = .null
        } else {
            self.init(rect)
        }
    }

    /// The rectangle for Core.
    var coreValue: TRRect {
        return TRRect(
            origin: TRPoint(x: TRFloat(origin.x), y: TRFloat(origin.y)),
            size: TRSize(width: TRFloat(width), height: TRFloat(height))
        )
    }
}
