//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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

struct Mutex: Sendable {
    private let semaphore = DispatchSemaphore(value: 1)

    func lock() {
        semaphore.wait()
    }

    func unlock() {
        semaphore.signal()
    }

    @discardableResult
    func synchronized<Result>(_ closure: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }

        return try closure()
    }
}

/// A value that can be accessed only while holding its lock.
final class Locked<Value>: @unchecked Sendable {
    // The value is non-Sendable in general, so Sendable is asserted here once: every access goes
    // through `withLock`, which serializes it.
    private let mutex = Mutex()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        return try mutex.synchronized {
            try body(&value)
        }
    }
}
