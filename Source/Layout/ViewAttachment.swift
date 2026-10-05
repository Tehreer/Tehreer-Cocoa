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

import CoreGraphics
import UIKit

/// A `TextReplacement` whose room in the text is filled by a real, live `UIView` that a
/// `TTextView` keeps attached and positioned while the attachment's line is near the screen,
/// detaching it again (unless `retainWhenOffscreen`) once it scrolls away, so a long article with
/// several attachments stays cheap.
///
/// Unlike a plain `TextReplacement`, a `ViewAttachment` draws nothing itself - the room is filled
/// by `view` instead.
open class ViewAttachment: TextReplacement {
    /// Where a `ViewAttachment` goes in the text.
    public enum Placement {
        /// The view has a line of its own and is as wide as the text, at whatever place the text
        /// begins. This is the default.
        case block

        /// The view sits in a line of text, at the width `ViewAttachment.width`, with its bottom
        /// edge `ViewAttachment.baselineOffset` below the baseline. It makes the line taller if it
        /// is taller than the text.
        case inline
    }

    /// The height of an attachment that is decided by the view, see
    /// `measure(forLayoutWidth:view:)`.
    public static let automaticDimension: CGFloat = -1.0

    /// The view currently attached to a `TTextView`, or `nil` if there isn't one right now -
    /// either because the attachment's line is off-screen, or it isn't part of a displayed text.
    public internal(set) weak var view: UIView?

    /// Where the view goes, on a line of its own or inside a line of text.
    open var placement: Placement { .block }

    /// The width of the room, in points, for an `.inline` attachment. A `.block` attachment is as
    /// wide as the text.
    open var width: CGFloat { 0 }

    /// The height of the room, and of the view, in points; or `automaticDimension`, which is the
    /// default, to have it decided by the view, see `measure(forLayoutWidth:view:)`.
    open var height: CGFloat { ViewAttachment.automaticDimension }

    /// How far the bottom edge of an `.inline` view is below the baseline of the text, in points,
    /// between 0 and `height`. With 0 the view stands on the baseline.
    open var baselineOffset: CGFloat { 0 }

    /// The space above and below a `.block` view; only `top` and `bottom` are used. It is part of
    /// the line, so the text around it is pushed away. An `.inline` view has no margins.
    open var margins: UIEdgeInsets { .zero }

    /// Whether the view is kept, laid out where it belongs and with its state, while it is far
    /// from the screen. By default it is dropped, and made again by `loadView()` when it comes
    /// back.
    open var retainWhenOffscreen: Bool { false }

    /// Whether the view is kept out of sight while the text is framed again after it asked for a
    /// resize, which is the default. A view whose room is going to change is then never seen with
    /// a room that is not its own, at the price of a blank for as long as the frame takes; and a
    /// view that is not on the screen is never hidden, as nobody would see the difference.
    ///
    /// An attachment whose view is likely to be on the screen when it resizes, and that would
    /// rather be seen at its old size for a moment than not at all, returns `false`: the view
    /// stays where it is, and gets the new room as soon as the frame is in place.
    open var hidesWhileResizing: Bool { true }

    public init() {}

    /// Makes the view. Called on the main thread, when the view is needed.
    open func loadView() -> UIView {
        fatalError("ViewAttachment subclasses must override loadView()")
    }

    /// Tells how big the `view` wants to be when the text is `layoutWidth` points wide. It is
    /// called on the main thread whenever the text is laid out again, for an attachment whose
    /// `height` is `automaticDimension`, before the lines are made; whatever height is returned
    /// is the height of the room. The width is not used yet: a `.block` view is always as wide as
    /// the text, and an `.inline` view as wide as `width`.
    ///
    /// The default fits the view at that width with as much height as it wants, which is right
    /// for any view whose height is known as soon as it is sized; override it to do differently.
    /// The view has no superview yet, and may never be shown.
    open func measure(forLayoutWidth layoutWidth: CGFloat, view: UIView) -> CGSize {
        let viewWidth = isBlock ? layoutWidth : max(width, 0)

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: viewWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return CGSize(width: viewWidth, height: fittingSize.height)
    }

    /// Tells that the view has changed its size by itself, or that a property of the room has:
    /// the text is framed again with the new size, without being typeset again, and the lines
    /// below the view move. What the reader is looking at does not, and the view is kept out of
    /// sight until the new frame is in place so it does not jump. It can be called from any
    /// thread at any time; calls that come together are made one.
    public func setNeedsResize() {
        lock.lock()
        let isScheduled = isResizePending
        isResizePending = true
        lock.unlock()

        guard !isScheduled else { return }

        DispatchQueue.main.async {
            self.lock.lock()
            self.isResizePending = false
            let liveHosts = self.hosts.compactMap { $0.value }
            self.lock.unlock()

            for host in liveHosts {
                host.attachmentResizeRequested(self)
            }
        }
    }

    // MARK: - Room

    struct Room {
        let ascent: CGFloat
        let descent: CGFloat
        let extent: CGFloat
    }

    private let lock = NSLock()
    private var isResizePending = false
    private var _measuredHeight: CGFloat = -1.0
    private var hosts: [WeakHost] = []

    private struct WeakHost {
        weak var value: TextContainer?
    }

    /// The height that the text view measured, or -1 if it has not.
    var measuredHeight: CGFloat {
        get {
            lock.lock()
            defer { lock.unlock() }

            return _measuredHeight
        }
        set {
            lock.lock()
            _measuredHeight = newValue
            lock.unlock()
        }
    }

    var isBlock: Bool {
        return placement == .block
    }

    /// Whether the text view has to ask `measure(forLayoutWidth:view:)` for the height.
    var isMeasured: Bool {
        return height < 0
    }

    /// The room of the line box, in the numbers of a text run, when the frame is `layoutWidth`
    /// wide. It is asked every time a line with this attachment is made, so the frame has the
    /// width of the text and the height that the view was measured to, and needs no typesetting
    /// again.
    func computeRoom(layoutWidth: CGFloat) -> Room {
        let fixed = height
        let roomHeight = fixed >= 0 ? fixed : max(measuredHeight, 0)

        if isBlock {
            let margins = self.margins
            let extent = layoutWidth.isFinite ? layoutWidth : 0.0

            return Room(ascent: max(margins.top, 0) + roomHeight, descent: max(margins.bottom, 0), extent: extent)
        }

        let offset = min(max(baselineOffset, 0), roomHeight)
        return Room(ascent: roomHeight - offset, descent: offset, extent: max(width, 0))
    }

    /// Remembers the text view that shows this attachment, to tell it about `setNeedsResize()`.
    func attach(to host: TextContainer) {
        lock.lock()
        defer { lock.unlock() }

        hosts.removeAll { $0.value == nil }

        if !hosts.contains(where: { $0.value === host }) {
            hosts.append(WeakHost(value: host))
        }
    }

    /// The frame of the view, given the box of its run in the text, `runRect`, and the width of
    /// the frame: the box without the margins, as wide as the frame for a `.block`.
    func viewFrame(in runRect: CGRect, frameWidth: CGFloat) -> CGRect {
        guard isBlock else {
            return runRect
        }

        let margins = self.margins
        let top = max(margins.top, 0)
        let bottom = max(margins.bottom, 0)

        return CGRect(
            x: 0.0,
            y: runRect.minY + top,
            width: frameWidth,
            height: max(runRect.height - top - bottom, 0)
        )
    }

    // MARK: - TextReplacement

    /// The provisional room, which is what the line breaking sees: a block is no wider than a
    /// point, and is put on a line of its own by the line breaking. The room that the lines have
    /// is worked out again for every frame, see `computeRoom(layoutWidth:)`.
    public var ascent: CGFloat { computeRoom(layoutWidth: 0.0).ascent }
    public var descent: CGFloat { computeRoom(layoutWidth: 0.0).descent }
    public var leading: CGFloat { .zero }

    /// Nothing is drawn - the room is filled by `view`.
    public func draw(in context: CGContext) {}
}
