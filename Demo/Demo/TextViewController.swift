//
// Copyright (C) 2021-2023 Muhammad Tayyab Akram
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

private enum TextSize {
    static let minimum: CGFloat = 20.0
    static let maximum: CGFloat = 56.0
}

class TextViewController: UIViewController {
    @IBOutlet private weak var textSizeSlider: UISlider!
    @IBOutlet private weak var textView: QuranTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTextSize()

        textView.typeface = TypefaceManager.default.typeface(forTag: TypefaceTag.noorehuda)
        textView.textColor = .text
        textView.textSize = 36.0
        textView.textAlignment = .center
        textView.attributedText = parseSurah()
        textView.lineHeightMultiplier = 0.9
        textView.isJustificationEnabled = true
        textView.separatorColor = .gray
        textView.highlightingColor = .highlight
        textView.contentInset = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }

    private func parseSurah() -> NSAttributedString? {
        guard let path = Bundle.main.path(forResource: "AlKahf", ofType: "json") else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard let ayahs = try? JSONDecoder().decode([Ayah].self, from: data) else { return nil }

        let surah = NSMutableAttributedString()
        var bismillah = true

        for ayah in ayahs {
            let ayahStart = surah.length
            let text = NSMutableAttributedString(string: ayah.text)

            for attr in ayah.attributes {
                let range = NSRange(location: attr.start, length: attr.end - attr.start)
                let color = parseColor(hex: attr.color)

                text.addAttribute(.foregroundColor, value: color, range: range)
            }

            surah.append(text)
            let ayahEnd = surah.length

            surah.mutableString.append(bismillah ? "\n" : "  ")

            let ayahRange = NSMakeRange(ayahStart, ayahEnd - ayahStart)
            surah.addAttribute(.ayah, value: true, range: ayahRange)

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

    private func updateTextSize() {
        let ratio = CGFloat(textSizeSlider.value / textSizeSlider.maximumValue)
        let multiplier = TextSize.maximum - TextSize.minimum
        let px = (ratio * multiplier) + TextSize.minimum

        textView.textSize = px
    }

    @IBAction
    private func textSizeSliderTouched(_ sender: Any) {
        textView.clearAyahHighlighting()
    }

    @IBAction
    private func textSizeSliderValueChanged(_ sender: Any) {
        updateTextSize()
    }
}
