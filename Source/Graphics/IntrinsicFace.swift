//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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

import CoreGraphics
import Foundation
import FreeType
import UIKit

class IntrinsicFace {
    private let mutex = Mutex()

    var renderableFace: RenderableFace!
    var ftSize: FT_Size!
    var ftStroker: FT_Stroker!

    var shapableFace: ShapableFace!

    private struct Description {
        var familyIndex: Int?
        var styleIndex: Int?
        var fullIndex: Int?

        var weight: Typeface.Weight = .regular
        var width: Typeface.Width = .normal
        var slope: Typeface.Slope = .plain
    }

    private struct DefaultProperties {
        var description = Description()

        var variationAxes: [VariationAxis] = []
        var paletteEntryNames: [String] = []
        var predefinedPalettes: [ColorPalette] = []
    }

    private var defaults = DefaultProperties()
    private var description = Description()

    var familyName = ""
    var styleName = ""
    var fullName = ""

    var strikeoutPosition: Int = 0
    var strikeoutThickness: Int = 0

    init?(fontStream: FontStream, faceIndex: Int) {
        guard let renderableFace = fontStream.makeRenderableFace(faceIndex: faceIndex) else {
            return nil
        }

        setupFull(renderableFace: renderableFace)
    }

    init(renderableFace: RenderableFace) {
        setupFull(renderableFace: renderableFace)
    }

    private init?(parent: IntrinsicFace, renderableFace: RenderableFace) {
        setupDerived(parent: parent, renderableFace: renderableFace)
    }

    private func setupFull(renderableFace: RenderableFace) {
        self.renderableFace = renderableFace

        let ftFace = renderableFace.ftFace
        let headTable = HeadTable(ftFace: ftFace)
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        setupAxes(nameTable: nameTable)
        setupCoordinates()
        setupPalettes(nameTable: nameTable)
        setupSize()
        setupDescription(headTable: headTable, os2Table: os2Table, nameTable: nameTable)
        setupStrikeout(os2Table: os2Table)
        setupVariation()
        setupHarfBuzz()
        setupNames(nameTable: nameTable)
    }

    private func setupDerived(parent: IntrinsicFace, renderableFace: RenderableFace) {
        self.renderableFace = renderableFace
        self.defaults = parent.defaults

        let ftFace = renderableFace.ftFace
        let os2Table = OS2Table(ftFace: ftFace)
        let nameTable = NameTable(ftFace: ftFace)

        setupSize()
        setupStrikeout(os2Table: os2Table)
        setupVariation()
        setupHarfBuzz(parent: parent)
        setupNames(nameTable: nameTable)
    }

    private func setupSize() {
        FT_New_Size(renderableFace.ftFace, &ftSize)
    }

    private func setupDescription(headTable: HeadTable?, os2Table: OS2Table?, nameTable: NameTable?) {
        var description = Description()
        description.familyIndex = nameTable?.indexOfFamilyName(considering: os2Table)
        description.styleIndex = nameTable?.indexOfStyleName(considering: os2Table)
        description.fullIndex = nameTable?.indexOfEnglishName(for: NameTable.NameID.full)

        defer {
            defaults.description = description
            self.description = description
        }

        if let os2Table = os2Table {
            description.weight = Typeface.Weight(value: os2Table.usWeightClass)
            description.width = Typeface.Width(value: os2Table.usWidthClass)

            if (os2Table.fsSelection & OS2Table.FSSelection.oblique) != 0 {
                description.slope = .oblique
            } else if (os2Table.fsSelection & OS2Table.FSSelection.italic) != 0 {
                description.slope = .italic
            }
        } else if let headTable = headTable {
            let macStyle = headTable.macStyle

            if (macStyle & OS2Table.MacStyle.bold) != 0 {
                description.weight = .bold
            }

            if (macStyle & OS2Table.MacStyle.condensed) != 0 {
                description.width = .condensed
            } else if (macStyle & OS2Table.MacStyle.extended) != 0 {
                description.width = .expanded
            }

            if (macStyle & OS2Table.MacStyle.italic) != 0 {
                description.slope = .italic
            }
        }
    }

    private func setupStrikeout(os2Table: OS2Table?) {
        if let os2Table = os2Table {
            strikeoutPosition = Int(os2Table.yStrikeoutPosition)
            strikeoutThickness = Int(os2Table.yStrikeoutSize)
        }
    }

    private func setupVariation() {
        let ftFace = renderableFace.ftFace
        var variation: UnsafeMutablePointer<FT_MM_Var>!

        guard FT_Get_MM_Var(ftFace, &variation) == FT_Err_Ok else { return }

        defer {
            FreeType.withLibrary { (library) -> Void in
                FT_Done_MM_Var(library, variation)
            }
        }

        var description = defaults.description
        defer { self.description = description }

        let numCoords = variation.pointee.num_axis
        var fixedCoords = Array<FT_Fixed>(repeating: 0, count: Int(numCoords))

        if FT_Get_Var_Design_Coordinates(ftFace, numCoords, &fixedCoords) == FT_Err_Ok {
            let nameTable = NameTable(ftFace: ftFace)

            // Reset the style name and the full name.
            description.styleIndex = nil
            description.fullIndex = nil

            // Get the style name of this instance.
            for i in 0 ..< Int(variation.pointee.num_namedstyles) {
                let namedStyle = variation.pointee.namedstyle[i]
                guard let namedCoords = namedStyle.coords else {
                    continue
                }

                let areEqual = fixedCoords.withUnsafeBufferPointer { (pointer) -> Bool in
                    guard let baseAddress = pointer.baseAddress else {
                        return false
                    }

                    let lhs = UnsafeRawPointer(namedCoords)
                    let rhs = UnsafeRawPointer(baseAddress)
                    let size = MemoryLayout<FT_Fixed>.size * Int(numCoords)

                    return memcmp(lhs, rhs, size) == 0
                }

                if areEqual {
                    description.styleIndex = nameTable?.indexOfEnglishName(for: UInt16(namedStyle.strid))
                    break
                }
            }

            // Get the values of variation axes.
            for i in 0 ..< Int(numCoords) {
                let axis = variation.pointee.axis[i]

                switch axis.tag {
                case FT_ULong(SFNTTag(stringLiteral: "ital").rawValue):
                    description.slope = Typeface.Slope(ital: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "slnt").rawValue):
                    description.slope = Typeface.Slope(slnt: fixedCoords[i])
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wdth").rawValue):
                    description.width = Typeface.Width(wdth: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                case FT_ULong(SFNTTag(stringLiteral: "wght").rawValue):
                    description.weight = Typeface.Weight(wght: CGFloat(f16Dot16: fixedCoords[i]))
                    break

                default:
                    break
                }
            }
        }
    }

    private func setupHarfBuzz(parent: IntrinsicFace? = nil) {
        if let parent = parent {
            shapableFace = ShapableFace(parent: parent.shapableFace, renderableFace: renderableFace)
        } else {
            shapableFace = ShapableFace(renderableFace: renderableFace)
        }
    }

    private func setupAxes(nameTable: NameTable?) {
        guard let fvarTable = renderableFace.fvarTable() else { return }

        let axisRecords = fvarTable.axisRecords

        var variationAxes: [VariationAxis] = []
        variationAxes.reserveCapacity(axisRecords.count)

        defer {
            defaults.variationAxes = variationAxes
        }

        for axisRecord in axisRecords {
            let axisTag: SFNTTag! = SFNTTag(rawValue: axisRecord.axisTag)
            let minValue = CGFloat(axisRecord.minValue)
            let defaultValue = CGFloat(axisRecord.defaultValue)
            let maxValue = CGFloat(axisRecord.maxValue)
            let flags = VariationAxis.Flags(rawValue: Int(axisRecord.flags))
            let axisNameId = axisRecord.axisNameId

            var axisName = ""

            if let index = nameTable?.indexOfEnglishName(for: axisNameId) {
                axisName = nameTable?.record(at: index).string ?? ""
            }

            let variationAxis = VariationAxis(tag: axisTag, name: axisName, flags: flags,
                                              defaultValue: defaultValue,
                                              minValue: minValue, maxValue: maxValue)

            variationAxes.append(variationAxis)
        }
    }

    private func setupCoordinates() {
        if !variationAxes.isEmpty {
            renderableFace.setupCoordinates(variationAxes.map { $0.defaultValue })
        }
    }

    private func setupPalettes(nameTable: NameTable?) {
        guard let cpalTable = renderableFace.cpalTable() else { return }

        let numPaletteEntries = Int(cpalTable.numPaletteEntries)
        let numPalettes = Int(cpalTable.numPalettes)

        let colorRecords = cpalTable.colorRecords
        let paletteTypes = cpalTable.paletteTypes
        let paletteLabels = cpalTable.paletteLabels
        let paletteEntryLabels = cpalTable.paletteEntryLabels

        var predefinedPalettes: [ColorPalette] = []
        predefinedPalettes.reserveCapacity(numPalettes)

        defer {
            defaults.predefinedPalettes = predefinedPalettes
        }

        /* Populate predefined palettes. */
        for i in 0 ..< numPalettes {
            var name = ""
            var flags: ColorPalette.Flags = []
            var colors: [UIColor] = []

            if let paletteLabels = paletteLabels {
                let nameID = paletteLabels[i]

                if nameID != 0xFFFF {
                    if let index = nameTable?.indexOfEnglishName(for: nameID) {
                        name = nameTable?.record(at: index).string ?? ""
                    }
                }
            }

            if let paletteTypes = paletteTypes {
                flags = ColorPalette.Flags(rawValue: Int(paletteTypes[i]))
            }

            let firstColorIndex = cpalTable.colorRecordIndex(at: i)
            for j in 0 ..< numPaletteEntries {
                let record = colorRecords[Int(firstColorIndex) + j]

                colors.append(UIColor(red: CGFloat(record.red) / 255.0,
                                      green: CGFloat(record.green) / 255.0,
                                      blue: CGFloat(record.blue) / 255.0,
                                      alpha: CGFloat(record.alpha) / 255.0))
            }

            predefinedPalettes.append(ColorPalette(name: name, flags: flags, colors: colors))
        }

        var paletteEntryNames: [String] = []
        paletteEntryNames.reserveCapacity(numPaletteEntries)

        defer {
            defaults.paletteEntryNames = paletteEntryNames
        }

        // Populate palette entry names.
        if let paletteEntryLabels = paletteEntryLabels {
            for i in 0 ..< numPaletteEntries {
                let nameID = paletteEntryLabels[i]
                var name = ""

                if nameID != 0xFFFF {
                    if let index = nameTable?.indexOfEnglishName(for: nameID) {
                        name = nameTable?.record(at: index).string ?? ""
                    }
                }

                paletteEntryNames.append(name)
            }
        } else {
            for _ in 0 ..< numPaletteEntries {
                paletteEntryNames.append("")
            }
        }
    }

    private func setupNames(nameTable: NameTable?) {
        guard let nameTable = nameTable else { return }

        if let index = description.familyIndex {
            familyName = nameTable.record(at: index).string ?? ""
        }
        if let index = description.styleIndex {
            styleName = nameTable.record(at: index).string ?? ""
        }
        if let index = description.fullIndex {
            fullName = nameTable.record(at: index).string ?? ""
        } else {
            if !familyName.isEmpty {
                fullName = familyName
                if !styleName.isEmpty {
                    fullName += " " + styleName
                }
            }
        }
    }

    deinit {
        withFreeTypeFace { _ -> Void in
            FT_Done_Size(ftSize)
        }

        if ftStroker != nil {
            FT_Stroker_Done(ftStroker)
        }
    }

    func withFreeTypeFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        return try renderableFace.withRawFace(body)
    }

    func withFreeTypeStroker<Result>(_ body: (FT_Stroker) throws -> Result) rethrows -> Result {
        mutex.lock()
        defer { mutex.unlock() }

        if ftStroker == nil {
            FreeType.withLibrary { (library) -> Void in
                if ftStroker == nil {
                    FT_Stroker_New(library, &ftStroker)
                }
            }
        }

        return try body(ftStroker)
    }

    var variationAxes: [VariationAxis] {
        return defaults.variationAxes
    }

    var paletteEntryNames: [String] {
        return defaults.paletteEntryNames
    }

    var predefinedPalettes: [ColorPalette] {
        return defaults.predefinedPalettes
    }

    var weight: Typeface.Weight {
        return description.weight
    }

    var width: Typeface.Width {
        return description.width
    }

    var slope: Typeface.Slope {
        return description.slope
    }

    func glyphID(forCodePoint codePoint: UTF32Char) -> GlyphID {
        let glyphID = withFreeTypeFace { (face) in
            FT_Get_Char_Index(face, FT_ULong(codePoint))
        }

        guard glyphID <= 0xFFFF else {
            print("Received invalid glyph id for code point: \(codePoint)")
            return 0
        }

        return GlyphID(glyphID)
    }

    var isVariable: Bool {
        return !variationAxes.isEmpty
    }

    func variationInstance(forCoordinates coordinates: [CGFloat]) -> IntrinsicFace? {
        guard isVariable else {
            return nil
        }

        var coordArray = Array<CGFloat>(repeating: 0, count: variationAxes.count)
        let coordCount = min(coordinates.count, variationAxes.count)

        for i in 0 ..< coordCount {
            coordArray[i] = coordinates[i]
        }

        guard let derivedFace = renderableFace.variationInstance(forCoordinates: coordArray) else {
            return nil
        }

        return IntrinsicFace(parent: self, renderableFace: derivedFace)
    }

    var variationCoordinates: [CGFloat] {
        return renderableFace.coordinates
    }
}
