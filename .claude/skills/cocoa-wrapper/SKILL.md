---
name: cocoa-wrapper
description: Rules, conventions and workflow for wrapping Tehreer Core in Tehreer-Cocoa (Swift 6.2, iOS). Use when the Core API changes and the Cocoa wrapper has to follow, when adding a Swift class or bridging extension for a Core object, when moving logic from Swift into Core, or when verifying the wrapper against Android.
---

# Wrap Tehreer Core in Tehreer-Cocoa

The Cocoa repo is `/Users/mta/Personal/UrduFeeds/tehreerCocoa` (SwiftPM package `TehreerCocoa`, iOS 12+, Swift 6.2 language mode, branch `v4`). `Libraries/TehreerCore` is a git submodule of Core and is compiled as a unity build (`Source/Tehreer.c`, `TR_CONFIG_UNITY`, `SB_CONFIG_EXPERIMENTAL_TEXT_API`) by the `Tehreer` target in `Package.swift`. Sibling wrapper: `android-wrapper` skill (`/Users/mta/Personal/UrduFeeds/tehreerAndroid`); the two public APIs are kept on par.

## 1. Principles

1. **Core owns the logic.** Layout, shaping, matching, drawing math, run backgrounds and decorations, cluster/caret math, typeface registry and CSS style matching live in Core. Swift never re-implements them. If Cocoa needs a rule Core lacks, add it to Core (with tests there), then bridge it.
2. **The bridge is thin.** A Swift member converts arguments, calls one `TR*` function, converts the result. No algorithms, no mirrored state, except what Core cannot give (section 6).
3. **Swift keeps Apple/Swift terminology, not Core's.** `CGFloat`, `CGRect`, `UIColor`, `NSAttributedString`, `CGContext`, `Range<Int>`, `String.Index`, `TypefaceTag = Int` / `TypeFamilyID = Int` (Core's integers, no mapping), `drawStyle`, `strokeRadius`. Core words are mirrored when they say something new (`computeInkBox`, `isScalable`, `bitmapStrikes`), not when they are only C idiom (`GetStartIndex/GetEndIndex` → `codeUnitRange`).
4. **API compatibility is not sacred.** Break Swift API when it lets the wrapper follow Core more directly; say so in the summary.
5. **Conversions are lazy.** Never convert Core data into Swift arrays/objects in an initializer. Read from Core when the property is asked for, or build once on first use, thread safely (section 4).
6. **Apple-only concerns stay in Swift:** `NSAttributedString` ↔ attributes, `CGContext` painting through the draw callbacks, shadows, `TextReplacement`/`ViewAttachment` drawing, UIKit/SwiftUI views (`TLabel`, `TTextView`, `StyledText`, …).
7. **Names follow Core where Core says it better.** `DrawStyle` (not rendering style), `strokeRadius` (not width), ink box, `isScalable`. Keep the same default values as Core (stroke radius 0.5) so no scaling code is needed.
8. **No deprecated API, Swift 6.2 clean.** The build must show no warnings from `Source/` (`xcodebuild … | grep warning: | grep -v Libraries/`). Replace a deprecated call (`String(cString: array)`, `SBScriptGetOpenTypeTag`) instead of silencing it.

## 1a. Code style of the wrapper

- **Copyright header.** A newly introduced file says `Copyright (C) 2026 Muhammad Tayyab Akram`. A file that already existed and is touched gets a range from its first year to 2026 (`2019-2026`; a single old year becomes `2019-2026`; a file first written in 2026 stays `2026`). Check with `git status`: new/untracked files have one year, modified files end with `-2026`.
- **No dots in file names** besides the extension: `Renderer+Tehreer.swift`, not `Renderer.RenderingStyle+Tehreer.swift`. Put the conversions of nested types in the file of their outer type (`Typeface+Tehreer.swift` has `Weight`, `Width`, `Slope`).
- **Calls break only when they do not fit in 100 columns.** A call that fits stays on one line, however many arguments it has. A call that does not fit uses the modern style: the line ends with the opening parenthesis, every argument has a line of its own (indented 4 more than the line that holds the call), and the closing parenthesis starts a line with the indentation of the call:
  ```swift
  let frame = TRFrameResolverCreateFrame(
      core,
      TRUInteger(codeUnitRange.lowerBound),
      TRUInteger(codeUnitRange.count)
  )
  ```
  Calls with a single argument, declarations, patterns (`case .foo(let a, let b)`), attributes, strings and comments are not rewritten. Nested calls are judged on their own line after the outer one is broken. The check is the line length of the whole line (text before the call, the call joined with `, `, text after it), not the call alone. `format-calls.py` (next to this file) applies the rule to the added lines of the git diff (and to every line of new files): run it from the Cocoa repo root as `python3 .claude/skills/cocoa-wrapper/format-calls.py [file …]`, then build and run the tests, because it is a text-level tool (it skips strings, comments, declarations and patterns, but review the diff).

## 2. Layout

```
Source/
  Bridging/    one file per EXTENDED type, named <Type>+Tehreer.swift (section 3)
  Collections/ IntrinsicCollection, CoreCollection, PrimitiveCollection (lazy views over Core memory)
  Graphics/    Typeface, FontFile, FontStream, TypefaceManager, TypeFamily, Renderer, GlyphImage, GlyphCache, GlyphLayers,
               VariationAxis, NamedStyle, ColorPalette, BitmapStrike, Type{Weight,Width,Slope}
  Layout/      Typesetter (+MutableTypesetter), BoundaryType, FrameResolver, ComposedFrame/Line, GlyphRun, TextReplacement, ...
  SFNT/        ShapingEngine, ShapingResult, SFNTTag, Tables/ (Head, Hhea, Maxp, OS2, Post, Name)
  Unicode/     SheenBidi wrappers (Bidi*, Script, CodePoint, BidiClass, GeneralCategory)
  Utilities/   Mutex, Locked, Lazy
  Views/ SwiftUI/   UI only
Tests/         XCTest, uses the fixture fonts of Core (TestFonts.path → Libraries/TehreerCore/Tests/Fonts)
```

Every file that touches `TR*` has `internal import Tehreer` (SheenBidi: `internal import SheenBidi`). Core types must never appear in a public or `@inlinable` signature; keep them in `private`/internal members.

## 3. Bridging extensions (`<Type>+Tehreer.swift`)

Conversions between a Core value type and a Swift/Foundation/CG/UIKit type live in **one extension file per extended type**, in `Source/Bridging/`, named after the extended type:

| File | Content |
|------|---------|
| `String+Tehreer` | `init(_ view: UnsafePointer<TRStringView>?)`, `init(coreCharacters:length:)`, `withCoreView` (UTF-8 view) |
| `UIColor+Tehreer` | `init(coreValue:)`, `coreValue` (ARGB) |
| `CGRect+Tehreer` | `init(_ TRRect)`, `init(inkBox:)` (empty box → `.null`) |
| `CGPoint+Tehreer`, `CGAffineTransform+Tehreer` | `init(_ TRPoint)` / `coreValue` |
| `CGPath+Tehreer` | `coreCallbacks` (TRPathCallbacks that fill a `CGMutablePath`), `make(from:transform:)` |
| `WritingDirection/ShapingOrder/BreakMode/TruncationPlace/TextAlignment/VerticalAlignment+Tehreer` | `coreValue` (+ `init(coreValue:)` when read back) |
| `Renderer+Tehreer` | `coreValue` for `Renderer.DrawStyle`, `StrokeCap`, `StrokeJoin` |
| `Typeface+Tehreer` | `init(coreValue:)`/`coreValue` (via `rawValue`) for `Typeface.Weight`, `Width`, `Slope` |
| `TRAttribute+Tehreer` | builders (`.typeSize(_)`, `.backgroundColor(_)`, `.underline()` …), `attributes(of: NSParagraphStyle)`, `defaults(from:objects:)` |
| `TextReplacement+Tehreer` | `makeCoreReplacement()` (callbacks box) |

Rules:
- Enum mappings are **explicit switches**, never `rawValue` casts, when the Swift raw values differ from Core's (`BreakMode.character` is 0, `TRBreakModeCharacter` is 1). `Typeface.Weight/Width/Slope` are the exception: their raw values are Core's constants, so they convert through `rawValue`.
- Naming: `coreValue` for Swift → Core, `init(coreValue:)` for Core → Swift. Use `CGRect(x)`, `CGPoint(x)` for Core structs.
- A wrapper class keeps its own `core` reference, lifetime and public API in its own file (`Typeface.swift`); only conversions go to `+Tehreer` files. New conversion needed → add to the existing file for that type, or create `<Type>+Tehreer.swift`.

## 4. Handles, lifetimes, laziness

- A wrapper class owns one Core reference: `let core: TRFooRef`; `deinit` releases it. No wrapper structs around handles.
- **Follow Core's ownership rule.** `Create`/`Copy` returns an owned reference: release in `deinit` (or `defer`). `Get` is not retained: `Retain` before keeping it (`Typeface(retaining:)` for `TRFontFileGetTypeface`). Objects owned by a parent (runs of a line, lines of a frame, data behind a pointer) are kept alive by holding the **owner** in the Swift object (`CoreCollection(owner:…)`, `private let owner: Typeface` in `VariationAxis`).
- When Core takes an attribute value (replacement, font features, typeface) it retains it; release your own reference after `TRTypesetterSetAttribute` (font features) or keep the creation reference for the lifetime of the mutable text so equal ranges keep merging (`MutableTypesetter.replacementCores`).
- Core objects are immutable and thread safe after creation → mark the wrapper `@unchecked Sendable` with a comment saying why. `Renderer` and `MutableTypesetter` are mutable configuration objects and are not thread safe.
- **Bulk data is not copied.** Per-element data (glyph IDs, advances, axes, palettes, bitmap strikes, named styles, coordinates, entries) is exposed as `PrimitiveCollection<T>` built on `CoreCollection(owner:pointer:count:convert:)`: it reads Core memory on every access and converts one element at that moment. Value types over Core structs (`VariationAxis`, `NamedStyle`, `ColorPalette`) hold the owner plus the raw Core struct and compute each property on access; nested lists are collections too.
- **Scalars are read at the spot** (`ascent`, `weight`, `isScalable`, …). Anything costly to convert and used repeatedly (names as `String`, `TText.string`, `TText.attributedString`, the runs of a line, the lines of a frame) goes through `Lazy<Value>`: `private let cache = Lazy<T>()`; `cache.get { make() }` is made once, thread safely (mutex), on first use. Never compute in `init`.
- Passing a Swift array to a `void *` context parameter passes its element buffer, not the array. Use `withUnsafeMutablePointer(to: &array) { … }` for the user data of enumeration callbacks.
- C callbacks are closures without captures: pass `self`/contexts through `Unmanaged.passUnretained(x).toOpaque()` and recover with `takeUnretainedValue()`.

## 5. Mapping rules (Core → Swift)

| Core | Swift |
|------|-------|
| `index` + `length` | `Range<Int>` (`codeUnitRange`) and `Range<String.Index>` (`characterRange`) overloads; the character overloads convert with `String.utf16Range/utf16Index` helpers only |
| `…GetStartIndex/GetEndIndex` | `codeUnitRange` |
| `TRBoolean` out-flag (`…Distance(…,&d)`) | initialise the out value, ignore the flag when a Swift `precondition` already range-checked |
| `TRInvalidIndex` / `NULL` for invalid | `nil` or `-1` (documented), or `precondition(…, .indexOutOfRange)` for programmer errors |
| callbacks with `TRBoolean *stop` | closures accept the `stop` parameter, ignored unless early exit is needed |
| `TRStringView` | `String(view)` (all encodings) / `withCoreView` |
| `TRColor` | `UIColor(coreValue:)` / `.coreValue` |
| `TRRect` | `CGRect(_:)`; ink boxes with `CGRect(inkBox:)` (null when empty) |
| `TRPath` | `CGPath.make(from:transform:)` |
| stroke radius | `Renderer.strokeRadius` is passed to Core as it is (default 0.5); views and SwiftUI modifiers use `strokeRadius` too |
| draw style | `Renderer.DrawStyle` (`fill`, `stroke`, `fillStroke`) ↔ `TRDrawStyle`; the property is `drawStyle` |
| truncation | `truncationPlace` + `isTruncationEnabled` map to `TRFrameResolverSetTruncationPlace` and `…SetTruncationEnabled`; views and SwiftUI expose both |
| `TRTypefaceRef` returned by Core | map back to the Swift object through a dictionary kept by the owner (`CoreTextObjects.typefaces`, `TypefaceManager.State.typefaces`) |

## 6. State the wrapper may keep

Only what Core cannot provide: the Swift object for a Core pointer (typefaces, replacements: `CoreTextObjects`), the Swift object of a registered Core typeface in `TypefaceManager` (tags and family IDs are Core's own `Int`s, nothing is mapped), the `Renderer` values Core has no getters for (colors, radius, shadow), the CoreGraphics layer cache attached to a glyph image (`TRGlyphImageSetNativeData`, read through `GlyphImage.layer`), and the source `NSAttributedString` of a `Typesetter` (keeps attributes Core does not know, such as `.link`). Everything else is asked from Core each time.

## 7. Text and layout: `Typesetter` / `MutableTypesetter`

Core merged the text into the typesetter, so Swift has no separate text class. `Typesetter` exposes `TRTypesetter` (immutable, thread safe): the text (`string`, `attributes(at:)`, `attributedString`), boundaries (`findBoundary`, `boundaryRange`) and the lines. `MutableTypesetter` exposes the mutable one (begin/endEditing, append, insert, delete, replace, setString, setAttribute(s), removeAttribute). Default attributes (typeface, size, ...) are given when a typesetter is created, never later. Core shapes each paragraph when it is made or changed, and an editing batch defers that to `endEditing()`: attributes can be set and removed inside a batch (build a text with many attributes in one, as `MutableTypesetter(attributedString:)` does), but no line, break, boundary or copy is available there. Both talk in `NSAttributedString.Key`s:

| Key | Core attribute |
|-----|----------------|
| `.typeface` (`Typeface`), `.typeSize`, `.scaleX`, `.scaleY`, `.baselineOffset`, `.obliqueness` | Typeface, TypeSize, ScaleX, ScaleY, BaselineOffset, Obliqueness |
| `.replacement` (`TextReplacement`) | Replacement (one per object, via `makeCoreReplacement`; `ViewAttachment` decides inline/block) |
| `.foregroundColor`, `.backgroundColor` | ForegroundColor, BackgroundColor |
| `.underlineStyle`, `.strikethroughStyle` (non-zero) | Underline, Strikethrough (zero removes) |
| `.underlineColor` / `.strikethroughColor` | DecorationColor (one colour for both; underline wins in `setAttributes`) |
| `.language` (BCP 47 string) | Language (`TRShapingEngineGetLanguageTagForName`) |
| `.fontFeatures` (`[SFNTTag: Int]`) | FontFeatures |
| `.paragraphStyle` | alignment (always), indents, spacing, line heights (only when non-zero) |

`Typesetter(text: NSAttributedString, defaultAttributes:)` builds a mutable typesetter (string first, then the attributes, outside a batch), then an immutable copy; `attributes(at:)`/`attributedString` convert back (the original string is returned when the text came from one). To support a new Core attribute: add a builder in `TRAttribute+Tehreer`, a case in `MutableTypesetter.setAttribute`/`removeAttribute`, the reverse case in `Typesetter.attributes(at:)`, a custom `NSAttributedString.Key` in `NSAttributedString+Keys.swift` if UIKit has none, and a test.

Core has no view-level object: `TLabel` and `TTextView` (a `UIScrollView` over a `TextContainer`) keep the platform logic (typesetting in the background, line views and their recycling, the line locator operation, link interaction, view attachments, the scroll anchor) and use `FrameResolver`, `ComposedFrame`, `LineLocator` and the `Typesetter` directly.

## 7a. Typeface registry, frame resolver, glyph buffers

- `TypefaceManager.register(_:forTag:familyID:)` passes `TypefaceTag`/`TypeFamilyID` (both `Int`, 0 = none) straight to `TRTypefaceManagerRegisterTypeface` and preconditions on failure (already registered, tag taken). `typeface(forTag:)`, `tag(of:)` (0 when none), `familyID(of:)`, CSS matching by ID or by name, `availableTypefaces`, `availableFamilies` all ask Core; the only state is `[TRTypefaceRef: Typeface]` behind a `Locked`.
- `FrameResolver` owns a `TRFrameResolverRef` created in `init` and pushes every property to Core in its `didSet` (Core has no getters, so `init` also sends the defaults of the Swift properties). `makeFrame` only calls `TRFrameResolverCreateFrame`. `truncationPlace` (non-optional, `.end`) and `isTruncationEnabled` (default `false`) mirror the two Core setters; never fold them into one optional. It is a mutable configuration object, not thread safe.
- **Glyph buffers are not copied.** `Renderer.generatePath/computeInkBox/drawGlyphs` take `PrimitiveCollection<GlyphID>`, `<CGPoint>` and `<CGFloat>` (what `GlyphRun` and `ShapingResult` return). `PrimitiveCollection.withCoreBuffer` hands Core the memory behind a `CoreCollection` (`IntrinsicCollection.coreBuffer`) with no copy; only a collection that is not backed by Core (an array literal in a test) is converted into a temporary buffer. Generic `RandomAccessCollection` overloads wrap their arguments with `PrimitiveCollection(…)` and call the main one. `ShapingResult.glyphIDs/glyphOffsets/glyphAdvances/clusterMap` are `PrimitiveCollection`s built on `CoreCollection`, like the runs'.

## 8. Drawing

Core draws; Swift supplies primitives.

- `GlyphRun.draw`, `ComposedLine.draw`, `ComposedFrame.draw` call `TRGlyphRunDraw`, `TRComposedLineDraw`, `TRComposedFrameDraw` inside `renderer.withDrawing(in: context, objects:)`. `ComposedLine.draw` subtracts the line origin so that it draws at the current position of the context (Core adds it).
- `Renderer.init` installs `TRDrawCallbacks` (`drawGlyphImage`, `fillRect`, `drawReplacement`) with the renderer as user data; `deinit` clears them. No `drawGlyphPath`. `withDrawing` works in pixel space (rounds the device translation, scales by `1 / renderScale`) and stores the context and the replacement objects for the callbacks.
- Every `Renderer` property is pushed to Core in its `didSet`; Core restores the renderer after drawing, so there is no sync step.
- Glyph callbacks stay cheap: `saveGState` only for a clip or a visible shadow, cache the last `CGColor`, bitmap-font images are scaled by `scaleX/scaleY`.

## 9. Parity with Android

Public API stays on par with `tehreerAndroid` (`/Users/mta/Personal/UrduFeeds/tehreerAndroid/tehreer-android/src/main/java/com/mta/tehreer`), in Swift terms: Typeface (+tables, bitmap strikes, glyph names, variants), FontFile, TypefaceManager/TypeFamily, Renderer, GlyphCache, ShapingEngine/Result, Typesetter, FrameResolver, ComposedFrame/Line, GlyphRun, BidiAlgorithm/Paragraph/Line/Run/Pair, ScriptClassifier/Run, CodePoint/BidiClass/GeneralCategory/Script, SFNT tables (Head, Hhea, Maxp, OS/2, Post, Name), widgets. To check after a change, list the public members of the Kotlin class and compare with the Swift one. Differences that are deliberate: `Spanned` spans vs `NSAttributedString` keys; `Script.openTypeTag` is not offered because `SBScriptGetOpenTypeTag` is deprecated (`Script.unicodeTag` instead); `Name` record locales are known only for Windows records.

## 10. Updating the wrapper after a Core change

1. `git -C <core> diff <old>..<new> -- Headers/Tehreer`; read the Doxygen of each change (ownership, ranges, `stop`).
2. Move the submodule (Core commits not pushed are not on GitHub):
   ```bash
   cd /Users/mta/Personal/UrduFeeds/tehreerCocoa/Libraries/TehreerCore
   git fetch /Users/mta/Learning/Tehreer-Core main && git checkout <sha>
   ```
   Core changes are made and tested in the Core repo, never in the submodule copy.
3. Build and let the compiler find call sites:
   ```bash
   xcodebuild build -scheme TehreerCocoa -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>
   ```
   (`swift build` fails on macOS: no UIKit.) Fix bridging files first, then wrappers, then views, tests, Demo.
4. **Coverage check.** List `TR_PUBLIC` functions and the ones never used in Swift:
   ```bash
   cat Source/*/*.swift Source/*/*/*.swift Tests/*.swift > /tmp/_all.swift
   for f in Libraries/TehreerCore/Headers/Tehreer/TR*.h; do grep TR_PUBLIC $f | grep -oE 'TR[A-Za-z0-9]+\(' | tr -d '(' | sort -u | while read fn; do grep -qw $fn /tmp/_all.swift || echo "$(basename $f .h): $fn"; done; done
   ```
   What remains must be deliberate (Retain/Release pairs, `TRReplacementComputeRoom`, `TRGlyphRunGetUserData`, `TRSheenBidi`, `TRVersionGetString` which Core never defines: use `TEHREER_VERSION_STRING`).
5. **Adopt, don't just port**: delete wrapper logic Core now owns; expose new Core capabilities with Swift names; update Android parity (section 9) and this skill when a rule changes.
6. Zero warnings from `Source/`; then tests and Demo (section 11).
7. Commit only when asked; tag `[lib]`/`[test]`; stage explicit files (not `.build/`).

## 11. Testing

```bash
xcodebuild test -scheme TehreerCocoa -destination 'platform=iOS Simulator,id=<iPhone sim id>' -derivedDataPath <scratch> > log 2>&1
grep -E "error:|failed|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|Restarting" log
for s in DemoUIKit DemoSwiftUI; do xcodebuild build -project Demo/Demo.xcodeproj -scheme $s -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch2> CODE_SIGNING_ALLOWED=NO; done
```
- Run long jobs in the background with output to a file; keep derived data in the scratchpad and delete it afterwards (the disk is tight). A "Restarting after unexpected exit" line means a crash; read the lines before it.
- Never `pkill -f "xcodebuild test"` from a command containing that text (it kills its own shell).
- Tests: `RendererTests`, `TypesetterTests`, `TypesetterTextTests`, `DrawTests` (pixel counts on a bitmap), `TypefaceManagerTests` (unregister in `tearDown`; the manager is process-global), `TypefaceTests`, `FontFileTests`, `SFNTTableTests`, `TTextView*Tests`. Fixtures are the fonts of Core. Add a test for every bridged capability, next to the neighbouring one.

## 12. Gotchas

- `Typeface` has no initializers from a path, data or stream: use `FontFile(path:)`/`FontFile(data:)`/`FontFile(stream:)` and `.typefaces.first`; a face with named styles has one typeface per style (do not expand them in Swift).
- `Renderer.glyphImage(forGlyph:)`/`strokeImage(forGlyph:)` return a `GlyphImage` that owns the +1 `TRGlyphImageRef` of `TRRendererCreate…Image` (no pixels are exposed, only `layer`); `glyphPath(for:)` is the single glyph path (`TRRendererCreateGlyphPath`), `generatePath(…)` the run path. `Renderer.foregroundColor` (not fill) and `skewX` (Core ratio, not an angle) follow Core.
- `ComposedLine.runs` (visual order), `GlyphRun.isBackward/scaleX/scaleY`, `Typesetter.makeSimpleLine(codeUnitRange:layoutWidth:)` (width 0 = no frame; there is no frame line), `LineLocator(frame:renderer:)` is public (no `makeLineLocator`). `ComposedFrame.indexOfLine(forCodeUnitAt:)` gives the last line for the frame end. `Typeface.Weight/Width/Slope` stay Swift enums with Core's raw values; Core returns the raw OS/2 weight, which may lie between the constants.
- `SFNTTag` must accept a space as any byte (`0x20…0x7E`): Core returns tags such as `URD `.
- `dataOfTable(_:offset:length:)` pads nothing: it returns fewer bytes at the end of a table and `nil` past it; table readers pad to the newest version length themselves.
- A `GlyphRun` finds its `Typeface`/`TextReplacement` through `CoreTextObjects`; every object that makes runs (`Typesetter`, `ComposedLine`, `ComposedFrame`) passes the same value on.
- `PrimitiveCollection` is not `Array`: use `Array(collection)` where an array is needed (tests, demo).
- `TypefaceManager` keeps Swift objects alive while registered (Core retains the Core typeface only).
