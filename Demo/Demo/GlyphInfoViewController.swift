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

import TehreerCocoa
import UIKit

class GlyphInfoView: UIView {
    private var needsUpdateData = false
    private var fontAscent: CGFloat = .zero
    private var fontDescent: CGFloat = .zero
    private var glyphAdvance: CGFloat = .zero
    private var glyphPath: CGPath!
    private var glyphBounds: CGRect = .zero

    var typeface: Typeface! {
        didSet { setNeedsUpdateData() }
    }

    var displaySize: CGFloat = 1024 {
        didSet { setNeedsUpdateData() }
    }

    var glyphID: UInt16 = .zero {
        didSet { setNeedsUpdateData() }
    }

    private func setNeedsUpdateData() {
        needsUpdateData = true
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    private func updateDataIfNeeded() {
        guard needsUpdateData else {
            return
        }
        needsUpdateData = false

        guard let typeface = typeface else {
            fontAscent = .zero
            fontDescent = .zero
            glyphAdvance = .zero
            glyphPath = nil
            glyphBounds = .zero
            return
        }

        let typeSize = CGFloat(typeface.unitsPerEm)
        let sizeScale = displaySize / typeSize
        let transform = CGAffineTransform(scaleX: sizeScale, y: sizeScale)

        fontAscent = CGFloat(typeface.ascent) * sizeScale
        fontDescent = CGFloat(typeface.descent) * sizeScale
        glyphAdvance = typeface.advance(forGlyph: glyphID, typeSize: typeSize, vertical: false) * sizeScale
        glyphPath = typeface.path(forGlyph: glyphID, typeSize: typeSize, transform: transform)
        glyphBounds = glyphPath.boundingBox
    }

    private func drawLine(in context: CGContext, start: CGPoint, end: CGPoint) {
        context.move(to: start)
        context.addLine(to: end)

        context.strokePath()
    }

    override var intrinsicContentSize: CGSize {
        updateDataIfNeeded()

        let hPadding: CGFloat = 144.0
        let vPadding: CGFloat = 32.0

        let negativeLSB = min(glyphBounds.minX, 0.0)
        let advanceWidth = glyphAdvance - negativeLSB
        let pathWidth = glyphBounds.maxX - negativeLSB

        let boundaryWidth = max(advanceWidth, pathWidth) + hPadding
        let boundaryHeight = fontAscent + fontDescent + vPadding

        return CGSize(width: ceil(boundaryWidth),
                      height: ceil(boundaryHeight))
    }

    override func draw(_ rect: CGRect) {
        updateDataIfNeeded()

        guard let context = UIGraphicsGetCurrentContext(),
              let glyphPath = glyphPath else {
                return
        }

        let fontHeight = fontAscent + fontDescent
        let lsbX = round((bounds.width - glyphBounds.width) / 2.0 - glyphBounds.minX)
        let rsbX = round(lsbX + glyphAdvance)
        let baseY = round((bounds.height - fontHeight) / 2.0 + fontAscent)
        let ascentY = round(baseY - fontAscent)
        let descentY = round(baseY + fontDescent)

        context.setShouldAntialias(true)
        context.setFontSize(12.0)
        context.setFillColor(UIColor.black.cgColor)
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(1.0)

        // Draw Vertical Lines.
        drawLine(in: context, start: CGPoint(x: lsbX, y: 0.0), end: CGPoint(x: lsbX, y: bounds.maxY))
        drawLine(in: context, start: CGPoint(x: rsbX, y: 0.0), end: CGPoint(x: rsbX, y: bounds.maxY))
        // Draw Horizontal Lines.
        drawLine(in: context, start: CGPoint(x: 0.0, y: baseY), end: CGPoint(x: bounds.maxX, y: baseY))
        drawLine(in: context, start: CGPoint(x: 0.0, y: ascentY), end: CGPoint(x: bounds.maxX, y: ascentY))
        drawLine(in: context, start: CGPoint(x: 0.0, y: descentY), end: CGPoint(x: bounds.maxX, y: descentY))
        // Draw Origin Circle.
        context.addEllipse(in: CGRect(x: lsbX - 4.0, y: baseY - 4.0, width: 8.0, height: 8.0))
        context.strokePath()

        // Draw Headings.
        NSAttributedString(string: "Ascent").draw(at: CGPoint(x: 0.0, y: ascentY))
        NSAttributedString(string: "Baseline").draw(at: CGPoint(x: 0.0, y: baseY))
        NSAttributedString(string: "Descent").draw(at: CGPoint(x: 0.0, y: descentY))

        // Draw Glyph Path.
        context.translateBy(x: lsbX, y: baseY)
        context.addPath(glyphPath)
        context.strokePath()
    }
}

class GlyphInfoViewController: UIViewController {
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var glyphInfoView: GlyphInfoView!

    private var typeface: Typeface!
    private var glyphID: UInt16 = .zero

    func setup(typeface: Typeface, glyphID: UInt16) {
        self.typeface = typeface
        self.glyphID = glyphID
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        glyphInfoView.typeface = typeface
        glyphInfoView.glyphID = glyphID
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        glyphInfoView.displaySize = scrollView.frame.height / 3.0
    }
}
