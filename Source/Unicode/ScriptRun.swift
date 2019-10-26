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

/// A script run represents a sequence of characters which have the same script.
public struct ScriptRun {
    /// The index to the first character of the run in source string.
    public var startIndex: String.Index

    /// The index after the last character of the run in source string.
    public var endIndex: String.Index

    /// The resolved script of the run.
    public var script: Script
}
