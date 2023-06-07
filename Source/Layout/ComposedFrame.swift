//
// Copyright (C) 2019-2020 Muhammad Tayyab Akram
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

/// Represents a frame containing multiple lines of text. It is the output resulting from
/// text-framing process performed by a typesetter.
public class ComposedFrame {
    let string: String

    init(string: String, codeUnitRange: Range<Int>, lines: [ComposedLine]) {
        self.string = string
        self.codeUnitRange = codeUnitRange
        self.lines = lines
    }

    /// The UTF-16 range of this frame in source string.
    public let codeUnitRange: Range<Int>

    /// The index to the first character of this frame in source string.
    public var startIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.lowerBound)
    }

    /// The index after the last character of this frame in source string.
    public var endIndex: String.Index {
        return string.characterIndex(forUTF16Index: codeUnitRange.upperBound)
    }

    /// The width of this frame.
    public internal(set) var width: CGFloat = .zero

    /// The height of this frame.
    public internal(set) var height: CGFloat = .zero

    /// The array containing all the lines of this frame.
    public let lines: [ComposedLine]

    /// Returns the index of line containing the specified UTF-16 code unit index.
    ///
    /// - Parameter index: The index of UTF-16 code unit for which to return the line index.
    /// - Returns: The index of line containing the specified UTF-16 code unit index.
    public func indexOfLine(forCodeUnitAt index: Int) -> Int {
        precondition(index >= codeUnitRange.lowerBound && index <= codeUnitRange.upperBound, String.indexOutOfRange)

        var low = 0
        var high = lines.count - 1

        while low <= high {
            let mid = (low + high) >> 1
            let lineRange = lines[mid].codeUnitRange

            if index >= lineRange.upperBound {
                low = mid + 1
            } else if index < lineRange.lowerBound {
                high = mid - 1
            } else {
                return mid
            }
        }

        return -1
    }

    /// Returns the index of line containing the specified character index.
    ///
    /// - Parameter index: The index of character for which to return the line index.
    /// - Returns: The index of line containing the specified character index.
    public func indexOfLine(forCharacterAt index: String.Index) -> Int {
        precondition(index >= startIndex && index <= endIndex, String.indexOutOfRange)

        return indexOfLine(forCodeUnitAt: string.utf16Index(forCharacterAt: index))
    }

    /// Returns the index of a suitable line representing the specified position.
    ///
    /// - Parameter position: The position for which to return the line index.
    /// - Returns: The index of a suitable line representing the specified position.
    public func indexOfLine(at position: CGPoint) -> Int {
        let lineCount = lines.count

        for i in 0 ..< lineCount {
            let line = lines[i]

            if position.y >= line.top && position.y <= line.bottom {
                return i
            }
        }

        return lineCount - 1
    }

    private func addSelectionParts(of line: ComposedLine, range: Range<Int>, in path: CGMutablePath) {
        let visualEdges = line.visualEdges(forCodeUnitRange: range)

        let edgeCount = visualEdges.count
        var edgeIndex = 0

        while edgeIndex < edgeCount {
            let edgeLeft = visualEdges[edgeIndex] + line.left
            let edgeRight = visualEdges[edgeIndex + 1] + line.left

            path.addRect(left: edgeLeft, top: line.top, right: edgeRight, bottom: line.bottom)

            edgeIndex += 2
        }
    }

    /// Creates a path that contains a set of rectangles covering the specified UTF-16 code unit range.
    ///
    /// - Parameter codeUnitRange: The selection range in source string.
    /// - Returns: A path that contains a set of rectangles covering the specified UTF-16 range.
    public func selectionPath(forCodeUnitRange codeUnitRange: Range<Int>) -> CGPath {
        let selectionPath = CGMutablePath()

        let firstIndex = indexOfLine(forCodeUnitAt: codeUnitRange.lowerBound)
        let lastIndex = indexOfLine(forCodeUnitAt: codeUnitRange.upperBound - 1)

        let firstLine = lines[firstIndex]
        let lastLine = lines[lastIndex]

        if firstLine === lastLine {
            addSelectionParts(of: firstLine, range: codeUnitRange, in: selectionPath)
        } else {
            let firstRange = firstLine.codeUnitRange
            let lastRange = lastLine.codeUnitRange

            let frameLeft: CGFloat = 0.0
            let frameRight = width

            // Select each intersecting part of first line.
            addSelectionParts(of: firstLine,
                              range: codeUnitRange.lowerBound ..< firstRange.upperBound,
                              in: selectionPath)

            // Select trailing padding of first line.
            if (lastLine.paragraphLevel & 1) == 1 {
                selectionPath.addRect(left: frameLeft, top: firstLine.top,
                                      right: firstLine.left, bottom: firstLine.bottom)
            } else {
                selectionPath.addRect(left: firstLine.right, top: firstLine.top,
                                      right: frameRight, bottom: firstLine.bottom)
            }

            // Select whole part of each mid line.
            for i in firstIndex + 1 ..< lastIndex {
                let midLine = lines[i]

                selectionPath.addRect(left: frameLeft, top: midLine.top,
                                      right: frameRight, bottom: midLine.bottom)
            }

            // Select leading padding of last line.
            if (lastLine.paragraphLevel & 1) == 1 {
                selectionPath.addRect(left: lastLine.right, top: lastLine.top,
                                      right: frameRight, bottom: lastLine.bottom)
            } else {
                selectionPath.addRect(left: frameLeft, top: lastLine.top,
                                      right: lastLine.left, bottom: lastLine.bottom)
            }

            // Select each intersecting part of last line.
            addSelectionParts(of: lastLine,
                              range: lastRange.lowerBound ..< codeUnitRange.upperBound,
                              in: selectionPath)
        }

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
