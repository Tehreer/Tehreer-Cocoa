//
// Copyright (C) 2021 Muhammad Tayyab Akram
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

import CoreGraphics
import Foundation
import FreeType

class RenderableFace {
    private let mutex = Mutex()

    let fontStream: FontStream
    let ftFace: FT_Face
    
    private(set) var coordinates: [CGFloat] = []

    init(fontStream: FontStream, ftFace: FT_Face) {
        self.fontStream = fontStream
        self.ftFace = ftFace
    }

    func setupCoordinates(_ coordinates: [CGFloat]) {
        self.coordinates = coordinates

        var fixedCoords = coordinates.map { $0.f16Dot16 }
        FT_Set_Var_Design_Coordinates(ftFace, FT_UInt(coordinates.count), &fixedCoords)
    }

    deinit {
        FreeType.withLibrary { _ -> Void in
            FT_Done_Face(ftFace)
        }
    }

    func variationInstance(forCoordinates coordinates: [CGFloat]) -> RenderableFace? {
        let faceIndex = ftFace.pointee.face_index

        guard let derivedFace = fontStream.makeRenderableFace(faceIndex: faceIndex) else {
            return nil
        }

        derivedFace.setupCoordinates(coordinates)

        return derivedFace
    }

    func withRawFace<Result>(_ body: (FT_Face) throws -> Result) rethrows -> Result {
        mutex.lock()
        defer { mutex.unlock() }

        return try body(ftFace)
    }

    func dataOfTable(_ tag: SFNTTag) -> Data? {
        withRawFace { (ftFace) in
            let inputTag = FT_ULong(tag.rawValue)
            var length: FT_ULong = 0

            FT_Load_Sfnt_Table(ftFace, inputTag, 0, nil, &length)

            guard length > 0 else {
                return nil
            }

            let count = Int(length)
            let bytes = UnsafeMutablePointer<FT_Byte>.allocate(capacity: count)
            FT_Load_Sfnt_Table(ftFace, inputTag, 0, bytes, nil)

            return Data(bytesNoCopy: bytes, count: count, deallocator: .free)
        }
    }

    func cpalTable() -> CPAL.Table? {
        guard let cpalData = dataOfTable("CPAL") else {
            return nil
        }

        return CPAL.Table(data: cpalData)
    }

    func fvarTable() -> FVAR.Table? {
        guard let fvarData = dataOfTable("fvar") else {
            return nil
        }

        return FVAR.Table(data: fvarData)
    }
}
