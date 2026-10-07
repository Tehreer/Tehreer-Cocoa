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

/// A collection that reads the elements that Core keeps for an object, such as the glyphs of a run.
/// It owns what the elements belong to, so that they stay valid for as long as it is used.
final class CoreCollection<Owner: AnyObject, Raw, Element>: IntrinsicCollection<Element> {
    private let owner: Owner
    private let pointer: UnsafePointer<Raw>?
    private let length: Int
    private let convert: (Raw) -> Element

    init(owner: Owner, pointer: UnsafePointer<Raw>?, count: Int, convert: @escaping (Raw) -> Element) {
        self.owner = owner
        self.pointer = pointer
        self.length = count
        self.convert = convert
    }

    override var count: Int {
        return length
    }

    override func item(at index: Int) -> Element {
        precondition(index >= 0 && index < length, "Index is out of range")

        return convert(pointer![index])
    }
}
