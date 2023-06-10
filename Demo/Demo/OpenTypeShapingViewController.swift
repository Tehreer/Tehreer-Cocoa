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
    static let showInfo = "ShowInfo"
}

class OpenTypeShapingViewController: UITableViewController {
    @IBOutlet private weak var typefaceTitleLabel: UILabel!
    @IBOutlet private weak var typeSizeField: UITextField!
    @IBOutlet private weak var scriptTagField: UITextField!
    @IBOutlet private weak var languageTagField: UITextField!
    @IBOutlet private weak var inputTextView: UITextView!

    private var selectedTypeface: Typeface! = TypefaceManager.default.availableTypefaces.first

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTypefaceTitle()
    }

    private func updateTypefaceTitle() {
        typefaceTitleLabel.text = selectedTypeface?.familyName
    }

    private func textOrPlaceholder(of textField: UITextField) -> String {
        let text = textField.text ?? ""

        if text.isEmpty {
            return textField.placeholder ?? ""
        }

        return text
    }

    // MARK: - Properties

    private var typeSize: Int! {
        return Int(textOrPlaceholder(of: typeSizeField))
    }

    private var scriptTag: SFNTTag! {
        return SFNTTag(string: textOrPlaceholder(of: scriptTagField))
    }

    private var languageTag: SFNTTag! {
        return SFNTTag(string: textOrPlaceholder(of: languageTagField))
    }

    private var inputText: String {
        return inputTextView.text
    }

    // MARK: - Actions

    @IBAction private func shapedButtonPressed(_ sender: Any) {
        guard let _ = scriptTag else {
            presentAlert("Enter a valid script tag")
            return
        }
        guard let _ = languageTag else {
            presentAlert("Enter a valid language tag")
            return
        }

        performSegue(withIdentifier: SegueID.showInfo, sender: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case SegueID.showTypefaces:
            let typefacesViewController = segue.destination as! AvailableTypefacesViewController
            typefacesViewController.setup(selectedTypeface: selectedTypeface, onSelectionChanged: {
                self.selectedTypeface = typefacesViewController.selectedTypeface
                self.updateTypefaceTitle()
            })

        case SegueID.showInfo:
            let infoViewController = segue.destination as! OpenTypeInfoViewController
            infoViewController.setup(typeface: selectedTypeface,
                                     typeSize: typeSize,
                                     scriptTag: scriptTag,
                                     languageTag: languageTag,
                                     sourceText: inputText)

        default:
            break
        }
    }
}
