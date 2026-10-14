//
// Copyright (C) 2026 Muhammad Tayyab Akram
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

/// Locates the lines of a `ComposedFrame` that are visible in a rectangle, without looking at all
/// of them. A view that shows a long text uses it to find the lines to show.
///
/// The locator keeps a box for each line, in the coordinates of the frame. The box of a line is the
/// union of the rectangle that spans the width of the frame from the top to the bottom of the line,
/// and the ink box of its glyphs, which can be taller than the line. The edges of the boxes are
/// rounded outward to integers, and the boxes of the lines can overlap.
// Unchecked because the locator of Core is immutable.
public final class LineLocator: @unchecked Sendable {
    private let core: TRLineLocatorRef

    init?(frame: TRComposedFrameRef, renderer: Renderer) {
        guard let core = TRLineLocatorCreate(frame, renderer.core) else {
            return nil
        }

        self.core = core
    }

    deinit {
        TRLineLocatorRelease(core)
    }

    /// The number of lines of the frame that this locator was made from.
    public var lineCount: Int {
        return Int(TRLineLocatorGetLineCount(core))
    }

    /// Returns the box of a line, in the coordinates of the frame.
    ///
    /// - Parameter lineIndex: The index of the line.
    /// - Returns: The box of the line, which has integral edges.
    public func box(ofLineAt lineIndex: Int) -> CGRect {
        precondition(lineIndex >= 0 && lineIndex < lineCount, "Line index is out of range")

        var box = TRRect()
        TRLineLocatorGetLineBox(core, TRUInteger(lineIndex), &box)

        return CGRect(box)
    }

    /// Passes the lines whose boxes intersect a rectangle to the body. Two rectangles intersect if
    /// they overlap by more than their edges, so a box that only touches the rectangle is not
    /// passed. Each line is passed once.
    ///
    /// The lines come in the order of the frame, unless the ink of a line reaches into a band above
    /// the lines before it, in which case that line comes first.
    ///
    /// - Parameters:
    ///   - rect: The rectangle in the coordinates of the frame. It can be bigger than the frame, or
    ///           lie outside of it, in which case no line is passed. Its origin and size can be
    ///           infinite.
    ///   - body: The closure to call for each line. It gets the index of the line, and can set the
    ///           stop flag to end the enumeration.
    public func enumerateLines(in rect: CGRect, _ body: (Int, inout Bool) -> Void) {
        precondition(!rect.isNull && rect.width >= 0.0 && rect.height >= 0.0, "Rect is not valid")

        withoutActuallyEscaping(body) { (body) in
            var context = body

            withUnsafeMutablePointer(to: &context) { (pointer) in
                _ = TRLineLocatorEnumerateLines(
                    core,
                    rect.coreValue,
                    { (userData, lineIndex, stop) in
                        let body = userData!.assumingMemoryBound(to: ((Int, inout Bool) -> Void).self)
                        var shouldStop = false

                        body.pointee(Int(lineIndex), &shouldStop)
                        if shouldStop {
                            stop!.pointee = 1
                        }
                    },
                    pointer
                )
            }
        }
    }

    /// Finds the lines whose boxes intersect a rectangle, reusing the array that is given so that
    /// calls that follow each other, as when scrolling, do not allocate once it has grown enough.
    ///
    /// - Parameters:
    ///   - rect: The rectangle in the coordinates of the frame.
    ///   - indexes: The array that receives the indexes of the lines, each of them once. Its
    ///              previous contents are removed, but its capacity is kept.
    public func findLines(in rect: CGRect, into indexes: inout [Int]) {
        indexes.removeAll(keepingCapacity: true)

        // The array is only touched through the pointer while the enumeration runs.
        withUnsafeMutablePointer(to: &indexes) { (pointer) in
            _ = TRLineLocatorEnumerateLines(
                core,
                rect.coreValue,
                { (userData, lineIndex, _) in
                    userData!.assumingMemoryBound(to: [Int].self).pointee.append(Int(lineIndex))
                },
                pointer
            )
        }
    }

    /// Returns the index of the first line whose box reaches below a vertical position, which means
    /// that the bottom of its box is greater than the position.
    ///
    /// - Parameter y: The vertical position in the coordinates of the frame.
    /// - Returns: The index of the line, or `nil` if no box reaches below the position.
    public func indexOfFirstLine(below y: CGFloat) -> Int? {
        let lineIndex = TRLineLocatorGetFirstLineIndexBelow(core, TRFloat(y))

        // The macro `TRInvalidIndex` is a cast, which Swift does not import.
        return (lineIndex != TRUInteger.max ? Int(lineIndex) : nil)
    }
}
