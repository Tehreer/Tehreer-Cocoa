//
// Copyright (C) 2021 Muhammad Tayyab Akram
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

private struct Ayah: Codable {
    let text: String
    let attributes: [Attribute]
}

private struct Attribute: Codable {
    let start: Int
    let end: Int
    let color: String
}

class TextViewController: UIViewController {
    @IBOutlet private weak var textView: TTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.typeface = TypefaceManager.default.typeface(forTag: TypefaceTag.noorehuda)
        textView.textColor = .text
        textView.textSize = 36.0
        textView.textAlignment = .center
        textView.attributedText = parseSurah()
        textView.lineHeightMultiplier = 0.75
        textView.contentInset = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }

    private func parseSurah() -> NSAttributedString? {
        guard let path = Bundle.main.path(forResource: "AlKahf", ofType: "json") else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard let ayahs = try? JSONDecoder().decode([Ayah].self, from: data) else { return nil }

        let surah = NSMutableAttributedString()
        var bismillah = true

        for ayah in ayahs {
            let text = NSMutableAttributedString(string: ayah.text)

            for attr in ayah.attributes {
                let range = NSRange(location: attr.start, length: attr.end - attr.start)
                let color = parseColor(hex: attr.color)

                text.addAttribute(.foregroundColor, value: color, range: range)
            }

            surah.append(text)
            surah.mutableString.append(bismillah ? "\n" : "      ")

            bismillah = false
        }

        return surah
    }

    private func parseColor(hex: String) -> UIColor {
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)

        return UIColor(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                       green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                       blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                       alpha: 1.0)
    }
}
