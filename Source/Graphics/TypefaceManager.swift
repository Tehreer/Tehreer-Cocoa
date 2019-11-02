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

/// The `TypefaceManager` class provides management activities related to typefaces.
public class TypefaceManager {
    public static let `default` = TypefaceManager()

    private let mutex = Mutex()

    private var tags: [TypefaceTag: Typeface] = [:]
    private var typefaces: [Typeface] = []
    private var isSorted = false

    private init() { }

    /// Registers a typeface agains a specified tag. The `typeface` or the `tag` mustn't be already
    /// registered.
    ///
    /// - Parameters:
    ///   - typeface: The typeface that will be registered.
    ///   - tag: An optional tag to identify the typeface.
    public func register(_ typeface: Typeface, forTag tag: TypefaceTag?) {
        mutex.synchronized {
            precondition(!typefaces.contains(where: { $0 === typeface }), "This typeface is already registered")

            if let tag = tag {
                precondition(tags.index(forKey: tag) == nil, "This tag is already taken")

                tags[tag] = typeface
                typeface.tag = tag
            }

            isSorted = false
            typefaces.append(typeface)
        }
    }

    /// Unregisters a typeface if it was previously registered.
    ///
    /// - Parameter typeface: The typeface to unregister.
    public func unregister(_ typeface: Typeface) {
        mutex.synchronized {
            if let index = typefaces.firstIndex(where: { $0 === typeface }) {
                typefaces.remove(at: index)
            }

            if let tag = typeface.tag {
                tags.removeValue(forKey: tag)
                typeface.tag = nil
            }
        }
    }

    /// Returns the typeface registered against the specified tag.
    ///
    /// - Parameter tag: The tag that identifies the typeface.
    /// - Returns: The registered typeface, or `nil` if no typeface is registered against the
    ///            specified tag.
    public func typeface(forTag tag: TypefaceTag) -> Typeface? {
        return mutex.synchronized {
            tags[tag]
        }
    }

    /// Returns the tag of a registered typeface.
    ///
    /// - Parameter typeface: The typeface whose tag is returned.
    /// - Returns: The tag of the typeface, or `nil` if it is not registered, or no tag was
    ///            specified while registration.
    public func tag(of typeface: Typeface) -> TypefaceTag? {
        return mutex.synchronized {
            typeface.tag
        }
    }

    /// Looks for a registered typeface having the specified full name.
    ///
    /// - Parameter fullName: The full name of the typeface.
    /// - Returns: The typeface having the specified full name, or `nil` if no such typeface is
    ///            registered.
    public func typeface(byName fullName: String) -> Typeface? {
        return mutex.synchronized {
            for typeface in typefaces {
                if typeface.fullName.compare(fullName,
                                             options: [.caseInsensitive],
                                             range: nil, locale: nil) == .orderedSame {
                    return typeface
                }
            }

            return nil
        }
    }

    /// The array of available typefaces sorted by their names in ascending order.
    public var availableTypefaces: [Typeface] {
        return mutex.synchronized {
            sortTypefacesIfNeeded()

            return typefaces
        }
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
