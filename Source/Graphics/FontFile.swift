//
// Copyright (C) 2019-2021 Muhammad Tayyab Akram
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
import FreeType

class FontStream {
    private var arguments: FT_Open_Args

    let faceCount: Int

    convenience init?(path: String) {
        let utf8Path = path.utf8CString.withUnsafeBufferPointer { (pointer) -> UnsafeMutablePointer<FT_String>? in
            guard let baseAddress = pointer.baseAddress else {
                return nil
            }

            let newPath = UnsafeMutablePointer<FT_String>.allocate(capacity: pointer.count)
            newPath.assign(from: baseAddress, count: pointer.count)
            return newPath
        }

        var arguments = FT_Open_Args()
        arguments.flags = FT_UInt(FT_OPEN_PATHNAME)
        arguments.memory_base = nil
        arguments.memory_size = 0
        arguments.pathname = utf8Path
        arguments.stream = nil

        self.init(arguments: &arguments)
    }

    convenience init?(stream: InputStream) {
        stream.open()

        let chunkLength = 4096
        let chunkBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkLength)

        var data = Data()

        while true {
            let bytesRead = stream.read(chunkBuffer, maxLength: chunkLength)
            guard bytesRead > 0 else {
                break
            }

            data.append(chunkBuffer, count: bytesRead)
        }

        chunkBuffer.deallocate()
        stream.close()

        self.init(data: data)
    }

    convenience init?(data: Data) {
        let streamBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: streamBuffer, count: data.count)

        self.init(pointer: UnsafePointer<FT_Byte>(streamBuffer), size: data.count)
    }

    private convenience init?(pointer: UnsafePointer<FT_Byte>, size: Int) {
        var arguments = FT_Open_Args()
        arguments.flags = FT_UInt(FT_OPEN_MEMORY)
        arguments.memory_base = pointer
        arguments.memory_size = size
        arguments.pathname = nil
        arguments.stream = nil

        self.init(arguments: &arguments)
    }

    convenience init?(arguments: inout FT_Open_Args) {
        let numFaces = FreeType.withLibrary { (library) -> FT_Long in
            var face: FT_Face!

            if FT_Open_Face(library, &arguments, 0, &face) == FT_Err_Ok {
                let numFaces = face.pointee.num_faces
                FT_Done_Face(face)

                return numFaces
            }

            return 0
        }
        guard numFaces > 0 else {
            return nil
        }

        self.init(arguments: &arguments, numFaces: numFaces)
    }

    private init(arguments: inout FT_Open_Args, numFaces: Int) {
        self.arguments = arguments
        self.faceCount = numFaces
    }

    deinit {
        if let utf8Path = arguments.pathname {
            utf8Path.deallocate()
        }
        if let pointer = arguments.memory_base {
            pointer.deallocate()
        }
        if let stream = arguments.stream {
            stream.pointee.close(stream)
            stream.deallocate()
        }
    }

    func makeFTFace(faceIndex: Int, instanceIndex: Int) -> FT_Face? {
        FreeType.withLibrary { (library) in
            let id: FT_Long = (instanceIndex << 16) + faceIndex
            var face: FT_Face!

            if FT_Open_Face(library, &arguments, id, &face) == FT_Err_Ok {
                if (face.pointee.face_flags & FT_FACE_FLAG_SCALABLE) == 0 {
                    FT_Done_Face(face)
                    face = nil
                }
            }

            return face
        }
    }
}

public class FontFile {
    private let mutex = Mutex()
    private let fontStream: FontStream
    private var defaultTypefaces: [Typeface]!

    public init?(path: String) {
        guard let fontStream = FontStream(path: path) else {
            return nil
        }

        self.fontStream = fontStream
    }

    public init?(stream: InputStream) {
        guard let fontStream = FontStream(stream: stream) else {
            return nil
        }

        self.fontStream = fontStream
    }

    private func loadTypefaces() {
        defaultTypefaces = []

        for i in 0 ..< fontStream.faceCount {
            guard let firstTypeface = Typeface(fontStream: fontStream, faceIndex: i, instanceIndex: i) else {
                continue
            }

            let instanceStart = defaultTypefaces.count;
            let instanceCount = firstTypeface.ftFace.pointee.style_flags >> 16

            defaultTypefaces.append(firstTypeface)

            for j in 1 ..< instanceCount {
                guard let instanceTypeface = Typeface(fontStream: fontStream, faceIndex: i, instanceIndex: j) else {
                    continue
                }

                let instanceCoords = instanceTypeface.variationCoordinates ?? []
                if !instanceCoords.isEmpty {
                    // Remove existing duplicate instances.
                    for k in (instanceStart ..< defaultTypefaces.count).reversed() {
                        let referenceCoords = defaultTypefaces[k].variationCoordinates

                        if instanceCoords == referenceCoords {
                            defaultTypefaces.remove(at: k)
                        }
                    }
                }

                defaultTypefaces.append(instanceTypeface)
            }
        }
    }

    public var typefaces: [Typeface] {
        if defaultTypefaces == nil {
            mutex.synchronized {
                if defaultTypefaces == nil {
                    loadTypefaces()
                }
            }
        }

        return defaultTypefaces
    }
}
