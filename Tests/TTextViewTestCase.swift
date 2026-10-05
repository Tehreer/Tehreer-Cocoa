//
// Copyright (C) 2026 Muhammad Tayyab Akram
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
import XCTest
@testable import TehreerCocoa

/// A fixture that shows a `TTextView` in a window and waits for the text to be framed. The test
/// font is the one of the demo.
class TTextViewTestCase: XCTestCase {
    static let typeface: Typeface = {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Demo/Fonts/NafeesWeb.ttf")
            .path

        return Typeface(path: path)!
    }()

    var window: UIWindow!
    var textView: TTextView!

    override func setUp() {
        super.setUp()

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()

        textView = TTextView(frame: window.bounds)
        textView.typeface = TTextViewTestCase.typeface
        textView.textSize = 24.0
        textView.contentInsetAdjustmentBehavior = .never
        window.addSubview(textView)
    }

    override func tearDown() {
        textView = nil
        window = nil

        super.tearDown()
    }

    func urduText(_ count: Int) -> String {
        return String(repeating: "یہ ایک لمبی کہانی کا حصہ ہے جو کئی سطروں پر پھیلی ہوئی ہے۔ ", count: count)
    }

    func spin(_ seconds: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Waits until `condition` holds, running the main loop and laying the view out.
    func wait(_ message: String, timeout: TimeInterval = 10.0, until condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)

        while !condition() && Date() < deadline {
            textView.layoutIfNeeded()
            spin()
        }

        XCTAssertTrue(condition(), "Timed out waiting for \(message)")
    }

    /// Waits until the text is framed and its line boxes are in, which is when its lines show.
    func awaitFrame(file: StaticString = #filePath, line: UInt = #line) {
        wait("the frame") {
            textView.textFrame != nil && textView.container.subviews.contains { $0 is LineView }
        }

        spin(0.2)
        textView.layoutIfNeeded()
    }

    func show(_ text: String) {
        textView.text = text
        awaitFrame()
    }

    var lines: [ComposedLine] {
        return textView.textFrame?.lines ?? []
    }

    func center(of line: ComposedLine) -> CGPoint {
        return CGPoint(x: line.origin.x + line.width / 2.0, y: line.origin.y - line.ascent / 2.0 + line.descent / 2.0)
    }
}
