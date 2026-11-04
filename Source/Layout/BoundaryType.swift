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

/// Specifies the kinds of boundaries that a text can be searched for.
public enum BoundaryType: Sendable {
    /// A boundary between two grapheme clusters.
    case grapheme
    /// A boundary between two word segments, which are words, spaces or punctuations.
    case word
    /// A boundary between two paragraphs, which end with their separator.
    case paragraph
}

/// Specifies the direction of searching for a boundary.
public enum BoundaryDirection: Sendable {
    /// Searches for the last boundary before an index.
    case backward
    /// Searches for the first boundary after an index.
    case forward
}
