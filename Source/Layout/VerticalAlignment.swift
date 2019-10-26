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

/// Specifies the vertical content alignment.
public enum VerticalAlignment: Int {
    /// Aligns the content vertically at the top of the frame.
    case top = 0
    /// Aligns the content vertically in the center of the frame.
    case middle = 1
    /// Aligns the content vertically at the bottom of the frame.
    case bottom = 2

    func multiplier() -> CGFloat {
        switch self {
        case .top:
            return 0.0
        case .middle:
            return 0.5
        case .bottom:
            return 1.0
        }
    }
}
