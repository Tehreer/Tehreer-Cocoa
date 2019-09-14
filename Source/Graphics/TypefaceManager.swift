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

public class TypefaceManager {
    public static let shared = TypefaceManager()

    private let semaphore = DispatchSemaphore(value: 1)

    private var tags: [TypefaceTag: Typeface] = [:]
    private var typefaces: [Typeface] = []
    private var isSorted = false

    private init() { }

    public func register(_ typeface: Typeface, for tag: TypefaceTag) {
        semaphore.wait()
        defer { semaphore.signal() }

        precondition(!typefaces.contains(where: { $0 === typeface }), "This typeface is already registered")
        precondition(tags.index(forKey: tag) == nil, "This tag is already taken")

        tags[tag] = typeface
        typeface.tag = tag

        isSorted = false
        typefaces.append(typeface)
    }

    public func unregister(_ typeface: Typeface) {
        semaphore.wait()
        defer { semaphore.signal() }

        if let index = typefaces.firstIndex(where: { $0 === typeface }) {
            typefaces.remove(at: index)
        }

        if let tag = typeface.tag {
            tags.removeValue(forKey: tag)
            typeface.tag = nil
        }
    }

    public func typeface(for tag: TypefaceTag) -> Typeface? {
        semaphore.wait()
        defer { semaphore.signal() }

        return tags[tag]
    }

    public func tag(of typeface: Typeface) -> TypefaceTag? {
        semaphore.wait()
        defer { semaphore.signal() }

        return typeface.tag
    }

    public var availableTypefaces: [Typeface] {
        semaphore.wait()
        defer { semaphore.signal() }

        sortTypefacesIfNeeded()

        return typefaces
    }

    private func sortTypefacesIfNeeded() {
        if !isSorted {
            typefaces.sort { (first, second) -> Bool in
                var result = first.familyName.compare(second.familyName,
                                                      options: [.caseInsensitive],
                                                      range: nil, locale: nil)

                if result == .orderedSame {
                    result = first.styleName.compare(second.styleName,
                                                     options: [.caseInsensitive],
                                                     range: nil, locale: nil)
                }

                return result == .orderedAscending
            }

            isSorted = true
        }
    }
}
