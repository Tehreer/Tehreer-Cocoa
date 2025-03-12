//
// Copyright (C) 2025 Muhammad Tayyab Akram
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
import SwiftUI

@available(iOS 15.0, *)
struct LineCanvas: View {
    let line: ComposedLine
    let renderer: Renderer
    let frame: CGRect

    init(
        _ line: ComposedLine,
        renderer: Renderer,
        frame: CGRect
    ) {
        self.line = line
        self.renderer = renderer
        self.frame = frame
    }

    var body: some View {
        Canvas { graphicsContext, size in
            graphicsContext.withCGContext { context in
                let superOrigin = frame.origin
                let lineOrigin = line.origin

                let offset = CGPoint(
                    x: lineOrigin.x - superOrigin.x,
                    y: lineOrigin.y - superOrigin.y
                )

                context.interpolationQuality = .none
                context.setShouldAntialias(false)
                context.setBlendMode(.normal)

                context.translateBy(x: offset.x, y: offset.y)
                line.draw(with: renderer, in: context)
            }
        }
        .frame(width: frame.width, height: frame.height)
    }
}
