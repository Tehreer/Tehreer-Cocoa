//
// Copyright (C) 2021 Muhammad Tayyab Akram
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
import FreeType

class RenderableFace {
    private let mutex = Mutex()

    let ftFace: FT_Face

    init(ftFace: FT_Face) {
        self.ftFace = ftFace
    }

    deinit {
        FreeType.withLibrary { _ -> Void in
            FT_Done_Face(ftFace)
        }
    }

    func withRawFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        mutex.lock()
        defer { mutex.unlock() }

        return try body(ftFace)
    }
}
