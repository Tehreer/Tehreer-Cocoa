//
// Copyright (C) 2019-2026 Muhammad Tayyab Akram
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


internal import Tehreer

import CoreGraphics
import Foundation

/// Represents a frame containing multiple lines of text. It is the output resulting from
/// text-framing process performed by a typesetter.
// Unchecked because the frame of Core is immutable, and the rest is set once in the initializer.
public final class ComposedFrame: @unchecked Sendable {
    private let core: TRComposedFrameRef
    let string: String

    init(core: TRComposedFrameRef, string: String, objects: CoreTextObjects) {
        self.core = core
        self.string = string

        let count = Int(TRComposedFrameGetLineCount(core))
        var lines: [ComposedLine] = []
        lines.reserveCapacity(count)

        for index in 0 ..< count {
            let line = TRComposedFrameGetLine(core, TRUInteger(index))!
            lines.append(ComposedLine(core: TRComposedLineRetain(line), string: string, objects: objects))
        }

        self.lines = lines
    }

    deinit {
        TRComposedFrameRelease(core)
    }

    /// The UTF-16 range of this frame in source string.
    public var codeUnitRange: Range<Int> {
        let range = TRComposedFrameGetCodeUnitRange(core)
        return Int(range.index) ..< Int(range.index + range.length)
    }

    /// The index to the first character of this frame in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this frame in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    /// The width of this frame.
    public var width: CGFloat {
        return CGFloat(TRComposedFrameGetWidth(core))
    }

    /// The height of this frame.
    public var height: CGFloat {
        return CGFloat(TRComposedFrameGetHeight(core))
    }

    /// The array containing all the lines of this frame.
    public let lines: [ComposedLine]

    /// Returns the index of line containing the specified UTF-16 code unit index.
    ///
    /// - Parameter index: The index of UTF-16 code unit for which to return the line index.
    /// - Returns: The index of line containing the specified UTF-16 code unit index.
    public func indexOfLine(forCodeUnitAt index: Int) -> Int {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, .indexOutOfRange)

        let lineIndex = TRComposedFrameGetIndexOfLineForCodeUnit(core, TRUInteger(index))

        return lineIndex == TRUInteger.max ? -1 : Int(lineIndex)
    }

    /// Returns the index of line containing the specified character index.
    ///
    /// - Parameter index: The index of character for which to return the line index.
    /// - Returns: The index of line containing the specified character index.
    public func indexOfLine(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index <= endIndex, .indexOutOfRange)

        return indexOfLine(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns the index of a suitable line representing the specified position.
    ///
    /// - Parameter position: The position for which to return the line index.
    /// - Returns: The index of a suitable line representing the specified position.
    public func indexOfLine(at position: CGPoint) -> Int {
        guard !lines.isEmpty else {
            return -1
        }

        return Int(TRComposedFrameGetIndexOfLineAtPosition(core, TRPoint(x: TRFloat(position.x),
                                                                         y: TRFloat(position.y))))
    }

    /// Creates a path that contains a set of rectangles covering the specified UTF-16 code unit range.
    ///
    /// - Parameter codeUnitRange: The selection range in source string.
    /// - Returns: A path that contains a set of rectangles covering the specified UTF-16 range.
    public func selectionPath(forCodeUnitRange codeUnitRange: Range<Int>) -> CGPath {
        let selectionPath = CGMutablePath()

        guard !codeUnitRange.isEmpty else {
            return selectionPath
        }

        let range = TRRange(index: TRUInteger(codeUnitRange.lowerBound),
                            length: TRUInteger(codeUnitRange.count))

        let user = Unmanaged.passUnretained(selectionPath).toOpaque()

        TRComposedFrameEnumerateSelection(core, range, { (user, rect) in
            let path = Unmanaged<CGMutablePath>.fromOpaque(user!).takeUnretainedValue()
            path.addRect(CGRect(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y),
                                width: CGFloat(rect.size.width), height: CGFloat(rect.size.height)))
        }, user)

        return selectionPath
    }

    /// Creates a path that contains a set of rectangles covering the specified character range.
    ///
    /// - Parameter characterRange: The selection range in source string.
    /// - Returns: A path that contains a set of rectangles covering the specified character range.
    public func selectionPath(forCharacterRange characterRange: Range<String.Index>) -> CGPath {
        return selectionPath(forCodeUnitRange: string.utf16Range(forCharacterRange: characterRange))
    }

    /// Draws this frame in the `context` with the specified renderer.
    ///
    /// - Parameters:
    ///   - renderer: The renderer with which to draw the frame.
    ///   - context: The context in which to draw the frame.
    ///   - point: The position at which to draw the frame.
    public func draw(with renderer: Renderer, in context: CGContext, at point: CGPoint) {
        context.translateBy(x: point.x, y: point.y)

        for line in lines {
            // TODO: Handle Attributes.

            context.translateBy(x: line.origin.x, y: line.origin.y)
            line.draw(with: renderer, in: context)
            context.translateBy(x: -line.origin.x, y: -line.origin.y)
        }

        context.translateBy(x: -point.x, y: -point.y)
    }
}
