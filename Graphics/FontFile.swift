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

public class FontFile {
    private var arguments: FT_Open_Args
    private let faceCount: Int

    public convenience init?(path: String) {
        let cpath = path.cString(using: .utf8)

        var arguments = FT_Open_Args()
        arguments.flags = FT_UInt(FT_OPEN_PATHNAME)
        arguments.memory_base = nil
        arguments.memory_size = 0
        arguments.pathname = UnsafeMutablePointer<FT_String>(mutating: cpath)
        arguments.stream = nil

        self.init(arguments: &arguments)
    }

    private convenience init?(arguments: UnsafePointer<FT_Open_Args>) {
        FreeType.semaphore.wait()

        var ftFace: FT_Face! = nil
        var numFaces: FT_Long = 0
        let error = FT_Open_Face(FreeType.library, arguments, 0, &ftFace)

        if error == FT_Err_Ok {
            numFaces = ftFace.pointee.num_faces
            FT_Done_Face(ftFace)
            ftFace = nil
        }

        FreeType.semaphore.signal()

        guard ftFace != nil else {
            return nil
        }

        self.init(arguments: arguments,
                  numFaces: numFaces)
    }

    private init(arguments: UnsafePointer<FT_Open_Args>, numFaces: Int) {
        self.arguments = arguments.pointee
        self.faceCount = numFaces
    }

    func createFTFace(faceIndex: Int, instanceIndex: Int) -> FT_Face? {
        FreeType.semaphore.wait()
        defer { FreeType.semaphore.signal() }

        var ftFace: FT_Face! = nil
        let id: FT_Long = (instanceIndex << 16) + faceIndex
        let error = FT_Open_Face(FreeType.library, &arguments, id, &ftFace)

        if error == FT_Err_Ok {
            if (ftFace.pointee.face_flags & FT_FACE_FLAG_SCALABLE) == 0 {
                FT_Done_Face(ftFace)
                ftFace = nil
            }
        }

        return ftFace
    }
}
