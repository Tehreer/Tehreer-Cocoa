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

private let LRI = "\u{2066}"
private let RLI = "\u{2067}"
private let PDI = "\u{2069}"

class BidiInfoViewController: UIViewController {
    @IBOutlet private weak var bidiTextView: UITextView!

    private var bidiText: String = ""
    private var pageText = NSMutableAttributedString()

    func setup(bidiText: String) {
        self.bidiText = bidiText
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        writeBidiText()
        bidiTextView.attributedText = pageText
    }

    private func firstHeading() -> [NSAttributedString.Key: Any] {
        return [.font: UIFont.boldSystemFont(ofSize: 24)]
    }

    private func secondHeading() -> [NSAttributedString.Key: Any] {
        return [.font: UIFont.boldSystemFont(ofSize: 20)]
    }

    private func inlineHeading() -> [NSAttributedString.Key: Any] {
        return [.font: UIFont.italicSystemFont(ofSize: 16)]
    }

    private func simpleText() -> [NSAttributedString.Key: Any] {
        return [.font: UIFont.systemFont(ofSize: 16)]
    }

    private func appendText(_ text: String) {
        pageText.append(NSAttributedString(string: text, attributes: simpleText()))
    }

    private func appendText(_ text: String, attributes: [NSAttributedString.Key: Any]) {
        pageText.append(NSAttributedString(string: text, attributes: attributes))
    }

    private func writeBidiText() {
        if let algorithm = BidiAlgorithm(string: bidiText) {
            writeAlgorithmText(algorithm: algorithm)
        }

        pageText.addAttribute(.foregroundColor, value: UIColor.text,
                              range: NSRange(location: 0, length: pageText.length))
    }

    private func writeAlgorithmText(algorithm: BidiAlgorithm) {
        var paragraphIndex = 1
        var paragraphStart = bidiText.startIndex
        let suggestedEnd = bidiText.endIndex

        while paragraphStart != suggestedEnd {
            guard let paragraph = algorithm.makeParagraph(characterRange: paragraphStart ..< suggestedEnd, baseLevel: BaseDirection.defaultLeftToRight.rawValue) else {
                continue
            }

            writeParagraphText(paragraph: paragraph, index: paragraphIndex)

            paragraphIndex += 1
            paragraphStart = paragraph.endIndex
        }
    }

    private func writeParagraphText(paragraph: BidiParagraph, index: Int) {
        let paragraphStart = paragraph.startIndex
        let paragraphEnd = paragraph.endIndex

        let paragraphText = ((paragraph.baseLevel & 1) == 1 ? RLI : LRI)
                          + String(bidiText[paragraphStart ..< paragraphEnd]) + PDI

        let startIndex = bidiText.distance(from: bidiText.startIndex, to: paragraphStart)
        let length = bidiText.distance(from: paragraphStart, to: paragraphEnd)

        appendText("Paragraph \(index)\n", attributes: firstHeading())
        appendText("Paragraph Text:", attributes: inlineHeading())
        appendText(" \"\(paragraphText)\"\n")
        appendText("Paragraph Range:", attributes: inlineHeading())
        appendText(" Start=\(startIndex)")
        appendText(" Length=\(length)\n")
        appendText("Base Level:", attributes: inlineHeading())
        appendText(" \(paragraph.baseLevel)\n\n")

        var counter = 1

        for bidiRun in paragraph.logicalRuns {
            writeRunText(run: bidiRun, index: counter)
            counter += 1
        }

        if let line = paragraph.makeLine(characterRange: paragraphStart ..< paragraphEnd) {
            writeLineText(line: line, index: index)
            writeMirrorsText(line: line)
        }

        appendText("\n")
    }

    private func writeRunText(run: BidiRun, index: Int) {
        let runStart = run.startIndex
        let runEnd = run.endIndex

        let startIndex = bidiText.distance(from: bidiText.startIndex, to: runStart)
        let runLength = bidiText.distance(from: runStart, to: runEnd)
        let runText = (run.isRightToLeft ? RLI : LRI)
                    + String(bidiText[runStart ..< runEnd]) + PDI

        appendText("Run \(index)\n", attributes: secondHeading());
        appendText("Run Text:", attributes: inlineHeading());
        appendText(" \"\(runText)\"\n");
        appendText("Run Range:", attributes: inlineHeading());
        appendText(" Start=\(startIndex) Length=\(runLength)\n");
        appendText("Embedding Level:", attributes: inlineHeading());
        appendText(" \(run.embeddingLevel)\n\n");
    }

    private func writeLineText(line: BidiLine, index: Int) {
        var visualMap: [String.Index: Int] = [:]
        var counter = 1

        for bidiRun in line.visualRuns {
            visualMap[bidiRun.startIndex] = counter
            counter += 1
        }

        let sorted = visualMap.sorted { (first, second) -> Bool in
            return first.value > second.value
        }

        if !sorted.isEmpty {
            appendText("Visual Order\n", attributes: secondHeading())

            for (_, runIndex) in sorted {
                appendText("<Run \(runIndex)>", attributes: inlineHeading())
                appendText(" ")
            }

            appendText("\n\n")
        }
    }

    private func writeMirrorsText(line: BidiLine) {
        var wroteHeading = false

        for bidiPair in line.mirroringPairs {
            if !wroteHeading {
                wroteHeading = true
                appendText("Mirrors\n", attributes: secondHeading())
            }

            appendText("*", attributes: inlineHeading())
            appendText(" Index=\(bidiPair.codeUnitIndex))")
            appendText(" Character=‘\(Character(bidiPair.actualCodePoint))’")
            appendText(" Mirror=‘\(Character(bidiPair.pairingCodePoint))’\n")
        }

        if (wroteHeading) {
            appendText("\n")
        }
    }
}
