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

extension CGPath {
    /// The callbacks that add the elements of a path of Core to a `CGMutablePath`, which has to be
    /// passed as the user data.
    static var coreCallbacks: TRPathCallbacks {
        var callbacks = TRPathCallbacks()
        callbacks.moveTo = { (user, x, y, _) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        callbacks.lineTo = { (user, x, y, _) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        callbacks.quadTo = { (user, controlX, controlY, x, y, _) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addQuadCurve(
                    to: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                    control: CGPoint(x: CGFloat(controlX), y: CGFloat(controlY))
                )
        }
        callbacks.cubicTo = { (user, control1X, control1Y, control2X, control2Y, x, y, _) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
                .addCurve(
                    to: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                    control1: CGPoint(x: CGFloat(control1X), y: CGFloat(control1Y)),
                    control2: CGPoint(x: CGFloat(control2X), y: CGFloat(control2Y))
                )
        }
        callbacks.close = { (user, _) in
            Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue().closeSubpath()
        }

        return callbacks
    }

    /// Makes the path of Core Graphics from the path of Core.
    static func make(from corePath: TRPathRef, transform: UnsafePointer<TRAffineTransform>? = nil) -> CGPath {
        let path = CGMutablePath()
        let user = Unmanaged.passUnretained(path).toOpaque()

        var callbacks = coreCallbacks
        _ = TRPathEnumerate(corePath, transform, &callbacks, user)

        return path
    }
}
