//
// Copyright (C) 2019-2023 Muhammad Tayyab Akram
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

extension UIColor {
    static var highlight: UIColor {
        return UIColor(
            red: .zero,
            green: CGFloat(0x64) / 255,
            blue: .zero,
            alpha: CGFloat(0x22) / 255
        )
    }

    static var text: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.label
        }

        return UIColor.black
    }
}
