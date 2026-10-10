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

import Foundation

/// The bidirectional character type of a code point, as defined by the Unicode Bidirectional Algorithm (UAX #9). The value `unknown` stands for a code point that has none.
public enum BidiClass: Int, Sendable {
    case unknown = 0
    case leftToRight = 1
    case rightToLeft = 2
    case arabicLetter = 3
    case boundaryNeutral = 4
    case nonspacingMark = 5
    case arabicNumber = 6
    case europeanNumber = 7
    case europeanTerminator = 8
    case europeanSeparator = 9
    case commonSeparator = 10
    case whiteSpace = 11
    case segmentSeparator = 12
    case paragraphSeparator = 13
    case otherNeutral = 14
    case leftToRightIsolate = 15
    case rightToLeftIsolate = 16
    case firstStrongIsolate = 17
    case popDirectionalIsolate = 18
    case leftToRightEmbedding = 19
    case rightToLeftEmbedding = 20
    case leftToRightOverride = 21
    case rightToLeftOverride = 22
    case popDirectionalFormat = 23
}
