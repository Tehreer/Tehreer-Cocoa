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

import Foundation

/// A `BidiLine` object represents a single line processed with rules L1-L2 of Unicode Bidirectional
/// Algorithm. Instead of reordering the characters as stated by rule L2, it allows to query and
/// iterate over reordered level runs. The caller is responsible to reorder the characters manually,
/// if required.
public class BidiLine {
    let buffer: BidiBuffer
    let line: SBLineRef

    init(buffer: BidiBuffer, line: SBLineRef) {
        self.buffer = buffer
        self.line = line
    }

    deinit {
        SBLineRelease(line)
    }

    var stringRange: Range<String.Index> {
        let lineOffset = SBLineGetOffset(line)
        let lineLength = SBLineGetLength(line)
        let utf16Range = NSRange(location: Int(lineOffset), length: Int(lineLength))

        return buffer.string.characterRange(forUTF16Range: utf16Range)
    }

    public var startIndex: String.Index {
        return stringRange.lowerBound
    }

    public var endIndex: String.Index {
        return stringRange.upperBound
    }
}
