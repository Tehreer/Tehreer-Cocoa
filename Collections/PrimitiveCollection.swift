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

    init(_ base: IntrinsicCollection<Element>, startIndex: Int, endIndex: Int) {
        self.base = base
        self.currentIndex = startIndex
        self.endIndex = endIndex
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

    init<Base>(_ base: Base, range: Range<Int>)
        where Base: RandomAccessCollection,
              Base.Index == Int,
              Base.Element == Element {
        self.base = IntrinsicWrapCollection(base: base)
        self.startIndex = range.lowerBound
        self.endIndex = range.upperBound
    }

    init<Base>(_ base: Base)
        where Base: RandomAccessCollection,
              Base.Index == Int,
              Base.Element == Element {
        self.init(base, range: 0 ..< base.count)
    }

    init(_ base: IntrinsicCollection<Element>, range: Range<Int>) {
        self.base = base
        self.startIndex = range.lowerBound
        self.endIndex = range.upperBound
    }

    init(_ base: IntrinsicCollection<Element>) {
        self.init(base, range: 0 ..< base.count)
    }

    public let startIndex: Int
    public let endIndex: Int

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

    public var count: Int {
        return endIndex - startIndex
    }

    public var isEmpty: Bool {
        return startIndex == endIndex
    }

    public var first: Element? {
        return !isEmpty ? base.item(at: startIndex) : nil
    }

    public var last: Element? {
        return !isEmpty ? base.item(at: endIndex - 1) : nil
    }

    public subscript(position: Int) -> Element {
        precondition(
            position >= startIndex && position < endIndex,
            "Index is out of range")

        return base.item(at: position)
    }

    public subscript(bounds: Range<Int>) -> PrimitiveCollection<Element> {
        precondition(
            bounds.lowerBound >= startIndex && bounds.upperBound < endIndex,
            "Index is out of range")

        return PrimitiveCollection(base, range: bounds)
    }

    public func makeIterator() -> PrimitiveIterator<Element> {
        return PrimitiveIterator(base, startIndex: startIndex, endIndex: endIndex)
    }
}
