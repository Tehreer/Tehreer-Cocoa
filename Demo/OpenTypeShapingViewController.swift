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

private enum SegueID {
    static let showTypefaces = "ShowTypefaces"
}

class OpenTypeShapingViewController: UITableViewController {
    @IBOutlet private weak var typefaceTitleLabel: UILabel!
    @IBOutlet private weak var typeSizeField: UITextField!
    @IBOutlet private weak var scriptTagField: UITextField!
    @IBOutlet private weak var languageTagField: UITextField!
    @IBOutlet private weak var inputTextView: UITextView!

    private var selectedTypeface = TypefaceManager.shared.availableTypefaces.first

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTypefaceTitle()
    }

    private func updateTypefaceTitle() {
        typefaceTitleLabel.text = selectedTypeface?.familyName
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case SegueID.showTypefaces:
            guard let typefacesViewController = segue.destination as? AvailableTypefacesViewController else {
                return
            }

            typefacesViewController.setup(selectedTypeface: selectedTypeface, onSelectionChanged: {
                self.selectedTypeface = typefacesViewController.selectedTypeface
                self.updateTypefaceTitle()
            })

        default:
            break
        }
    }
}
