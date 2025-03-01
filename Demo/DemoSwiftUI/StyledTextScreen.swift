//
// Copyright (C) 2025 Muhammad Tayyab Akram
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

import SwiftUI
import TehreerCocoa

private enum LinkURL {
    static let adobe = URL(string: "https://en.wikipedia.org/wiki/Adobe_Inc.")!
    static let glyph = URL(string: "https://en.wikipedia.org/wiki/Glyph")!
    static let microsoft = URL(string: "https://en.wikipedia.org/wiki/Microsoft")!
    static let unicode = URL(string: "https://en.wikipedia.org/wiki/Unicode")!
}

private enum LinkColor {
    static let text = Color.text
    static let blue = UIColor(red: 0x1E / 255.0, green: 0x43 / 255.0, blue: 0xA9 / 255.0, alpha: 1.0)
}

struct StyledTextScreen: View {
    private let data = [
        ["اوپن ٹائپ دراصل کمپیوٹر فونٹس کے لیے ایک قابل میزان فارمیٹ کو کہا جاتا ہے جسے ابتداء میں "],
        [LinkColor.blue, LinkURL.microsoft, "مائکروسافٹ"],
        [" نے تیار کیا تھا اور پھر بعد میں "],
        [LinkColor.blue, LinkURL.adobe, "ایڈوبی سسٹم"],
        [" بھی اس میں شامل ہو گیا۔ گو انکا اعلان 1996ء میں کیا گیا تھا پر انکی قابل ذکر تعداد میں ترسیل 2000ء تا 2001ء تک دیکھنے میں آئی۔ "],
        [LinkColor.blue, LinkURL.adobe, "ایڈوبی سسٹم"],
        [" نے اپنے فونٹس کے تمام تر کتب خانے کو اوپن ٹائپ میں تبدیل کرنے کا کام 2002ء تک مکمل کر لیا تھا۔ سن 2005ء کے آغاز تک 10،000 فونٹس اوپن ٹائپ میں دستیاب کرائے جاچکے تھے جن میں سے "],
        [LinkColor.blue, LinkURL.adobe, "ایڈوبی سسٹم"],
        [" کے کتب خانے کا ایک تہائی حصہ بنتا تھا۔\nیہ فونٹس ونڈوز ، لینکس اور میک آپریٹنگ سسٹمز پر کام کرتے ہیں۔ ان میں 65 ہزار سے زیادہ "],
        [LinkColor.blue, LinkURL.glyph, "منقوشات (glyphs)"],
        [" اور "],
        [LinkColor.blue, LinkURL.unicode, "یونیکوڈ"],
        ["کی سہولت موجود ہے۔ ان میں لاطینیہ زبانوں کے ساتھ ساتھ غیرلاطینی ترسیمات و حروف رکھنے والی زبانوں کی تخطیط بھی کی جاسکتی ہے۔"]
    ]
    
    private let article = NSMutableAttributedString()
    
    init() {
        for span in data {
            var attributes: [NSAttributedString.Key: Any] = [:]

            for element in span {
                switch element {
                case is UIColor:
                    attributes[.foregroundColor] = element
                case is URL:
                    attributes[.link] = element
                case let string as String:
                    article.append(NSAttributedString(string: string, attributes: attributes))
                default: break
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            Text("OpenType")
                .font(.largeTitle)
                .italic()
                .tint(.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom)
            
            ScrollView {
                StyledText(
                    article,
                    defaultAttributes: [
                        .typeface: TypefaceManager.default.typeface(forTag: TypefaceTag.tajNastaleeq)!,
                        .typeSize: 30.0,
                        .foregroundColor: UIColor(red: 0.30, green: 0.60, blue: 0.15, alpha: 1.0)
                    ]
                )
                .padding(.horizontal)
            }
            
            Text("https://ur.wikipedia.org/wiki/OpenType")
                .font(.body)
                .italic()
                .tint(.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
        }
        .navigationTitle("Styled Text")
    }
}

#Preview {
    StyledTextScreen()
}
