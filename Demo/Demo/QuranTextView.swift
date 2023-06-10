//
// Copyright (C) 2023 Muhammad Tayyab Akram
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

import Foundation
import TehreerCocoa
import UIKit

extension NSAttributedString.Key {
    static let ayah = NSAttributedString.Key("Ayah")
}

private struct Ayah: Equatable {
    let range: Range<String.Index>
}

private class HighlightingView: UIView {
    var highlightingColor = UIColor(white: CGFloat(0xDD) / 255, alpha: 1.0) {
        didSet {
            setNeedsDisplay()
        }
    }

    var highlightingPath: CGPath? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        if let path = highlightingPath {
            highlightingColor.setFill()

            context.addPath(path)
            context.drawPath(using: .fill)
        }
    }
}

class QuranTextView: TTextView {
    private let highlightingView = HighlightingView()

    private var activeAyah: Ayah?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        highlightingView.backgroundColor = .clear
        highlightingView.isOpaque = false
        highlightingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlightingView)

        let gesture = UITapGestureRecognizer(target: self, action: #selector(textViewTapped))
        addGestureRecognizer(gesture)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        highlightingView.frame = CGRect(origin: .zero, size: contentSize)
    }

    @objc
    private func textViewTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        let position = gestureRecognizer.location(in: self)
        activeAyah = ayah(at: position)
        refreshActiveAyah()
    }

    private func ayah(at codeUnitIndex: Int) -> Ayah? {
        guard let attributedText = attributedText else {
            return nil
        }

        var attributeRange = NSRange(location: 0, length: 0)
        let attributeValue = attributedText.attribute(
            .ayah,
            at: codeUnitIndex,
            longestEffectiveRange: &attributeRange,
            in: NSRange(location: 0, length: attributedText.length)
        )

        guard attributeValue != nil,
              let range = Range(attributeRange, in: attributedText.string) else {
            return nil
        }

        return Ayah(range: range)
    }

    private func ayah(at position: CGPoint) -> Ayah? {
        guard let codeUnitIndex = indexOfCodeUnit(at: position) else {
            return nil
        }

        return ayah(at: codeUnitIndex)
    }

    private func path(for ayah: Ayah) -> CGPath? {
        guard let textFrame = textFrame else { return nil }

        return textFrame.selectionPath(forCharacterRange: ayah.range)
    }

    private func refreshActiveAyah() {
        guard let activeAyah = activeAyah else { return }

        highlightingView.highlightingPath = path(for: activeAyah)
    }

    func clearAyahHighlighting() {
        activeAyah = nil
        highlightingView.highlightingPath = nil
    }

    var highlightingColor: UIColor {
        get { highlightingView.highlightingColor }
        set { highlightingView.highlightingColor = newValue }
    }
}
