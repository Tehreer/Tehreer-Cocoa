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

/// Represents font named style.
public struct NamedStyle {
    /// The style name.
    public let styleName: String

    /// The coordinates.
    public let coordinates: [CGFloat]

    /// The post script name.
    public let postScriptName: String?

    init(styleName: String, coordinates: [CGFloat], postScriptName: String?) {
        self.styleName = styleName
        self.coordinates = coordinates
        self.postScriptName = postScriptName
    }
}
