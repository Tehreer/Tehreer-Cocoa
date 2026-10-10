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

extension TextAlignment {
    var coreValue: TRTextAlignment {
        switch self {
        case .left:
            return TRTextAlignment(TRTextAlignmentLeft)
        case .center:
            return TRTextAlignment(TRTextAlignmentCenter)
        case .right:
            return TRTextAlignment(TRTextAlignmentRight)
        case .leading:
            return TRTextAlignment(TRTextAlignmentLeading)
        case .trailing:
            return TRTextAlignment(TRTextAlignmentTrailing)
        }
    }

    init(coreValue: TRTextAlignment) {
        switch coreValue {
        case TRTextAlignment(TRTextAlignmentLeft):
            self = .left
        case TRTextAlignment(TRTextAlignmentCenter):
            self = .center
        case TRTextAlignment(TRTextAlignmentRight):
            self = .right
        case TRTextAlignment(TRTextAlignmentTrailing):
            self = .trailing
        default:
            self = .leading
        }
    }
}
