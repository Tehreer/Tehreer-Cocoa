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

import UIKit

extension NSTextAlignment {
    func flushFactor(for paragraphLevel: UInt8) -> CGFloat {
        let isRTL = (paragraphLevel & 1) == 1

        switch self {
        case .center:
            return 0.5
        case .right:
            return 1.0
        case .natural, .justified:
            return isRTL ? 1.0 : 0.0
        default:
            return 0.0
        }
    }
}
