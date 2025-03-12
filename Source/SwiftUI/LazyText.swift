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

import Foundation
import SwiftUI

@available(iOS 15.0, *)
struct LazyText: View {
    @StateObject private var manager: LazyTextManager

    let properties: TextProperties
    let coordinateSpace: CoordinateSpace
    @Binding var scrollHeight: CGFloat

    init(
        properties: TextProperties,
        coordinateSpace: CoordinateSpace,
        scrollHeight: Binding<CGFloat>
    ) {
        self.properties = properties
        self.coordinateSpace = coordinateSpace
        _manager = StateObject(wrappedValue: LazyTextManager())
        _scrollHeight = scrollHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ScrollOffsetKey.self,
                        value: geometry.frame(in: coordinateSpace).origin
                    )
            }
            .frame(height: 0)

            if let textFrame = manager.textFrame {
                ForEach(manager.visibleIndices, id: \.self) { index in
                    let lineBox = manager.lineBoxes[index]
                    let currentLine = textFrame.lines[index]

                    if let separatorColor = properties.separatorColor {
                        let separatorTop = currentLine.origin.y - currentLine.ascent
                        let separatorBottom = separatorTop + currentLine.height
                        let separatorY = separatorBottom.rounded()

                        separatorColor
                            .frame(width: manager.scrollWidth, height: 1)
                            .position(x: manager.scrollWidth / 2.0, y: separatorY)
                    }

                    LineCanvas(
                        currentLine,
                        renderer: manager.renderer,
                        frame: lineBox
                    )
                    .position(x: lineBox.midX, y: lineBox.midY)
                }
                .frame(height: textFrame.height.rounded(.up))
            }
        }
        .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset in
            manager.updateScrollOffset(scrollOffset)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        manager.updateScrollWidth(geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { newValue in
                        manager.updateScrollWidth(newValue)
                    }
            }
            .frame(height: 0)
        }
        .onAppear {
            manager.setupProperties(properties)
        }
        .onChange(of: scrollHeight) { newHeight in
            manager.updateScrollHeight(newHeight)
        }
        .onChange(of: properties) { newProperties in
            manager.updateProperties(newProperties)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}
