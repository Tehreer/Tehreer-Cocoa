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

private enum Link {
    static let adobe = URL(string: "https://en.wikipedia.org/wiki/Adobe_Inc.")!
    static let glyph = URL(string: "https://en.wikipedia.org/wiki/Glyph")!
    static let microsoft = URL(string: "https://en.wikipedia.org/wiki/Microsoft")!
    static let unicode = URL(string: "https://en.wikipedia.org/wiki/Unicode")!
}

private enum Color {
    static let black = UIColor.black
    static let blue = UIColor(red: 0x1E / 255.0, green: 0x43 / 255.0, blue: 0xA9 / 255.0, alpha: 1.0)
}

class LabelViewController: UIViewController {
    @IBOutlet private weak var label: TLabel!

    let data = [
        [Color.black, "اوپن ٹائپ دراصل کمپیوٹر فونٹس کے لیے ایک قابل میزان فارمیٹ کو کہا جاتا ہے جسے ابتداء میں "],
        [Color.blue, Link.microsoft, "مائکروسافٹ"],
        [Color.black, " نے تیار کیا تھا اور پھر بعد میں "],
        [Color.blue, Link.adobe, "ایڈوبی سسٹم"],
        [Color.black, " بھی اس میں شامل ہو گیا۔ گو انکا اعلان 1996ء میں کیا گیا تھا پر انکی قابل ذکر تعداد میں ترسیل 2000ء تا 2001ء تک دیکھنے میں آئی۔ "],
        [Color.blue, Link.adobe, "ایڈوبی سسٹم"],
        [Color.black, " نے اپنے فونٹس کے تمام تر کتب خانے کو اوپن ٹائپ میں تبدیل کرنے کا کام 2002ء تک مکمل کر لیا تھا۔ سن 2005ء کے آغاز تک 10،000 فونٹس اوپن ٹائپ میں دستیاب کرائے جاچکے تھے جن میں سے "],
        [Color.blue, Link.adobe, "ایڈوبی سسٹم"],
        [Color.black, " کے کتب خانے کا ایک تہائی حصہ بنتا تھا۔\nیہ فونٹس ونڈوز ، لینکس اور میک آپریٹنگ سسٹمز پر کام کرتے ہیں۔ ان میں 65 ہزار سے زیادہ "],
        [Color.blue, Link.glyph, "منقوشات (glyphs)"],
        [Color.black, " اور "],
        [Color.blue, Link.unicode, "یونیکوڈ"],
        [Color.black, "کی سہولت موجود ہے۔ ان میں لاطینیہ زبانوں کے ساتھ ساتھ غیرلاطینی ترسیمات و حروف رکھنے والی زبانوں کی تخطیط بھی کی جاسکتی ہے۔"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        let text = NSMutableAttributedString()

        for span in data {
            var attributes: [NSAttributedString.Key: Any] = [:]

            for element in span {
                switch element {
                case is UIColor:
                    attributes[.foregroundColor] = element
                case is URL:
                    attributes[.link] = element
                case let string as String:
                    text.append(NSAttributedString(string: string, attributes: attributes))
                default: break
                }
            }
        }

        label.typeface = TypefaceManager.shared.typeface(for: TypefaceTag.tajNastaleeq)
        label.textSize = 20
        label.attributedText = text
    }
}
