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

import UIKit

class LineView: UIView {
    let renderer = Renderer()

    var line: ComposedLine? {
        didSet {
            DispatchQueue.main.async {
                self.setNeedsDisplay()
            }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let line = line else { return }

        let superOrigin = frame.origin
        let lineOrigin = line.origin
        let offset = CGPoint(x: lineOrigin.x - superOrigin.x,
                             y: lineOrigin.y - superOrigin.y)

        context.translateBy(x: offset.x, y: offset.y)
        line.draw(with: renderer, in: context)
    }
}
