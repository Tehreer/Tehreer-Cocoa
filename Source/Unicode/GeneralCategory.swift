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

/// The general category of a code point in the Unicode Standard. The value `unknown` stands for a code point that has none.
public enum GeneralCategory: Int, Sendable {
    case unknown = 0
    case uppercaseLetter = 1
    case lowercaseLetter = 2
    case titlecaseLetter = 3
    case modifierLetter = 4
    case otherLetter = 5
    case nonspacingMark = 6
    case spacingMark = 7
    case enclosingMark = 8
    case decimalNumber = 9
    case letterNumber = 10
    case otherNumber = 11
    case connectorPunctuation = 12
    case dashPunctuation = 13
    case openPunctuation = 14
    case closePunctuation = 15
    case initialPunctuation = 16
    case finalPunctuation = 17
    case otherPunctuation = 18
    case mathSymbol = 19
    case currencySymbol = 20
    case modifierSymbol = 21
    case otherSymbol = 22
    case spaceSeparator = 23
    case lineSeparator = 24
    case paragraphSeparator = 25
    case control = 26
    case format = 27
    case surrogate = 28
    case privateUse = 29
    case unassigned = 30
}
