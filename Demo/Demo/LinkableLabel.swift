//
// Copyright (C) 2020 Muhammad Tayyab Akram
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

private struct Link: Equatable {
    let url: URL
    let range: Range<String.Index>
}

class LinkableLabel: TLabel {
    private var activeLink: Link?
    private var linkPath: CGPath?

    override func draw(_ rect: CGRect) {
        if let linkPath = linkPath, let context = UIGraphicsGetCurrentContext() {
            UIColor(red: CGFloat(0xCC) / 255.0, green: CGFloat(0xCC) / 255.0,
                    blue: CGFloat(0xEE) / 255.0, alpha: 1.0).setFill()

            context.addPath(linkPath)
            context.drawPath(using: .fill)
        }

        super.draw(rect)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let firstTouch = touches.first else {
            return
        }

        activeLink = link(at: firstTouch.location(in: self))
        refreshActiveLink()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        if let firstTouch = touches.first {
            let pointedLink = link(at: firstTouch.location(in: self))
            if pointedLink != activeLink {
                clearActiveLink()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if activeLink != nil {
            openActiveLink()
            clearActiveLink()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        if activeLink != nil {
            clearActiveLink()
        }
    }

    private func link(at codeUnitIndex: Int) -> Link? {
        guard let attrText = attributedText else {
            return nil
        }

        var spanRange = NSRange(location: 0, length: 0)
        let attribute = attrText.attribute(.link, at: codeUnitIndex,
                                           longestEffectiveRange: &spanRange,
                                           in: NSRange(location: 0, length: attrText.length))

        if let url = attribute as? URL,
           let range = Range<String.Index>(spanRange, in: attrText.string) {
            return Link(url: url, range: range)
        }

        return nil
    }

    private func link(at position: CGPoint) -> Link? {
        guard let codeUnitIndex = indexOfCodeUnit(at: position) else {
            return nil
        }

        return link(at: codeUnitIndex)
    }

    private func refreshActiveLink() {
        defer { setNeedsDisplay() }

        guard let activeLink = activeLink,
              let textFrame = textFrame else {
            linkPath = nil
            return
        }

        linkPath = textFrame.selectionPath(forCharacterRange: activeLink.range)
    }

    private func clearActiveLink() {
        activeLink = nil
        refreshActiveLink()
    }

    private func openActiveLink() {
        if let url = activeLink?.url {
            UIApplication.shared.openURL(url)
        }
    }
}
