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

internal import Tehreer

import Foundation

/// The `TypefaceManager` class provides management activities related to typefaces. The registry
/// itself lives in Tehreer Core, which identifies typefaces by integer tags, groups them into
/// families and picks the typeface of a family that is closest to a requested width, weight and
/// slope, as described by CSS Fonts Level 4.
public final class TypefaceManager: Sendable {
    public static let `default` = TypefaceManager()

    // Core hands out the typefaces that it registered, and this maps them back to the objects that
    // were registered. It also keeps those objects alive.
    private let registered = Locked([TRTypefaceRef: Typeface]())

    private init() { }

    /// Registers a typeface against a tag and a family ID. The `typeface` mustn't be already
    /// registered, and the `tag` mustn't be already taken.
    ///
    /// - Parameters:
    ///   - typeface: The typeface that will be registered.
    ///   - tag: An optional positive tag to identify the typeface, or zero for none.
    ///   - familyID: An optional positive ID of the family that the typeface belongs to, or zero to
    ///               group it with the typefaces that have no family ID and the same font family
    ///               name.
    public func register(
        _ typeface: Typeface,
        forTag tag: TypefaceTag = 0,
        familyID: TypeFamilyID = 0
    ) {
        precondition(tag >= 0, "The tag is negative")
        precondition(familyID >= 0, "The family ID is negative")

        registered.withLock { (registered) in
            let isRegistered = TRTypefaceManagerRegisterTypeface(
                typeface.core,
                TRUInteger(tag),
                TRUInteger(familyID)
            ) != 0

            precondition(
                isRegistered,
                "This typeface is already registered, or the tag is already taken"
            )

            registered[typeface.core] = typeface
        }
    }

    /// Unregisters a typeface if it was previously registered.
    ///
    /// - Parameter typeface: The typeface to unregister.
    public func unregister(_ typeface: Typeface) {
        registered.withLock { (registered) in
            if TRTypefaceManagerUnregisterTypeface(typeface.core) != 0 {
                registered.removeValue(forKey: typeface.core)
            }
        }
    }

    /// Returns the typeface registered against the specified tag.
    ///
    /// - Parameter tag: The tag that identifies the typeface.
    /// - Returns: The registered typeface, or `nil` if no typeface is registered against the
    ///            specified tag.
    public func typeface(forTag tag: TypefaceTag) -> Typeface? {
        guard tag > 0 else {
            return nil
        }

        return registered.withLock { (registered) in
            TRTypefaceManagerGetTypeface(TRUInteger(tag)).flatMap { registered[$0] }
        }
    }

    /// Returns the tag of a registered typeface.
    ///
    /// - Parameter typeface: The typeface whose tag is returned.
    /// - Returns: The tag of the typeface, or zero if it is not registered, or no tag was specified
    ///            while registration.
    public func tag(of typeface: Typeface) -> TypefaceTag {
        return TypefaceTag(TRTypefaceManagerGetTypefaceTag(typeface.core))
    }

    /// Returns the ID of the family that a registered typeface belongs to.
    ///
    /// - Parameter typeface: The typeface whose family ID is returned.
    /// - Returns: The ID of the family, or zero if the typeface is not registered, or no family ID
    ///            was specified while registration.
    public func familyID(of typeface: Typeface) -> TypeFamilyID {
        return TypeFamilyID(TRTypefaceManagerGetTypefaceFamilyID(typeface.core))
    }

    /// Looks for a registered typeface having the specified full name.
    ///
    /// - Parameter fullName: The full name of the typeface.
    /// - Returns: The typeface having the specified full name, or `nil` if no such typeface is
    ///            registered.
    public func typeface(byName fullName: String) -> Typeface? {
        return availableTypefaces.first {
            $0.fullName.compare(
                fullName,
                options: [.caseInsensitive],
                range: nil,
                locale: nil
            ) == .orderedSame
        }
    }

    /// Returns the typeface of a family that is closest to the specified style, as described by CSS
    /// Fonts Level 4.
    ///
    /// - Parameters:
    ///   - familyID: The ID of the family.
    ///   - width: The typographic width of the desired typeface.
    ///   - weight: The typographic weight of the desired typeface.
    ///   - slope: The typographic slope of the desired typeface.
    /// - Returns: The best matching typeface, or `nil` if the ID is zero or the family has no
    ///            typefaces.
    public func typeface(
        forFamilyID familyID: TypeFamilyID,
        width: Typeface.Width,
        weight: Typeface.Weight,
        slope: Typeface.Slope
    ) -> Typeface? {
        guard familyID > 0 else {
            return nil
        }

        return registered.withLock { (registered) in
            TRTypefaceManagerGetMatchingTypefaceByFamilyID(
                TRUInteger(familyID),
                width.coreValue,
                weight.coreValue,
                slope.coreValue
            ).flatMap { registered[$0] }
        }
    }

    /// Returns the typeface of a family that is closest to the specified style, as described by CSS
    /// Fonts Level 4.
    ///
    /// - Parameters:
    ///   - familyName: The name of the family, which is matched ignoring the case.
    ///   - width: The typographic width of the desired typeface.
    ///   - weight: The typographic weight of the desired typeface.
    ///   - slope: The typographic slope of the desired typeface.
    /// - Returns: The best matching typeface, or `nil` if no typeface has the family name.
    public func typeface(
        forFamilyName familyName: String,
        width: Typeface.Width,
        weight: Typeface.Weight,
        slope: Typeface.Slope
    ) -> Typeface? {
        let byName = registered.withLock { (registered) in
            familyName.withCoreView { (view) in
                TRTypefaceManagerGetMatchingTypefaceByFamilyName(
                    view,
                    width.coreValue,
                    weight.coreValue,
                    slope.coreValue
                ).flatMap { registered[$0] }
            }
        }

        if let byName = byName {
            return byName
        }

        // The typefaces that have a family ID are not matched by the name of their family.
        let family = availableFamilies.first {
            $0.familyID != 0 && $0.familyName.compare(
                familyName,
                options: [.caseInsensitive],
                range: nil,
                locale: nil
            ) == .orderedSame
        }

        return family.flatMap {
            typeface(forFamilyID: $0.familyID, width: width, weight: weight, slope: slope)
        }
    }

    /// The array of available typefaces sorted by their family names and then by their style names
    /// in ascending order.
    public var availableTypefaces: [Typeface] {
        return registered.withLock { (registered) in
            var cores: [TRTypefaceRef] = []

            withUnsafeMutablePointer(to: &cores) { (pointer) in
                TRTypefaceManagerEnumerateTypefaces(
                    { (typeface, context, _) in
                                                                                                                                                                                                                            context!.assumingMemoryBound(to: [TRTypefaceRef].self).pointee.append(typeface!)
                                                                                                                                                                                                                        },
                    pointer
                )
            }

            return cores.compactMap { registered[$0] }
        }
    }

    /// The array of available families sorted by their names in ascending order.
    public var availableFamilies: [TypeFamily] {
        struct Entry {
            var familyID: TypeFamilyID
            var familyName: String
        }

        var entries: [Entry] = []

        withUnsafeMutablePointer(to: &entries) { (pointer) in
            TRTypefaceManagerEnumerateFamilies(
                { (familyID, familyName, context, _) in
                    context!.assumingMemoryBound(to: [Entry].self).pointee.append(
                        Entry(
                            familyID: TypeFamilyID(familyID),
                            familyName: String(familyName)
                        )
                    )
                },
                pointer
            )
        }

        let typefaces = availableTypefaces

        return entries.compactMap { (entry) in
            let members = typefaces.filter { (typeface) in
                let memberID = familyID(of: typeface)

                if entry.familyID != 0 {
                    return memberID == entry.familyID
                }

                return memberID == 0 && typeface.familyName.compare(
                    entry.familyName,
                    options: [.caseInsensitive],
                    range: nil,
                    locale: nil
                ) == .orderedSame
            }

            return members.isEmpty ? nil : TypeFamily(
                familyName: entry.familyName,
                familyID: entry.familyID,
                typefaces: members
            )
        }
    }
}
