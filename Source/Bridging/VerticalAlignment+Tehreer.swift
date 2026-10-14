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

extension VerticalAlignment {
    init(coreValue: TRVerticalAlignment) {
        switch coreValue {
        case TRVerticalAlignment(TRVerticalAlignmentCenter):
            self = .middle
        case TRVerticalAlignment(TRVerticalAlignmentBottom):
            self = .bottom
        default:
            self = .top
        }
    }

    var coreValue: TRVerticalAlignment {
        switch self {
        case .top:
            return TRVerticalAlignment(TRVerticalAlignmentTop)
        case .middle:
            return TRVerticalAlignment(TRVerticalAlignmentCenter)
        case .bottom:
            return TRVerticalAlignment(TRVerticalAlignmentBottom)
        }
    }
}
