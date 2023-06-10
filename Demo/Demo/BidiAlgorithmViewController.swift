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

import UIKit

private enum SegueID {
    static let showInfo = "ShowInfo"
}

class BidiAlgorithmViewController: UITableViewController {
    @IBOutlet private weak var inputTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case SegueID.showInfo:
            let bidiInfoViewController = segue.destination as! BidiInfoViewController
            bidiInfoViewController.setup(bidiText: inputTextView.text)

        default: break
        }
    }
}
