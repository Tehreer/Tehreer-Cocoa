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

extension Renderer.DrawStyle {
    var coreValue: TRDrawStyle {
        switch self {
        case .fill:
            return TRDrawStyle(TRDrawStyleFill)
        case .stroke:
            return TRDrawStyle(TRDrawStyleStroke)
        case .fillStroke:
            return TRDrawStyle(TRDrawStyleFillStroke)
        }
    }
}

extension Renderer.StrokeCap {
    var coreValue: TRStrokeCap {
        return TRStrokeCap(rawValue)
    }
}

extension Renderer.StrokeJoin {
    var coreValue: TRStrokeJoin {
        return TRStrokeJoin(rawValue)
    }
}
