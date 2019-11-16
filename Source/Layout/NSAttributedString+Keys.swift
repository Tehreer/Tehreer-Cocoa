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

extension NSAttributedString.Key {
    /// The value of this attribute is a `Typeface` object. Use this attribute to specify the
    /// typeface of the text during rendering.
    public static let typeface = NSAttributedString.Key("TTypeface")
    /// The value of this attribute is a `CGFloat` value. Use this attribute to specify the size of
    /// of the typeface during rendering.
    public static let typeSize = NSAttributedString.Key("TSize")
    /// The value of this attribute is a `CGFloat` value. Use this attribute to specify the scale of
    /// of the typeface during rendering.
    public static let scaleX = NSAttributedString.Key("TScaleX")
    /// The value of this attribute is a `CGFloat` value. Use this attribute to specify the scale of
    /// of the typeface during rendering.
    public static let scaleY = NSAttributedString.Key("TScaleY")
}
