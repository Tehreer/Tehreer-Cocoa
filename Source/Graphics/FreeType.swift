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

class FreeType {
    private static let instance = FreeType()

    private let mutex = Mutex()
    private var library: FT_Library!

    static func withLibrary<Result>(_ body: (FT_Library) throws -> Result) rethrows -> Result {
        return try instance.mutex.synchronized {
            try body(instance.library)
        }
    }

    private init() {
        FT_Init_FreeType(&library)
    }

    deinit {
        FT_Done_FreeType(library)
    }
}
