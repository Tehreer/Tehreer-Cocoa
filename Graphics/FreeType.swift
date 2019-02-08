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

    static var semaphore: DispatchSemaphore {
        return instance.semaphore
    }

    static var library: FT_Library {
        return instance.library
    }

    private let semaphore = DispatchSemaphore(value: 1)
    private var library: FT_Library!

    private init() {
        FT_Init_FreeType(&library)
    }

    deinit {
        FT_Done_FreeType(library)
    }
}
