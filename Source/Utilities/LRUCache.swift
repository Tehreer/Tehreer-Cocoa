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

private class Node<Key, Value> where Key: Hashable {
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

    func value(forKey key: Key) -> Value? {
        if let node = data[key] {
            cache.makeFirst(node: node)
            return node.value
        }

        return nil
    }

    func setValue(_ value: Value?, forKey key: Key) {
        guard let value = value else {
            removeValue(forKey: key)
            return
        }

        let newNode = Node(segment: self, key: key, value: value)
        let oldNode = data.updateValue(newNode, forKey: key)
        guard oldNode == nil else {
            fatalError("An entry with same key has already been added")
        }

        cache.size += sizeOf(key: key, value: value)
        cache.addFirst(node: newNode)

        cache.trim(toSize: cache.capacity)
    }

    func removeValue(forKey key: Key) {
        if let node = data.removeValue(forKey: key) {
            cache.size -= sizeOf(key: key, value: node.value)
            cache.remove(node: node)
        }
    }
}

class LRUCache<Key, Value> where Key: Hashable {
    fileprivate(set) var capacity: Int
    fileprivate(set) var size: Int

    private let head: Node<Key, Value>

    init(capacity: Int, dummyPair: (Key, Value)) {
        self.capacity = capacity
        self.size = 0

        head = Node(key: dummyPair.0, value: dummyPair.1)
        head.previous = head
        head.next = head
    }

    private var lastNode: Node<Key, Value> {
        return head.previous!
    }

    fileprivate func makeFirst(node: Node<Key, Value>) {
        remove(node: node)
        addFirst(node: node)
    }

    fileprivate func addFirst(node: Node<Key, Value>) {
        node.previous = head
        node.next = head.next
        head.next!.previous = node
        head.next = node
    }

    fileprivate func remove(node: Node<Key, Value>) {
        node.previous!.next = node.next
        node.next!.previous = node.previous
        node.previous = nil
        node.next = nil
    }

    func clear() {
        head.previous = head
        head.next = head
    }

    func trim(toSize maxSize: Int) {
        while size > maxSize {
            let toEvict = lastNode
            if toEvict === head {
                break
            }

            let segment = toEvict.segment!
            let key = toEvict.key

            segment.removeValue(forKey: key)
        }
    }
}
