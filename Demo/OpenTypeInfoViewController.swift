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

import TehreerCocoa
import UIKit

private struct ClusterDetail {
    let codePoints: [UnicodeScalar]
    let glyphIDs: Slice<ShapingResult.GlyphIDs>
    let glyphOffsets: Slice<ShapingResult.GlyphOffsets>
    let glyphAdvances: Slice<ShapingResult.GlyphAdvances>
}

private struct TextDetail {
    let string: String
    let glyphIDs: ShapingResult.GlyphIDs
    let glyphOffsets: ShapingResult.GlyphOffsets
    let glyphAdvances: ShapingResult.GlyphAdvances
    let clusterMap: ShapingResult.ClusterMap
    let clusterInitials: [Int]

    var clusterCount: Int {
        return clusterInitials.count - 1
    }

    func clusterDetail(at index: Int) -> ClusterDetail {
        let codeUnitStart = clusterInitials[index]
        let codeUnitEnd = clusterInitials[index + 1]

        let characterStart = string.utf16.index(string.startIndex, offsetBy: codeUnitStart)
        let characterEnd = string.utf16.index(string.startIndex, offsetBy: codeUnitEnd)
        let clusterString = string[characterStart ..< characterEnd]

        let glyphStart = clusterMap[codeUnitStart]
        let glyphEnd = (codeUnitEnd < clusterMap.count ? clusterMap[codeUnitEnd] : glyphIDs.count)
        let glyphRange = glyphStart ..< glyphEnd

        return ClusterDetail(codePoints: Array(clusterString.unicodeScalars),
                             glyphIDs: glyphIDs[glyphRange],
                             glyphOffsets: glyphOffsets[glyphRange],
                             glyphAdvances: glyphAdvances[glyphRange])
    }
}

class CharacterDetailCell: UITableViewCell {
    @IBOutlet weak var characterLabel: UILabel!
}

class GlyphDetailCell: UITableViewCell {
    @IBOutlet weak var glyphIDLabel: UILabel!
    @IBOutlet weak var glyphOffsetLabel: UILabel!
    @IBOutlet weak var glyphAdvanceLabel: UILabel!
}

class ClusterDetailCell: UITableViewCell, UITableViewDataSource {
    @IBOutlet private weak var charactersTableView: UITableView!
    @IBOutlet private weak var glyphsTableView: UITableView!

    @IBOutlet private var charactersHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var glyphsHeightConstraint: NSLayoutConstraint!

    private var clusterDetail: ClusterDetail!

    fileprivate func configure(with clusterDetail: ClusterDetail) {
        self.clusterDetail = clusterDetail

        NSLayoutConstraint.deactivate([
            charactersHeightConstraint, glyphsHeightConstraint
        ])

        charactersTableView.reloadData()
        glyphsTableView.reloadData()

        charactersTableView.layoutIfNeeded()
        glyphsTableView.layoutIfNeeded()

        charactersHeightConstraint.constant = charactersTableView.contentSize.height
        glyphsHeightConstraint.constant = glyphsTableView.contentSize.height

        NSLayoutConstraint.activate([
            charactersHeightConstraint, glyphsHeightConstraint
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
        case charactersTableView:
            return clusterDetail.codePoints.count

        case glyphsTableView:
            return clusterDetail.glyphIDs.count

        default:
            fatalError()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {
        case charactersTableView:
            let codePoint = clusterDetail.codePoints[clusterDetail.codePoints.startIndex + indexPath.row]

            let cell = tableView.dequeueReusableCell(withIdentifier: "\(CharacterDetailCell.self)", for: indexPath) as! CharacterDetailCell
            cell.characterLabel.text = String(format: "\u{202A}%04X (\(Character(codePoint)))", codePoint.value)

            return cell

        case glyphsTableView:
            let glyphID = clusterDetail.glyphIDs[clusterDetail.glyphIDs.startIndex + indexPath.row]
            let glyphOffset = clusterDetail.glyphOffsets[clusterDetail.glyphOffsets.startIndex + indexPath.row]
            let glyphAdvance = clusterDetail.glyphAdvances[clusterDetail.glyphAdvances.startIndex + indexPath.row]

            let cell = tableView.dequeueReusableCell(withIdentifier: "\(GlyphDetailCell.self)", for: indexPath) as! GlyphDetailCell
            cell.glyphIDLabel.text = String(format: "%04X", glyphID)
            cell.glyphOffsetLabel.text = "(\(Int(glyphOffset.x + 0.5)), \(Int(glyphOffset.y + 0.5)))"
            cell.glyphAdvanceLabel.text = "\(Int(glyphAdvance + 0.5))"

            return cell

        default:
            fatalError()
        }
    }
}

class OpenTypeInfoViewController: UITableViewController {
    @IBOutlet private weak var headerView: UIView!

    private var textDetail: TextDetail!

    func setup(typeface: Typeface, typeSize: Int,
               scriptTag: SFNTTag, languageTag: SFNTTag, sourceText: String) {
        let shapingEngine = ShapingEngine()
        shapingEngine.typeface = typeface
        shapingEngine.typeSize = CGFloat(typeSize)
        shapingEngine.scriptTag = scriptTag
        shapingEngine.languageTag = languageTag

        let textRange = sourceText.startIndex ..< sourceText.endIndex
        let shapingResult = shapingEngine.shape(string: sourceText, characterRange: textRange)
        let clusterMap = shapingResult.clusterMap
        let length = clusterMap.count

        var initials: [Int] = []
        var previous = -1

        for i in 0 ..< length {
            let value = clusterMap[i]
            if value != previous {
                initials.append(i)
            }

            previous = value
        }
        initials.append(length)

        textDetail = TextDetail(string: sourceText,
                                glyphIDs: shapingResult.glyphIDs,
                                glyphOffsets: shapingResult.glyphOffsets,
                                glyphAdvances: shapingResult.glyphAdvances,
                                clusterMap: shapingResult.clusterMap,
                                clusterInitials: initials)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.contentInset.bottom += 8
        headerView.backgroundColor = tableView.backgroundColor
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60.0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return textDetail.clusterCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(ClusterDetailCell.self)", for: indexPath) as! ClusterDetailCell
        cell.configure(with: textDetail.clusterDetail(at: indexPath.row))

        return cell
    }
}
