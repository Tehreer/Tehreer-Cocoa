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
    private let stream: FT_Stream?
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

    public convenience init?(stream: InputStream) {
        let fontStream = UnsafeMutablePointer<FT_StreamRec>.allocate(capacity: 1)
        fontStream.pointee.base = nil
        fontStream.pointee.size = 0
        fontStream.pointee.pos = 0
        fontStream.pointee.descriptor.pointer = Unmanaged.passRetained(stream).toOpaque()
        fontStream.pointee.pathname.pointer = nil
        fontStream.pointee.read = { (stream, offset, buffer, count) in
            let streamPointer = (stream!.pointee.descriptor.pointer)!
            let unmanagedStream = Unmanaged<InputStream>.fromOpaque(streamPointer)
            let platformStream = unmanagedStream.takeUnretainedValue()
            let bytesRead = platformStream.read(buffer!, maxLength: Int(count))

            return UInt(bytesRead)
        }
        fontStream.pointee.close = { (stream) in
            if let streamPointer = stream!.pointee.descriptor.pointer {
                let unmanagedStream = Unmanaged<InputStream>.fromOpaque(streamPointer)
                unmanagedStream.release()

                stream!.pointee.base = nil
                stream!.pointee.size = 0
                stream!.pointee.descriptor.pointer = nil
            }
        }

        var arguments = FT_Open_Args()
        arguments.flags = FT_UInt(FT_OPEN_STREAM)
        arguments.memory_base = nil
        arguments.memory_size = 0
        arguments.pathname = nil
        arguments.stream = fontStream

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
                  stream: arguments.pointee.stream,
                  numFaces: numFaces)
    }

    private init(arguments: UnsafePointer<FT_Open_Args>, stream: FT_Stream?, numFaces: Int) {
        self.arguments = arguments.pointee
        self.stream = stream
        self.faceCount = numFaces
    }

    deinit {
        if let stream = stream {
            stream.pointee.close(stream)
            stream.deallocate()
        }
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
