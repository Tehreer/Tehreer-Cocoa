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

public struct PrimitiveIterator<Element>: IteratorProtocol {
    let base: IntrinsicCollection<Element>

    private var currentIndex: Int
    private let endIndex: Int

    init(_ base: IntrinsicCollection<Element>, offset: Int, count: Int) {
        self.base = base
        self.currentIndex = offset
        self.endIndex = offset + count
    }

    public mutating func next() -> Element? {
        if currentIndex != endIndex {
            defer {
                currentIndex += 1
            }

            return base.item(at: currentIndex)
        }

        return nil
    }
}

public struct PrimitiveCollection<Element>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Iterator = PrimitiveIterator<Element>
    public typealias SubSequence = PrimitiveCollection<Element>

    let base: IntrinsicCollection<Element>

    private let offset: Int
    public let count: Int

    init<Base>(_ base: Base, range: Range<Int>)
        where Base: RandomAccessCollection,
              Base.Index == Int,
              Base.Element == Element {
        self.init(IntrinsicWrapCollection(base: base), range: range)
    }

    init<Base>(_ base: Base)
        where Base: RandomAccessCollection,
              Base.Index == Int,
              Base.Element == Element {
        self.init(base, range: 0 ..< base.count)
    }

    init(_ base: IntrinsicCollection<Element>, range: Range<Int>) {
        self.base = base
        self.offset = range.lowerBound
        self.count = range.count
    }

    init(_ base: IntrinsicCollection<Element>) {
        self.init(base, range: 0 ..< base.count)
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return count
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func formIndex(after i: inout Int) {
        i += 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }

    public func formIndex(before i: inout Int) {
        i -= 1
    }

    public func index(_ i: Int, offsetBy n: Int) -> Int {
        return i + n
    }

    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        let distance = i + n
        if n > 0 ? (i > limit || distance <= limit) : (i < limit || distance >= limit) {
            return distance
        }

        return nil
    }

    public func distance(from start: Int, to end: Int) -> Int {
        return end - start
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public var first: Element? {
        return !isEmpty ? base.item(at: offset) : nil
    }

    public var last: Element? {
        return !isEmpty ? base.item(at: offset + count - 1) : nil
    }

    public subscript(position: Int) -> Element {
        precondition(
            position >= 0 && position < count,
            "Index is out of range")

        return base.item(at: position + offset)
    }

    public subscript(bounds: Range<Int>) -> PrimitiveCollection<Element> {
        precondition(
            bounds.lowerBound >= 0 && bounds.upperBound <= count,
            "Index is out of range")

        return PrimitiveCollection(base, range: bounds.lowerBound + offset ..< bounds.upperBound + offset)
    }

    public func makeIterator() -> PrimitiveIterator<Element> {
        return PrimitiveIterator(base, offset: offset, count: count)
    }
}
