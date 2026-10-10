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

internal import Tehreer

import CoreGraphics
import Foundation

/// The replacement of Core for a `TextReplacement` of the wrapper, which keeps the object that
/// decides the room.
private final class ReplacementBox {
    let replacement: TextReplacement

    init(_ replacement: TextReplacement) {
        self.replacement = replacement
    }

    func room(layoutWidth: CGFloat) -> TRReplacementRoom {
        if let attachment = replacement as? ViewAttachment {
            let room = attachment.computeRoom(layoutWidth: layoutWidth)

            return TRReplacementRoom(
                ascent: TRFloat(room.ascent),
                descent: TRFloat(room.descent),
                extent: TRFloat(room.extent)
            )
        }

        return TRReplacementRoom(
            ascent: TRFloat(replacement.ascent),
            descent: TRFloat(replacement.descent),
            extent: TRFloat(replacement.width)
        )
    }
}

extension TextReplacement {
    /// Creates the replacement of Core for this replacement, which the caller owns. Core only uses
    /// its room to lay out the line, while the drawing is left to the wrapper.
    func makeCoreReplacement() -> TRReplacementRef? {
        var callbacks = TRReplacementCallbacks()
        callbacks.computeRoom = { (user, layoutWidth, room) in
            let box = Unmanaged<ReplacementBox>.fromOpaque(user!).takeUnretainedValue()
            room!.pointee = box.room(layoutWidth: CGFloat(layoutWidth))
        }
        callbacks.finalize = { (user) in
            Unmanaged<ReplacementBox>.fromOpaque(user!).release()
        }

        let isBlock = (self as? ViewAttachment)?.isBlock == true
        let box = Unmanaged.passRetained(ReplacementBox(self))

        let kind = isBlock ? TRReplacementKind(TRReplacementKindBlock)
                           : TRReplacementKind(TRReplacementKindInline)

        guard let core = TRReplacementCreate(&callbacks, box.toOpaque(), kind) else {
            box.release()
            return nil
        }

        return core
    }
}
