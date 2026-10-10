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

/// Represents font named style. It reads what it tells from Core when it is asked for.
public struct NamedStyle: @unchecked Sendable {
    // The typeface owns the memory that the style of Core points to.
    private let owner: Typeface
    private let style: TRNamedStyle

    init(owner: Typeface, style: TRNamedStyle) {
        self.owner = owner
        self.style = style
    }

    /// The style name.
    public var styleName: String {
        return String(style.subfamilyName)
    }

    /// The coordinates.
    public var coordinates: PrimitiveCollection<CGFloat> {
        return PrimitiveCollection(
            CoreCollection(
                owner: owner, pointer: style.coordinatesPtr, count: Int(style.coordinateCount)
            ) { CGFloat($0) }
        )
    }

    /// The post script name.
    public var postScriptName: String? {
        return style.postScriptName.map { String($0) }
    }
}
