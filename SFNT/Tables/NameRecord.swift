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

extension NameTable {
    public struct Record {
        /// The name id of this record.
        public let nameID: UInt16

        /// The platform id of this record.
        public let platformID: UInt16

        /// The language id of this record.
        public let languageID: UInt16

        /// The encoding id of this record.
        public let encodingID: UInt16

        /// The encoded bytes of this record.
        public let bytes: [UInt8]
    }
}
