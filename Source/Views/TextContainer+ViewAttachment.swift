//
// Copyright (C) 2026 Muhammad Tayyab Akram
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

/// The place that the view of a `ViewAttachment` takes in the current frame, in the coordinate
/// system of this view.
struct AttachmentSlot {
    let attachment: ViewAttachment
    let rect: CGRect
}

extension TextContainer {
    /// Finds where the views of the attachments go in `textFrame`.
    func resolveViewSlots(in textFrame: ComposedFrame) -> [AttachmentSlot] {
        guard let text = sourceText else {
            return []
        }

        var slots: [AttachmentSlot] = []
        let frameRange = NSRange(location: textFrame.codeUnitRange.lowerBound, length: textFrame.codeUnitRange.count)

        text.enumerateAttribute(.replacement, in: frameRange, options: []) { (value, range, _) in
            guard let attachment = value as? ViewAttachment else { return }

            let start = range.location
            let lineIndex = textFrame.indexOfLine(forCodeUnitAt: start)
            guard lineIndex >= 0 else { return }

            let textLine = textFrame.lines[lineIndex]
            guard let glyphRun = textLine.visualRuns.first(where: { $0.codeUnitRange.contains(start) }) else { return }

            let runRect = CGRect(
                x: textLine.origin.x + glyphRun.origin.x,
                y: textLine.origin.y - glyphRun.ascent,
                width: glyphRun.width,
                height: glyphRun.height
            )

            slots.append(AttachmentSlot(
                attachment: attachment,
                rect: attachment.viewFrame(in: runRect, frameWidth: textFrame.width)
            ))
        }

        return slots.sorted { $0.rect.minY < $1.rect.minY }
    }

    /// Detaches every view that does not belong to an attachment of the current frame.
    func detachOrphanViews() {
        let liveAttachments = Set(viewSlots.map { ObjectIdentifier($0.attachment) })

        for attachment in attachedViewAttachments where !liveAttachments.contains(ObjectIdentifier(attachment)) {
            detach(attachment)
        }

        attachedViewAttachments.removeAll { !liveAttachments.contains(ObjectIdentifier($0)) }
        measuredViews = measuredViews.filter { liveAttachments.contains($0.key) }
        resizingAttachments.formIntersection(liveAttachments)
    }

    /// Whether a view at `rect` is on the screen, or no further from it than
    /// `viewAttachmentPrefetchDistance`. A view with no room, which is what a view that only knows
    /// its size once it is attached has to begin with, counts too when it is at the place of the
    /// screen, or it would never be attached and never grow.
    private func isNearScreen(_ rect: CGRect) -> Bool {
        let visible = visibleRect
        let top = visible.minY - viewAttachmentPrefetchDistance
        let bottom = visible.maxY + viewAttachmentPrefetchDistance

        if !rect.isEmpty {
            return rect.minX < visible.maxX && rect.maxX > visible.minX && rect.minY < bottom && rect.maxY > top
        }

        return rect.minX <= visible.maxX && rect.maxX >= visible.minX && rect.minY <= bottom && rect.maxY >= top
    }

    /// Puts the view of each attachment that is on a visible line, or is to be retained, over the
    /// room that the frame has for it, and removes the views that are far from the screen.
    func layoutViewAttachments() {
        for slot in viewSlots {
            let attachment = slot.attachment
            let identifier = ObjectIdentifier(attachment)

            if !attachment.retainWhenOffscreen && !isNearScreen(slot.rect) {
                if attachment.view != nil {
                    detach(attachment)
                }

                continue
            }

            let view: UIView

            if let existing = attachment.view {
                view = existing
            } else {
                view = measuredViews.removeValue(forKey: identifier) ?? attachment.loadView()
                attachment.view = view

                addSubview(view)
            }

            view.frame = slot.rect

            // The view is shown again once it is where the new frame has put it.
            if isFrameFresh && resizingAttachments.remove(identifier) != nil {
                view.isHidden = false
            }
        }

        isFrameFresh = false
        attachedViewAttachments = viewSlots.map { $0.attachment }.filter { $0.view != nil }
    }

    /// Measures the views of the attachments that leave their height to the view, at the width
    /// that the text has, and hands the heights to the attachments, which the frame reads. The
    /// view of an attachment is the one that is attached, or one that is made for the purpose and
    /// waits for its turn.
    func measureViewAttachments() {
        let source = isTypesetterUserDefined ? typesetter?.text : attributedText
        guard let text = source else { return }

        text.enumerateAttribute(.replacement, in: NSRange(location: 0, length: text.length), options: []) { (value, _, _) in
            guard let attachment = value as? ViewAttachment else { return }

            attachment.attach(to: self)

            if attachment.isMeasured {
                _ = measureViewAttachment(attachment)
            }
        }
    }

    private func measureViewAttachment(_ attachment: ViewAttachment) -> Bool {
        let identifier = ObjectIdentifier(attachment)

        let view: UIView
        if let existing = attachment.view ?? measuredViews[identifier] {
            view = existing
        } else {
            view = attachment.loadView()
            measuredViews[identifier] = view
        }

        let height = max(attachment.measure(forLayoutWidth: layoutWidthForAttachments, view: view).height, 0)
        let isChanged = attachment.measuredHeight != height

        attachment.measuredHeight = height

        return isChanged
    }

    /// Called, on the main thread, when an attachment tells that its view has changed its size.
    /// The view is measured again and, if the height is not the same, made invisible until the
    /// text is framed again with the new one.
    func attachmentResizeRequested(_ attachment: ViewAttachment) {
        guard viewSlots.contains(where: { $0.attachment === attachment }) else {
            return
        }

        // The size of a fixed room is not the view's to change.
        if attachment.isMeasured {
            // A view may have changed what it wants without a request for layout, and would then
            // answer from the cache of what it was asked before.
            if let view = attachment.view ?? measuredViews[ObjectIdentifier(attachment)] {
                setNeedsLayoutTree(view)
            }

            if !measureViewAttachment(attachment) {
                return
            }
        }

        // Out of sight while the new frame is made, unless it need not be: a view that is not on
        // the screen has nobody to be seen by, and an attachment may leave its view where it is,
        // and let it grow or shrink when the frame arrives, rather than blink.
        if let view = attachment.view, attachment.hidesWhileResizing, view.frame.intersects(visibleRect) {
            view.isHidden = true
            resizingAttachments.insert(ObjectIdentifier(attachment))
        }

        setNeedsUpdateTextFrame()
    }

    private func setNeedsLayoutTree(_ view: UIView) {
        view.setNeedsLayout()

        for subview in view.subviews {
            setNeedsLayoutTree(subview)
        }
    }

    /// Returns whether the position is on the view of a `ViewAttachment`.
    func isInsideViewAttachment(at position: CGPoint) -> Bool {
        return attachedViewAttachments.contains { $0.view?.frame.contains(position) == true }
    }

    private func detach(_ attachment: ViewAttachment) {
        attachment.view?.removeFromSuperview()
        attachment.view = nil
    }
}
