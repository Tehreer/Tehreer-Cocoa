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

import Foundation

/// A value that is made the first time it is asked for, and then kept. It is thread safe: the value
/// is made once, even if several threads ask for it at the same time.
final class Lazy<Value>: @unchecked Sendable {
    private let mutex = Mutex()
    private var stored: Value?

    init() { }

    /// Returns the value, making it with the closure if it was not made yet.
    func get(_ make: () -> Value) -> Value {
        return mutex.synchronized {
            if let stored = stored {
                return stored
            }

            let value = make()
            stored = value

            return value
        }
    }
}
