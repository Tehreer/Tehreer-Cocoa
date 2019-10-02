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

struct PatternKey: Hashable {
    let scriptTag: SFNTTag
    let languageTag: SFNTTag
    let featureTags: [UInt32]
    let featureValues: [UInt16]
}

fileprivate class PatternValue {
    let sfPattern: SFPatternRef

    init(_ sfPattern: SFPatternRef) {
        self.sfPattern = SFPatternRetain(sfPattern)
    }

    deinit {
        SFPatternRelease(sfPattern)
    }
}

class PatternCache {
    private let mutex = Mutex()
    private var patterns = Dictionary<PatternKey, PatternValue>()

    subscript(key: PatternKey) -> SFPatternRef? {
        get {
            return mutex.synchronized {
                if let index = patterns.index(forKey: key) {
                    return patterns[index].value.sfPattern
                }

                return nil
            }
        }
        set {
            mutex.synchronized {
                patterns[key] = newValue != nil ? PatternValue(newValue!) : nil
            }
        }
    }
}
