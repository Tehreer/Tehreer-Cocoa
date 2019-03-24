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

class BidiBuffer {
    private var source: CFString!
    private var buffer: UnsafeMutablePointer<UniChar>!

    let string: String
    let data: UnsafePointer<Unicode.UTF16.CodeUnit>
    let length: Int

    init(_ string: String) {
        let source = string as CFString

        self.string = string
        self.length = CFStringGetLength(source)

        if let data = CFStringGetCharactersPtr(source) {
            self.source = source
            self.data = data
        } else {
            self.buffer = UnsafeMutablePointer<UniChar>.allocate(capacity: length)
            CFStringGetCharacters(source, CFRangeMake(0, length), buffer)
            
            self.data = UnsafePointer<UInt16>(buffer)
        }
    }

    deinit {
        if let buffer = buffer {
            buffer.deallocate()
        }
    }
}
