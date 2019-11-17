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

private enum CellID {
    static let typefaceTitle = "TypefaceTitleCell"
}

class AvailableTypefacesViewController: UITableViewController {
    private let availableTypefaces = TypefaceManager.default.availableTypefaces

    private(set) var selectedTypeface: Typeface?
    private var onSelectionChanged: ActionCallback!

    func setup(selectedTypeface: Typeface?, onSelectionChanged: @escaping ActionCallback) {
        self.selectedTypeface = selectedTypeface
        self.onSelectionChanged = onSelectionChanged
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableTypefaces.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let typeface = availableTypefaces[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.typefaceTitle, for: indexPath)
        cell.textLabel?.text = typeface.familyName
        cell.accessoryType = typeface === selectedTypeface ? .checkmark : .none

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedTypeface = availableTypefaces[indexPath.row]
        tableView.reloadData()

        onSelectionChanged()
    }
}
