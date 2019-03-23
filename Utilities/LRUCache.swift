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

fileprivate class Node<Key, Value> where Key: Hashable {
    let segment: LRUSegment<Key, Value>!
    let key: Key
    var value: Value
    var next: Node<Key, Value>?
    weak var previous: Node<Key, Value>?

    init(segment: LRUSegment<Key, Value>, key: Key, value: Value) {
        self.segment = segment
        self.key = key
        self.value = value
    }

    init(key: Key, value: Value) {
        self.segment = nil
        self.key = key
        self.value = value
    }
}

class LRUSegment<Key, Value> where Key: Hashable {
    let cache: LRUCache<Key, Value>
    private var data: [Key: Node<Key, Value>] = [:]

    init(cache: LRUCache<Key, Value>) {
        self.cache = cache
    }

    func sizeOf(key: Key, value: Value) -> Int {
        return 1
    }

    subscript(key: Key) -> Value? {
        get {
            cache.semaphore.wait()
            defer { cache.semaphore.signal() }

            if let node = data[key] {
                cache.makeFirst(node: node)
                return node.value
            }

            return nil
        }
        set(value) {
            if let value = value {
                cache.semaphore.wait()

                let newNode = Node(segment: self, key: key, value: value)
                let oldNode = data.updateValue(newNode, forKey: key)
                guard oldNode == nil else {
                    fatalError("An entry with same key has already been added")
                }

                cache._size += sizeOf(key: key, value: value)
                cache.addFirst(node: newNode)

                cache.semaphore.signal()

                cache.trim(toSize: cache.capacity)
            } else {
                cache.semaphore.wait()
                defer { cache.semaphore.signal() }

                if let node = data.removeValue(forKey: key) {
                    cache._size -= sizeOf(key: key, value: node.value)
                    cache.remove(node: node)
                }
            }
        }
    }
}

class LRUCache<Key, Value> where Key: Hashable {
    private(set) var semaphore = DispatchSemaphore(value: 1)

    fileprivate var _capacity: Int
    fileprivate var _size: Int

    private let _header: Node<Key, Value>

    init(capacity: Int, dummyPair: (Key, Value)) {
        _capacity = capacity
        _size = 0
        _header = Node(key: dummyPair.0, value: dummyPair.1)
        _header.previous = _header
        _header.next = _header
    }

    private var lastNode: Node<Key, Value> {
        return _header.previous!
    }

    fileprivate func makeFirst(node: Node<Key, Value>) {
        remove(node: node)
        addFirst(node: node)
    }

    fileprivate func addFirst(node: Node<Key, Value>) {
        node.previous = _header
        node.next = _header.next
        _header.next!.previous = node
        _header.next = node
    }

    fileprivate func remove(node: Node<Key, Value>) {
        node.previous!.next = node.next
        node.next!.previous = node.previous
        node.previous = nil
        node.next = nil
    }

    var capacity: Int {
        return _capacity
    }

    var size: Int {
        semaphore.wait()
        defer { semaphore.signal() }

        return _size
    }

    func clear() {
        semaphore.wait()
        defer { semaphore.signal() }

        _header.previous = _header
        _header.next = _header
    }

    func trim(toSize maxSize: Int) {
        while true {
            semaphore.wait()
            defer { semaphore.signal() }

            if _size <= maxSize {
                break
            }

            let toEvict = lastNode
            if toEvict === _header {
                break
            }

            let segment = toEvict.segment!
            let key = toEvict.key
            segment[key] = nil
        }
    }
}
