//
// Copyright (C) 2021-2023 Muhammad Tayyab Akram
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
import UIKit

class LineView: UIView {
    let renderer = Renderer()

    var layoutWidth: CGFloat = .zero

    var separatorColor: UIColor?

    var line: ComposedLine? {
        didSet {
            DispatchQueue.main.async {
                self.setNeedsDisplay()
            }
        }
    }

    private func drawSeparator(for line: ComposedLine, in context: CGContext) {
        guard let separatorColor = separatorColor else { return }

        let superOrigin = frame.origin

        let lineTop = line.origin.y - line.ascent - superOrigin.y
        let lineBottom = lineTop + line.height

        let separatorHeight: CGFloat = 1.0

        let separatorLeft = floor(0.0 - superOrigin.x)
        let separatorRight = ceil(separatorLeft + layoutWidth)
        let separatorTop = floor(lineBottom - (separatorHeight / 2.0))

        context.setShouldAntialias(true)
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(separatorHeight)

        context.move(to: CGPoint(x: separatorLeft, y: separatorTop))
        context.addLine(to: CGPoint(x: separatorRight, y: separatorTop))

        context.strokePath()
    }

    private func drawTextLine(_ line: ComposedLine, in context: CGContext) {
        let superOrigin = frame.origin
        let lineOrigin = line.origin

        let offset = CGPoint(
            x: lineOrigin.x - superOrigin.x,
            y: lineOrigin.y - superOrigin.y
        )

        context.translateBy(x: offset.x, y: offset.y)
        line.draw(with: renderer, in: context)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let line = line else { return }

        drawSeparator(for: line, in: context)
        drawTextLine(line, in: context)
    }
}
