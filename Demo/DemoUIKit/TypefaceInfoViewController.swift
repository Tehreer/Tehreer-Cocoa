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

import TehreerCocoa
import UIKit

enum NameID {
    static let copyright = 0;
    static let fontFamily = 1;
    static let fontSubfamily = 2;
    static let uniqueID = 3;
    static let fullName = 4;
    static let version = 5;
    static let postScriptName = 6;
    static let trademark = 7;
    static let manufacturer = 8;
    static let designer = 9;
    static let description = 10;
    static let vendorURL = 11;
    static let designerURL = 12;
    static let license = 13;
    static let licenseURL = 14;
    static let typographicFamily = 16;
    static let typographicSubfamily = 17;
    static let macFullName = 18;
    static let sampleText = 19;
    static let postScriptCIDFindFontName = 20;
    static let wwsFamily = 21;
    static let wwsSubfamily = 22;
    static let lightBackgroundPalette = 23;
    static let darkBackgroundPalette = 24;
    static let variationsPostScriptNamePrefix = 25;
}

enum PlatformID {
    static let windows = 3
}

private struct NameInfo {
    let title: String
    let names: String
}

class NameInfoCell: UITableViewCell {
    @IBOutlet weak var nameTitleLabel: UILabel!
    @IBOutlet weak var nameLineLabel: UILabel!

    fileprivate func configure(with nameInfo: NameInfo) {
        nameTitleLabel.text = nameInfo.title
        nameLineLabel.text = nameInfo.names
    }
}

class TypefaceInfoViewController: UITableViewController {
    @IBOutlet private weak var typefaceLabel: UILabel!
    @IBOutlet private weak var headerView: UIView!

    private var selectedTypeface: Typeface!
    private var nameList: [NameInfo] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        selectTypeface(TypefaceManager.default.availableTypefaces.first)
    }

    private func appendName(_ title: String, id: Int, table: NameTable, list: inout [NameInfo]) {
        var strings: [String] = []

        for i in 0 ..< table.recordCount {
            let record = table.record(at: i)

            if record.nameID == id && record.platformID == PlatformID.windows {
                if let string = record.string {
                    strings.append(string)
                }
            }
        }

        if !strings.isEmpty {
            var names = ""

            for string in strings {
                names.append(string + "\n")
            }
            names.remove(at: names.index(before: names.endIndex))

            list.append(NameInfo(title: title, names: names))
        }
    }

    private func selectTypeface(_ typeface: Typeface!) {
        selectedTypeface = typeface
        typefaceLabel.text = typeface.familyName
        nameList.removeAll()

        guard let nameTable = NameTable(typeface: typeface) else {
            return
        }

        appendName("Copyright Notice:", id: NameID.copyright, table: nameTable, list: &nameList)
        appendName("Font Family Name:", id: NameID.fontFamily, table: nameTable, list: &nameList)
        appendName("Font Subfamily Name:", id: NameID.fontSubfamily, table: nameTable, list: &nameList)
        appendName("Unique Font Identifier:", id: NameID.uniqueID, table: nameTable, list: &nameList)
        appendName("Full Font Name:", id: NameID.fullName, table: nameTable, list: &nameList)
        appendName("Version String:", id: NameID.version, table: nameTable, list: &nameList)
        appendName("PostScript Name:", id: NameID.postScriptName, table: nameTable, list: &nameList)
        appendName("Trademark:", id: NameID.trademark, table: nameTable, list: &nameList)
        appendName("Manufacturer Name:", id: NameID.manufacturer, table: nameTable, list: &nameList)
        appendName("Designer Name:", id: NameID.designer, table: nameTable, list: &nameList)
        appendName("Typeface Description:", id: NameID.description, table: nameTable, list: &nameList)
        appendName("Vendor URL:", id: NameID.vendorURL, table: nameTable, list: &nameList)
        appendName("Designer URL:", id: NameID.designerURL, table: nameTable, list: &nameList)
        appendName("License Description:", id: NameID.license, table: nameTable, list: &nameList)
        appendName("License Info URL:", id: NameID.licenseURL, table: nameTable, list: &nameList)
        appendName("Typographic Family Name:", id: NameID.typographicFamily, table: nameTable, list: &nameList)
        appendName("Typographic Subfamily Name:", id: NameID.typographicSubfamily, table: nameTable, list: &nameList)
        appendName("Compatible Full (Macintosh Only):", id: NameID.macFullName, table: nameTable, list: &nameList)
        appendName("Sample Text:", id: NameID.sampleText, table: nameTable, list: &nameList)
        appendName("PostScript CID “findfont” Name:", id: NameID.postScriptCIDFindFontName, table: nameTable, list: &nameList)
        appendName("WWS Family Name:", id: NameID.wwsFamily, table: nameTable, list: &nameList)
        appendName("WWS Subfamily Name:", id: NameID.wwsSubfamily, table: nameTable, list: &nameList)
        appendName("Light Background Palette:", id: NameID.lightBackgroundPalette, table: nameTable, list: &nameList)
        appendName("Dark Background Palette:", id: NameID.darkBackgroundPalette, table: nameTable, list: &nameList)
        appendName("Variations PostScript Name Prefix:", id: NameID.variationsPostScriptNamePrefix, table: nameTable, list: &nameList)

        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
    }

    // MARK: - Actions

    @IBAction private func typefaceViewTapped(_ sender: Any) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: "\(AvailableTypefacesViewController.self)") as? AvailableTypefacesViewController {
            viewController.setup(selectedTypeface: selectedTypeface, onSelectionChanged: { [weak self] in
                self?.selectTypeface(viewController.selectedTypeface)
            })

            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44.0
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nameList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(NameInfoCell.self)", for: indexPath) as! NameInfoCell
        cell.configure(with: nameList[indexPath.row])

        return cell
    }
}
