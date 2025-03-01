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

enum TypefaceTag {
    static let mehrNastaliq = "MehrNastaliq"
    static let nafeesWeb = "NafeesWeb"
    static let noorehuda = "Noorehuda"
    static let tajNastaleeq = "TajNstaleeq"
}

private func register(file: (name: String, type: String), forTag tag: String) {
    if let fullPath = Bundle.main.path(forResource: file.name, ofType: file.type),
       let typeface = Typeface(path: fullPath) {
        TypefaceManager.default.register(typeface, forTag: tag)
    }
}

@main
struct DemoApp: App {
    init() {
        register(file: ("MehrNastaliq", "ttf"), forTag: TypefaceTag.mehrNastaliq)
        register(file: ("NafeesWeb", "ttf"), forTag: TypefaceTag.nafeesWeb)
        register(file: ("Noorehuda", "ttf"), forTag: TypefaceTag.noorehuda)
        register(file: ("TajNastaleeq", "ttf"), forTag: TypefaceTag.tajNastaleeq)
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                MainScreen()
            }
            .tint(Color(red: 90 / 255.0, green: 180 / 255.0, blue: 90 / 255.0))
        }
    }
}
