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

import Foundation
import CoreGraphics

protocol Scalable {
    associatedtype Output

    static func *(value: Self, scale: CGFloat) -> Output
}

extension Int32: Scalable {
    typealias Output = CGFloat

    static func *(value: Int32, scale: CGFloat) -> CGFloat {
        return CGFloat(value) * scale
    }
}

extension SFPoint: Scalable {
    typealias Output = CGPoint

    static func *(value: SFPoint, scale: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat(value.x) * scale,
                       y: CGFloat(value.y) * scale)
    }
}
