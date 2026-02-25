# ROADMAP — markdraw

> An Excalidraw-inspired drawing tool built in Dart/Flutter with a human-readable markdown serialization format.
> TDD · SOLID · Cross-platform (iOS, Android, Web, macOS, Windows, Linux)

---

## Excalidraw Architecture Analysis

Before laying out the roadmap, here's what we learned from studying the Excalidraw codebase. This understanding informs every phase below.

### Core Data Model

Excalidraw's heart is a flat list of element objects, each sharing 26+ base properties (`id`, `type`, `x`, `y`, `width`, `height`, `angle`, `strokeColor`, `backgroundColor`, `fillStyle`, `strokeWidth`, `strokeStyle`, `roughness`, `opacity`, `roundness`, `seed`, `version`, `versionNonce`, `isDeleted`, `groupIds`, `frameId`, `boundElements`, `updated`, `link`, `locked`, `customData`, `index`). Specialized types extend this base:

| Category | Types | Key Extra Properties |
|---|---|---|
| **Geometric** | `rectangle`, `ellipse`, `diamond` | `roundness` |
| **Linear** | `line`, `arrow` (inc. elbow) | `points[]`, `startBinding`, `endBinding`, `startArrowhead`, `endArrowhead`, `elbowed` |
| **Freedraw** | `freedraw` | `points[]`, `pressures[]`, `simulatePressure` |
| **Text** | `text` | `text`, `originalText`, `fontSize`, `fontFamily`, `textAlign`, `verticalAlign`, `containerId`, `lineHeight`, `autoResize` |
| **Media** | `image` | `fileId`, `status`, `scale`, `crop` |
| **Containers** | `frame`, `magicFrame` | `name` |
| **Embeds** | `iframe`, `embeddable` | URL via `link` |

### Rendering Architecture

Excalidraw uses a **dual-canvas** approach: a **static canvas** (rendered with Rough.js for the hand-drawn look, throttled to ~60fps, cached and only redrawn when elements change) and an **interactive canvas** (continuously animated for selection handles, cursors, snap lines, drag previews). A `Renderer` class filters elements by viewport bounds and memoizes results using a `sceneNonce` cache-invalidation token.

### Serialization

The `.excalidraw` JSON format wraps `{ type, version, source, elements[], appState{}, files{} }`. Elements are serialized verbatim. AppState is cleaned (transient UI state stripped). Files are stored as base64 data URLs keyed by `fileId`. Scene data can also be embedded in PNG metadata chunks and SVG comments for round-trip portability.

### Key Architectural Patterns

- **Immutable elements** — elements are never mutated; new versions are created with incremented `version` and fresh `versionNonce`.
- **Soft deletion** — `isDeleted: true` rather than removing from the array, enabling undo and collaboration.
- **Fractional indexing** — the `index` property uses fractional strings for ordering without renumbering.
- **Binding system** — arrows maintain `startBinding`/`endBinding` references to other elements via `FixedPointBinding` objects (element ID + fixed point ratio).
- **LinearElementEditor** — a state machine managing multi-point creation (click-to-add-point) and editing (drag-to-move-point) with shift-lock, grid snapping, and binding suggestions.
- **Action system** — commands are first-class objects with `perform()`, `keyTest()`, and UI metadata, dispatched through an `ActionManager`.

### Flutter Ecosystem Alignment

- **`rough_flutter`** — a maintained Dart 3 port of Rough.js with null safety. Supports rectangle, circle, ellipse, line, polygon, arc, and path primitives with hachure, solid, cross-hatch, zigzag, dots, and dashed fills. This is our rendering foundation.
- **Flutter `CustomPainter`** — maps directly to Excalidraw's canvas rendering model. We'll use two `CustomPainter` layers (static + interactive) on a `Stack`.
- **`GestureDetector` / `Listener`** — Flutter's gesture system maps cleanly to Excalidraw's pointer event handling.

---

## The Markdown Extension: `.markdraw` Format

The serialization format is the differentiating feature. It's a superset of markdown that embeds drawing instructions in fenced code blocks while allowing free-form prose around them.

### Format Specification (Target)

````markdown
---
markdraw: 1
background: "#ffffff"
grid: 20
---

# Architecture Overview

Here's how the services connect:

```sketch
rect "Auth Service" id=auth at 100,200 size 160x80 fill=#e3f2fd rounded
rect "API Gateway" id=gateway at 350,200 size 160x80 fill=#fff3e0 rounded
arrow from auth to gateway label="JWT tokens" stroke=dashed
ellipse "Database" id=db at 225,400 size 120x80 fill=#e8f5e9
arrow from gateway to db label="queries"
```

The auth service handles OAuth2 flows. All inter-service
communication uses mTLS.

```sketch
text "High Priority" at 100,50 size=24 color=#d32f2f bold
freedraw points=[[0,0],[5,2],[10,8],...] pressure=[0.5,0.7,0.9,...] color=#1e1e1e
line points=[[0,0],[100,0],[100,100]] closed stroke=dotted
```
````

### Format Design Principles

1. **Human-readable primitives** — named shapes use natural syntax: `rect "Label" at X,Y size WxH`
2. **ID-based references** — elements get `id=name` for arrow binding: `arrow from auth to gateway`
3. **Familiar styling** — CSS-like: `fill=#e3f2fd stroke=dashed color=#1e1e1e`
4. **Lossless freehand** — point arrays and pressure data stored inline for round-trip fidelity (not expected to be hand-edited)
5. **Mixed content** — prose markdown sections interleave freely with `sketch` blocks
6. **YAML frontmatter** — canvas-level settings (background, grid, zoom)
7. **Git-friendly** — text diffs show meaningful changes

---

## Project Structure

```
markdraw/
├── lib/
│   ├── core/                    # Domain layer (no Flutter imports)
│   │   ├── elements/            # Element models & base types
│   │   ├── scene/               # Scene graph, element collection
│   │   ├── math/                # Geometry, vectors, bounds
│   │   ├── history/             # Undo/redo stack
│   │   └── serialization/       # .markdraw parser & serializer
│   ├── rendering/               # Flutter rendering layer
│   │   ├── painters/            # CustomPainters (static + interactive)
│   │   ├── rough/               # Rough drawing adapter
│   │   └── viewport/            # Pan, zoom, viewport culling
│   ├── editor/                  # Editor logic & state
│   │   ├── tools/               # Tool implementations (select, rect, arrow...)
│   │   ├── actions/             # Action system (command pattern)
│   │   └── bindings/            # Arrow binding logic
│   ├── ui/                      # Flutter widgets & layout
│   │   ├── canvas/              # Canvas widget stack
│   │   ├── toolbar/             # Tool selection bar
│   │   ├── properties/          # Property panel
│   │   └── text_editor/         # Inline text editing
│   └── app.dart                 # App entry point
├── test/
│   ├── core/                    # Unit tests (pure Dart, no Flutter)
│   ├── rendering/               # Widget tests
│   ├── editor/                  # Integration tests
│   ├── serialization/           # Round-trip & parser tests
│   └── golden/                  # Golden image tests for rendering
├── integration_test/            # E2E tests per platform
├── excalidraw/                  # Excalidraw source reference (read-only)
└── pubspec.yaml
```

---

## Phase 0 — Foundation (Weeks 1–2)

> Goal: Project scaffold, CI, core abstractions, and the first passing test.

### 0.1 Project Setup
- [x] Initialize Flutter project with multi-platform targets
- [x] Configure linting (`flutter_lints` strict mode + custom rules)
- [x] Set up CI (GitHub Actions: test, analyze, coverage on every PR)
- [x] Add dependencies: `uuid`, `equatable`, `freezed`
- [x] Configure code coverage reporting (80% threshold enforced in CI)
- [x] Clone excalidraw repo into `./excalidraw/` for reference

### 0.2 Core Element Model
- [x] `Element` base class with all 26 shared properties (immutable, manual `copyWith`)
- [x] `ElementId` value object (UUID-based generation)
- [x] `Point`, `Size`, `Bounds` value objects in `core/math/`
- [x] `StrokeStyle` enum: `solid`, `dashed`, `dotted`
- [x] `FillStyle` enum: `solid`, `hachure`, `crossHatch`, `zigzag`
- [x] `Roundness` value object with `adaptive` and `proportional` variants
- [x] **Tests**: Element creation, equality, copyWith, version bumping, soft deletion

### 0.3 Element Type Hierarchy
- [x] `RectangleElement` — base geometric, `roundness` property
- [x] `EllipseElement` — bounding-box defined
- [x] `DiamondElement` — midpoint vertices
- [x] `TextElement` — `text`, `fontSize`, `fontFamily`, `textAlign`, `containerId`
- [x] `LineElement` — `points[]`, `startArrowhead`, `endArrowhead`
- [x] `ArrowElement extends LineElement` — `startBinding`, `endBinding`
- [x] `FreedrawElement` — `points[]`, `pressures[]`, `simulatePressure`
- [x] **Tests**: Each type constructs correctly, copyWith works, type-specific methods

### 0.4 Scene Model
- [x] `Scene` class — ordered collection of elements, CRUD operations
- [x] Immutable element updates (new version, bumped `versionNonce`)
- [x] Soft deletion (`isDeleted` flag)
- [x] Fractional index ordering
- [x] `getElementAtPoint(Point)` — hit testing placeholder (bounds-only)
- [x] **Tests**: Add/remove/update elements, ordering, soft delete, version bumping

> **TDD checkpoint**: All core model tests pass (120 tests). Zero Flutter imports in `core/`. CI green with coverage enforcement. ✅

---

## Phase 1 — Markdown Serialization (Weeks 3–5)

> Goal: Parse and serialize the `.markdraw` format with full round-trip fidelity.
> This is front-loaded because the format IS the product differentiator.

### 1.1 Lexer & Parser
- [x] YAML frontmatter parser (canvas settings)
- [x] Markdown section splitter (prose blocks vs `sketch` fenced blocks)
- [x] Sketch block tokenizer: keywords (`rect`, `ellipse`, `diamond`, `arrow`, `line`, `text`, `freedraw`)
- [x] Property parser: `at X,Y`, `size WxH`, `fill=`, `stroke=`, `color=`, `id=`, `rounded`
- [x] Arrow reference resolver: `from <id> to <id>`
- [x] Point array parser: `points=[[x,y],[x,y],...]`
- [x] Pressure array parser: `pressure=[0.5,0.7,...]`
- [x] **Tests**: Tokenization of every element type, error recovery on malformed input

### 1.2 Serializer
- [x] `Scene` → `.markdraw` string serialization
- [x] Human-readable output for geometric and text elements
- [x] Compact but parseable output for freedraw (point arrays)
- [x] Prose section preservation (round-trip fidelity)
- [x] YAML frontmatter emission
- [x] **Tests**: Serialize → parse → serialize produces identical output

> **TDD checkpoint**: Parser & serializer complete with round-trip fidelity. 281 tests passing. Zero analyzer issues. ✅

### 1.3 JSON Interop
- [x] Import from `.excalidraw` JSON format
- [x] Export to `.excalidraw` JSON format
- [x] Mapping between Excalidraw element types and markdraw types
- [x] **Tests**: Round-trip tests for all 7 element types, property conversion tests, edge cases

> **TDD checkpoint**: Excalidraw JSON import/export complete with round-trip fidelity. 74 codec tests passing. Zero analyzer issues. ✅

### 1.4 File I/O
- [x] Platform-agnostic file read/write abstraction (Interface Segregation)
- [x] Desktop: native file picker & save dialog (via file_picker package)
- [x] Web: download blob / upload file input (blob download for save, file_picker for open)
- [x] Mobile: file picker integration for iOS/Android (FileType.any for custom UTI compatibility)
- [x] **Tests**: Mock file system, verify read/write round-trip

> **TDD checkpoint**: Can load an excalidraw file, convert to `.markdraw`, save, reload, and verify all elements match. ✅

---

## Phase 2 — Rendering Engine (Weeks 6–9)

> Goal: See elements on screen with the hand-drawn aesthetic.

### 2.1 Rough Drawing Adapter
- [x] `RoughAdapter` interface — abstracts `rough_flutter` behind a clean API
- [x] `drawRectangle(Bounds, DrawStyle)` → rough rectangle
- [x] `drawEllipse(Bounds, DrawStyle)` → rough ellipse
- [x] `drawDiamond(Bounds, DrawStyle)` → rough polygon (4 midpoints)
- [x] `drawLine(List<Point>, DrawStyle)` → rough linear path
- [x] `drawArrow(List<Point>, ArrowheadStyle, DrawStyle)` → path + arrowhead
- [x] `drawFreedraw(List<Point>, List<double> pressures, DrawStyle)` → smooth path
- [x] `DrawStyle` value object mapping element properties → rough DrawConfig + FillerConfig
- [x] Seed-based deterministic rendering (same seed = same wobble)
- [x] **Tests**: Golden image tests comparing rendered output against reference PNGs (10 golden tests)

> **TDD checkpoint**: RoughCanvasAdapter draws all 7 element types via rough_flutter. Dashed/dotted strokes, all 4 arrowhead types, and Bezier freedraw interpolation. ~86 new tests. Zero analyzer issues. ✅

### 2.2 Static Canvas Painter
- [x] `StaticCanvasPainter extends CustomPainter`
- [x] Iterates visible elements, delegates to `RoughAdapter`
- [x] Viewport transform (pan + zoom applied to canvas matrix)
- [x] Element ordering by fractional index
- [x] Skip `isDeleted` elements
- [x] Text rendering with Flutter `TextPainter`
- [x] **Tests**: Widget tests verifying paint calls, golden tests for element combinations

> **TDD checkpoint**: StaticCanvasPainter renders all 7 element types with viewport pan/zoom. ViewportState, TextRenderer, ElementRenderer dispatch. ~44 new tests. Zero analyzer issues. ✅

### 2.3 Interactive Canvas Painter
- [x] `InteractiveCanvasPainter extends CustomPainter`
- [x] Selection rectangle (dashed blue outline)
- [x] Resize handles (corner + edge)
- [x] Rotation handle
- [x] Hover highlight
- [x] Snap lines (alignment guides)
- [x] Multi-point creation preview (line/arrow in progress)
- [x] **Tests**: Verify handle positions, snap line calculations
- [x] Point handles for line/arrow vertex editing
- [x] ArrowElement.copyWithLine preserves arrow type

> **TDD checkpoint**: InteractiveCanvasPainter renders selection boxes, handles (resize + rotation + point), hover highlights, marquee, snap lines, creation previews. Handles follow rotation. Interactive example with move, resize, rotate, point drag. ~50 new tests, 557 total. Zero analyzer issues. ✅

### 2.4 Viewport Management
- [x] `ViewportState` functional methods — `screenToScene`, `sceneToScreen`, `pan`, `zoomAt`, `fitToBounds`
- [x] Pan via drag gesture using `ViewportState.pan()`
- [x] Zoom via scroll / toolbar using `ViewportState.zoomAt()` with anchor point
- [x] Fit-to-content via `ViewportState.fitToBounds()` + `Scene.sceneBounds()`
- [x] Viewport culling: `cullElements()` filters off-screen elements before painting
- [x] Scene-to-screen and screen-to-scene coordinate transforms on `ViewportState`
- [x] **Tests**: Coordinate transforms at various zoom levels, culling correctness

> **TDD checkpoint**: ViewportState has coordinate transforms, pan, zoomAt, fitToBounds. Scene.sceneBounds() computes union of active element bounds. cullElements() filters by viewport visibility with margin. StaticCanvasPainter uses culling. Examples use the new API. ~47 new tests, 604 total. Zero analyzer issues. ✅

---

## Phase 3 — Interaction & Editing (Weeks 10–14)

> Goal: Full drawing and editing interaction — the 80% core experience.

### 3.1 Tool System
- [x] `Tool` abstract class — `onPointerDown`, `onPointerMove`, `onPointerUp`, `onKeyEvent`
- [x] `ToolResult` sealed class — mutation descriptions decoupled from state (AddElement, UpdateElement, RemoveElement, SetSelection, UpdateViewport, Compound, SwitchTool)
- [x] `EditorState` immutable value object — applies `ToolResult` to produce new state
- [x] `ToolContext` read-only snapshot + `ToolOverlay` transient UI data
- [x] `SelectTool` — click to select, drag to move, shift+click multi-select, marquee selection
- [x] `RectangleTool` — drag to create rectangle
- [x] `EllipseTool` — drag to create ellipse
- [x] `DiamondTool` — drag to create diamond
- [x] `LineTool` — click-to-add-point, double-click or Enter to finalize
- [x] `ArrowTool` — like LineTool but creates ArrowElement with endArrowhead
- [x] `FreedrawTool` — continuous path recording with simulatePressure
- [x] `TextTool` — click to place text element
- [x] `HandTool` (pan) — drag to scroll viewport via screen-space delta
- [x] `createTool` factory function for ToolType → Tool mapping
- [x] Tool switching via toolbar and keyboard shortcuts (R, E, D, L, A, P, T, H) *(implemented in 3.5)*
- [x] **Tests**: Each tool produces correct element type with expected properties from simulated gestures

> **TDD checkpoint**: Tool abstract class with 9 implementations. EditorState applies ToolResult mutations. Each tool produces correct element type from simulated pointer events. ~114 new tests, 718 total. Zero analyzer issues. ✅

### 3.2 Selection & Transform
- [x] Handle hit-testing with inverse rotation for rotated elements
- [x] Single-element resize via 8 directional handles with minimum 10×10 constraint
- [x] Shift+resize for aspect ratio lock
- [x] Single-element rotation with Shift for 15° snap increments
- [x] Line/arrow point dragging with bounding box recalculation
- [x] Multi-element move — same delta applied to all selected
- [x] Multi-element resize — proportional scaling from union bounds
- [x] Multi-element rotate — each element rotates around union center
- [x] Delete/Backspace — removes all selected elements
- [x] Ctrl+D duplicate — copies with new IDs at +10,+10 offset
- [x] Ctrl+A select all active elements
- [x] Arrow key nudge — ±1px (±10px with Shift)
- [x] Ctrl+C copy / Ctrl+V paste / Ctrl+X cut via in-memory clipboard
- [x] Clipboard stored in EditorState, survives tool switches
- [x] **Tests**: Handle hit-testing, resize all 8 directions, rotation, point drag, multi-element transforms, all keyboard shortcuts, clipboard round-trip

> **TDD checkpoint**: SelectTool handles resize (8 directions), rotation, point drag, multi-element transforms. Delete, duplicate, copy/paste/cut, select-all, nudge all work via keyboard. Clipboard stored in EditorState. ~84 new tests, ~802 total. Zero analyzer issues. ✅

### 3.3 Arrow Binding
- [x] Binding detection — when arrow endpoint is near a bindable element, snap to it
- [x] `PointBinding` — stores element ID + normalized position (0–1, 0–1) as fixedPoint
- [x] `BindingUtils` — stateless utility class with `isBindable`, `findBindTarget`, `computeFixedPoint`, `resolveBindingPoint`, `updateBoundArrowEndpoints`, `findBoundArrows`
- [x] ArrowTool snaps endpoints to nearby shapes on creation, stores PointBindings
- [x] Bound arrow updates when target element moves/resizes/rotates/nudges
- [x] Unbind on drag away from element; rebind on drag to new element
- [x] Visual indicator during binding (green highlight around target element)
- [x] Delete bound target clears bindings on affected arrows
- [x] Arrows in selection set excluded from binding updates (no double-move)
- [x] **Tests**: 68 new tests — binding utils, arrow creation, move/resize updates, point drag rebind/unbind, edge cases, integration round-trip

> **TDD checkpoint**: Arrow binding complete with BindingUtils, ArrowTool creation binding, SelectTool move/resize/delete binding updates, point drag rebind/unbind, visual indicator. 870 tests total. Zero analyzer issues. ✅

### 3.4 Undo/Redo
- [x] `HistoryManager` — stores Scene snapshots with configurable maxDepth (100)
- [x] Ctrl/Cmd+Z undo, Ctrl/Cmd+Shift+Z redo
- [x] Coalesce rapid changes (drag events → single undo step via scene-before-drag capture)
- [x] `isSceneChangingResult` classifier — determines which ToolResults affect the scene
- [x] Keyboard scene-changing shortcuts (delete, duplicate, paste, nudge) each push history
- [x] Text commit/cancel push history
- [x] **Tests**: 43 new tests — HistoryManager unit tests, classifier tests, integration tests

> **TDD checkpoint**: HistoryManager with undo/redo stacks, drag coalescing, keyboard shortcut history. isSceneChangingResult classifier. 913 tests total. Zero analyzer issues. ✅

### 3.5 Keyboard Shortcuts
- [x] Tool shortcuts (V=select, R=rectangle, E=ellipse, D=diamond, L=line, A=arrow, P=freedraw, T=text, H=hand)
- [x] Escape to deselect / cancel current tool *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] Ctrl/Cmd+A select all *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] Ctrl/Cmd+S save, Ctrl/Cmd+Shift+S save-as, Ctrl/Cmd+O open
- [x] Ctrl/Cmd+Z / Ctrl/Cmd+Shift+Z undo/redo *(done in 3.4 — widget _handleKeyEvent)*
- [x] Delete/Backspace to remove *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] Arrow keys to nudge selection (1px, 10px with Shift) *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] Ctrl+C copy / Ctrl+V paste / Ctrl+X cut *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] Ctrl+D duplicate *(done in 3.2 — SelectTool.onKeyEvent)*
- [x] **Tests**: Key event → expected action dispatched *(covered in 3.2 + 3.4 + 3.5 tests)*

> **TDD checkpoint**: Single-key tool switching via toolTypeForKey() mapping function. Only fires without modifier keys (no conflict with Ctrl+D, Ctrl+A). Ctrl+S/Shift+S/O file operations via file_picker + DocumentService + SceneDocumentConverter. 12 new tests. Zero analyzer issues. ✅

### 3.6 Property Panel
- [x] Stroke color picker (6 swatches)
- [x] Background color picker (6 swatches + transparent)
- [x] Stroke width (thin=1, medium=2, bold=4, extra-bold=6)
- [x] Stroke style (solid, dashed, dotted)
- [x] Fill style (solid, hachure, cross-hatch, zigzag)
- [x] Roughness slider (0–3, step 0.5)
- [x] Opacity slider (0–100%)
- [x] Font size (S=16, M=20, L=28, XL=36), family (Virgil, Helvetica, Cascadia), alignment (left, center, right) — shown for text elements
- [x] Roundness toggle (for rectangles/diamonds)
- [x] PropertyPanelState — pure-logic class: fromElements() extracts common style, applyStyle() produces UpdateElementResult/CompoundResult
- [x] ElementStyle — value class with nullable fields (null = mixed values)
- [x] **Tests**: 22 tests — style extraction, mixed values, application to single/multiple/text elements

> **TDD checkpoint**: PropertyPanelState with ElementStyle extraction and application. Property panel widget in example app with all controls. Changes push undo history. 947 tests total. Zero analyzer issues. ✅

> **Phase 3 complete**: Can create all basic shapes, connect them with arrows, type text, undo/redo, switch tools via keyboard, and edit element styles via property panel. This is the **80% milestone**.

---

## Phase 4 — Text Editing & Bound Text (Weeks 15–17)

> Goal: Rich inline text editing and text-inside-shapes (the most complex UI feature).

### 4.1 Inline Text Editor
- [x] Double-click text element → overlay `TextField` at element position
- [x] Match font size, family, color, alignment to element
- [x] Auto-resize element width as user types (using `TextRenderer.measure`)
- [x] Commit on blur or Enter; cancel restores original text or removes new element
- [x] **Tests**: Edit text, verify element `text` property updates

### 4.2 Bound Text (Text-in-Shapes)
- [x] Double-click rectangle/ellipse/diamond → create bound text child
- [x] Text `containerId` references parent shape
- [x] Text auto-wraps within parent bounds (90% width)
- [x] Text centered vertically and horizontally
- [x] Text inherits rotation from parent
- [x] Deleting parent deletes bound text; deleting text doesn't delete parent
- [x] Moving/resizing parent syncs bound text position
- [x] Duplicating parent also duplicates bound text with new IDs
- [x] Marquee/select-all excludes bound text elements
- [x] **Tests**: Create bound text, resize parent, verify text follows

### 4.3 Arrow Labels
- [x] Double-click arrow midpoint → create bound text
- [x] Label positioned at midpoint of arrow path (computed by ArrowLabelUtils)
- [x] Label rendered at midpoint by StaticCanvasPainter
- [x] Deleting arrow deletes label; duplicating arrow duplicates label
- [x] **Tests**: Create arrow label, move arrow endpoints, verify label repositions

> **TDD checkpoint**: TextRenderer.measure() for auto-sizing. Scene.findBoundText() and fixed getElementAtPoint() to skip bound text. BoundTextUtils for position sync. ArrowLabelUtils for midpoint computation. StaticCanvasPainter renders bound text inside shapes and arrow labels. SelectTool cascading delete/duplicate/move/resize for bound text. Double-click editing in example app. SceneDocumentConverter for Scene↔Document round-trip. Golden image tests (10). CI with coverage. File open/save via file_picker. ~68 new tests, 1015 total. Zero analyzer issues. ✅

---

## Phase 5 — Export & Import (Weeks 18–20)

> Goal: Get drawings out of the app in useful formats.

### 5.1 PNG Export
- [x] Render scene to offscreen canvas → PNG bytes (`PngExporter`)
- [x] Configurable scale factor (1x, 2x, 3x)
- [x] Optional background color or transparent
- [ ] Embed `.markdraw` data in PNG metadata (like Excalidraw's tEXt chunk) — *deferred: requires raw PNG byte manipulation*
- [x] Export selection only or full scene
- [x] **Tests**: Export → verify PNG bytes, scale, background, selection

### 5.2 SVG Export
- [x] Render scene to SVG string (`SvgExporter`)
- [x] Rough.js style paths as SVG `<path>` elements (`SvgPathConverter` + `SvgElementRenderer`)
- [x] Embed `.markdraw` data in SVG comment (base64 encoded)
- [x] **Tests**: Valid SVG output, round-trip via embedded data

### 5.3 Clipboard
- [x] Copy selected elements as `.markdraw` text to clipboard (`ClipboardCodec` + `ClipboardService`)
- [x] Paste `.markdraw` text from clipboard → add elements to scene
- [ ] Also copy as PNG for pasting into other apps — *deferred: platform-dependent native code*
- [x] **Tests**: Copy → paste → verify elements round-trip, mock service tests

### 5.4 Excalidraw Interop
- [x] Import `.excalidraw` JSON files *(done in Phase 1.3)*
- [x] Export to `.excalidraw` JSON (lossy for prose sections) *(done in Phase 1.3)*
- [ ] Drag-and-drop file support — *deferred: DropRegion API is brittle across platforms*
- [x] **Tests**: Round-trip with sample Excalidraw files (all 7 types, bindings, styles, 50+ elements)

> **TDD checkpoint**: ExportBounds utility, PngExporter (PictureRecorder → PNG bytes), SvgPathConverter (rough OpSets → SVG path data), SvgElementRenderer (element → SVG markup), SvgExporter (full SVG with embedded markdraw), ClipboardCodec (serialize/parse for clipboard), ClipboardService abstraction, Excalidraw round-trip tests. Example app with export buttons and system clipboard. ~97 new tests, 1112 total. Zero analyzer issues. ✅

---

## Phase 6 — Advanced Features (Weeks 21–26)

> Goal: The remaining 20% — frames, images, grouping, advanced arrows.

### 6.1 Grouping
- [x] Select multiple elements → Ctrl/Cmd+G to group
- [x] Groups behave as single selectable unit (click selects group, click again drills to individual)
- [x] Ctrl/Cmd+Shift+G to ungroup (removes outermost groupId)
- [x] Nested groups (groupIds list: innermost-first, outermost-last)
- [x] `.markdraw` syntax: `group=id1,id2` inline property on element lines
- [x] Marquee selection expands to include all group members
- [x] Dragging unselected grouped element moves entire group
- [x] Duplicate/paste remap groupIds for independence
- [x] Shift+click toggles entire group in/out of selection
- [x] `GroupUtils` stateless utility class (follows `BindingUtils` pattern)
- [x] **Tests**: 73 new tests — GroupUtils (25), SelectTool grouping (34), serialization round-trip (14)

> **TDD checkpoint**: GroupUtils with outermost/innermost, findGroupMembers, expandToGroup, groupElements, ungroupElements, resolveGroupForClick. SelectTool group-aware click/marquee/move/keyboard. Serializer/parser for group= property. ~73 new tests, ~1185 total. Zero analyzer issues. ✅

### 6.2 Frames
- [x] `FrameElement` — named container with `label` field, clean (non-rough) rendering
- [x] `FrameUtils` — stateless utility for containment logic (follows `BindingUtils`/`GroupUtils` pattern)
- [x] Frame rendering with child clipping (Canvas.save/clipRect/restore)
- [x] SVG export with `<clipPath>` for frame children
- [x] `FrameTool` — drag to create frame, F keyboard shortcut, default label "Frame N"
- [x] Auto-assign `frameId` when element moved fully inside a frame
- [x] Clear `frameId` when element moved outside frame boundary
- [x] Moving/nudging frame also moves its children
- [x] Deleting frame releases children (clears `frameId`)
- [x] Duplicate/paste remap `frameId` for independent copies
- [x] Frame label rendered above top edge
- [x] `.markdraw` syntax: `frame "Section A" id=sec at X,Y size WxH` with `frame=sec` property on children
- [x] Excalidraw JSON codec support for frame type
- [x] **Tests**: ~75 new tests — FrameElement (7), FrameUtils (21), serialization (18), rendering (6), FrameTool (13), SelectTool frame-aware (10)

> **TDD checkpoint**: FrameElement with label, FrameUtils containment logic, .markdraw and Excalidraw serialization, frame rendering with clipping, FrameTool with F shortcut, SelectTool frame-aware move/delete/duplicate/paste. ~75 new tests, ~1260 total. Zero analyzer issues. ✅

### 6.3 Image Elements
- [x] `ImageElement` — element subclass with `fileId`, `mimeType`, `crop` (ImageCrop?), `imageScale`
- [x] `ImageFile` — binary image data container, `ImageCrop` — normalized crop rectangle (0-1 range)
- [x] Scene `files` map (`Map<String, ImageFile>`) with `addFile`/`removeFile`
- [x] `.markdraw` serialization: `image id=X at X,Y size WxH file=X crop=X,Y,W,H scale=X` + ` ```files ` block with base64 data
- [x] Excalidraw JSON codec: `fileId`, `scale`, `crop` on elements; `files` map with data URLs
- [x] `ImageElementCache` — LRU cache (max 50) decoding `ImageFile` bytes → `dart:ui Image`
- [x] `ElementRenderer` image rendering with crop support and placeholder
- [x] SVG export: `<image>` tag with embedded data URI
- [x] `AddFileResult` / `RemoveFileResult` — sealed class members for file store mutations
- [x] Image import via file picker (aspect-ratio preserving, centered at viewport)
- [x] Aspect-ratio resize: images default locked, Shift unlocks (inverted from normal shapes)
- [x] File cleanup on delete: `RemoveFileResult` when no other elements reference the `fileId`
- [x] Duplicate image reuses same `fileId` (shared file data)
- [x] **Tests**: ~65 new tests — ImageElement/Crop/File (19), serialization (12), Excalidraw (8), rendering (7), import (10), SelectTool (7)

> **TDD checkpoint**: ImageElement with file store, full serialization round-trip (.markdraw + Excalidraw JSON), rendering with cache and SVG export, import via file picker, aspect-ratio-locked resize, file cleanup on delete. ~1325 tests total. Zero analyzer issues. ✅

### 6.4 Elbow Arrows
- [x] `elbowed: bool` field on `ArrowElement` (default false, no new element type)
- [x] `ElbowRouting` stateless utility — Manhattan routing with padding, heading inference, simplification
- [x] Binding-aware re-routing — `BindingUtils.updateBoundArrowEndpoints` computes headings from fixedPoints
- [x] Clean (non-rough) rendering — crisp polyline with `lineTo` segments, arrowheads, dash/dot patterns
- [x] SVG export: clean `<path>` with L commands for elbowed arrows
- [x] `ArrowTool` elbowed creation — two-click workflow with real-time routed preview
- [x] `.markdraw` serialization: `elbowed` flag on arrow lines, parsed via `hasFlag('elbowed')`
- [x] Excalidraw JSON: `elbowed: true` field on arrow elements
- [x] Clipboard copy/paste preserves elbowed flag
- [x] SelectTool segment drag editing — horizontal segments move vertically, vertical segments move horizontally
- [x] PropertyPanelState `elbowed` toggle — regular↔elbowed conversion with re-routing/simplification
- [x] Example app: "Elbowed" switch in property panel when arrows are selected
- [x] **Tests**: ~74 new tests — ElbowRouting (18), binding re-routing (10), rendering (10), ArrowTool (10), serialization (12), SelectTool segment drag (9), property panel (8)

> **TDD checkpoint**: ElbowRouting with Manhattan routing, binding-aware re-routing, clean rendering + SVG, two-click creation, full serialization round-trip, segment drag editing, property panel toggle. ~1407 tests total. Zero analyzer issues. ✅

### 6.5 Libraries
- [x] `LibraryItem` and `LibraryDocument` immutable models
- [x] `ExcalidrawLibCodec` — parse v1+v2 `.excalidrawlib` JSON, serialize v2
- [x] `ExcalidrawJsonCodec` — expose `elementToJson`, `parseElement`, `parseFilesJson`, `filesToJson` as public helpers
- [x] `LibraryCodec` — `.markdrawlib` format with `---` item dividers, reuses `.markdraw` sketch blocks
- [x] `DocumentFormat.markdrawLibrary` / `.excalidrawLibrary` enum values
- [x] `DocumentService.loadLibrary` / `saveLibrary` methods
- [x] `LibraryUtils` stateless utility — `createFromElements` (normalize positions, collect bound text + files) and `instantiate` (fresh IDs, remap groupIds/frameIds/boundElements/containerId/bindings, center placement)
- [x] Example app: library panel with add-to-library, click-to-place, import/export, delete
- [x] **Tests**: ~61 new tests — LibraryItem model (6), ExcalidrawLibCodec (17), LibraryCodec + DocumentService (17), LibraryUtils (13), integration (8)

> **TDD checkpoint**: Full library support with immutable models, dual-format codec, create/instantiate with ID remapping, example app panel. ~1468 tests total. Zero analyzer issues.

### 6.6 Locking
- [ ] Lock element to prevent editing
- [ ] Visual indicator (lock icon)
- [ ] `.markdraw` syntax: `rect "Fixed" ... locked`
- [ ] **Tests**: Locked elements resist selection, move, delete

---

## Phase 7 — Platform Polish (Weeks 27–30)

> Goal: Production quality on all platforms.

### 7.1 Responsive Layout
- [ ] Adaptive toolbar (horizontal on desktop, bottom sheet on mobile)
- [ ] Property panel as side panel (desktop) or bottom sheet (mobile)
- [ ] Touch-optimized handles (larger touch targets on mobile)
- [ ] Keyboard shortcut hints (desktop only)

### 7.2 Performance
- [ ] Element render caching (only re-render changed elements)
- [ ] Viewport culling optimization (spatial index / R-tree)
- [ ] Lazy rough path generation (generate on first paint, cache by seed)
- [ ] Profile and optimize for 1000+ elements
- [ ] Web: CanvasKit renderer preferred over HTML renderer

### 7.3 Accessibility
- [ ] Semantic labels for all toolbar buttons
- [ ] Keyboard-only navigation through elements (Tab to cycle, Enter to edit)
- [ ] Screen reader announcements for tool changes and element creation
- [ ] High contrast mode

### 7.4 Platform Integration
- [ ] **Web**: URL sharing, PWA support, browser file API
- [ ] **Desktop**: Native menu bar, file associations (`.markdraw`), drag-and-drop
- [ ] **Mobile**: Share sheet, haptic feedback on snaps, Apple Pencil / stylus pressure
- [ ] Dark mode theming

---

## Phase 8 — Collaboration & Advanced (Weeks 31+)

> Goal: Stretch features for post-launch iteration.

### 8.1 Real-time Collaboration
- [ ] CRDT-based element sync (investigate `y-crdt` Dart port or custom)
- [ ] Presence awareness (show collaborator cursors)
- [ ] Conflict resolution for concurrent edits
- [ ] WebSocket server for session management

### 8.2 AI Integration
- [ ] Generate diagrams from text description (LLM → `.markdraw`)
- [ ] Convert freehand sketches to clean shapes (shape recognition)
- [ ] Auto-layout suggestions

### 8.3 Plugin System
- [ ] Custom element types via plugin API
- [ ] Custom tools
- [ ] Custom export formats
- [ ] Custom markdown extensions within `sketch` blocks

### 8.4 Version History
- [ ] Git-native diffing (`.markdraw` is plain text)
- [ ] In-app version timeline
- [ ] Visual diff view

---

## Testing Strategy

### Test Pyramid

| Layer | Tool | What | Target |
|---|---|---|---|
| **Unit** | `dart test` | Element models, math, parser, serializer, history | 70% of tests |
| **Widget** | `flutter_test` | Painters, tools, property panel, toolbar | 20% of tests |
| **Golden** | `flutter_test` | Rendering fidelity (hand-drawn shapes match expected PNGs) | 5% of tests |
| **Integration** | `integration_test` | Full user flows per platform (create, edit, save, load) | 5% of tests |

### TDD Workflow

For every feature:

1. **Write failing test** — describe the expected behavior
2. **Implement minimum code** — make the test pass
3. **Refactor** — apply SOLID principles, extract abstractions
4. **Golden test** (if visual) — capture approved rendering, fail on regression

### Key Test Suites (mapped to Excalidraw tests for parity)

| Excalidraw Test File | Our Equivalent | Phase |
|---|---|---|
| `dragCreate.test.tsx` | `test/editor/tools/drag_create_test.dart` | 3 |
| `multiPointCreate.test.tsx` | `test/editor/tools/multi_point_create_test.dart` | 3 |
| `binding.test.tsx` | `test/editor/bindings/arrow_binding_test.dart` | 3 |
| `restore.test.tsx` | `test/serialization/markdraw_roundtrip_test.dart` | 1 |
| `history.test.tsx` | `test/core/history/history_manager_test.dart` | 3 |

---

## SOLID Principles Application

| Principle | Application |
|---|---|
| **S — Single Responsibility** | Each tool handles one element type. Parser, serializer, and scene are separate classes. Rendering is decoupled from domain logic. |
| **O — Open/Closed** | New element types are added by extending `Element` and implementing `ElementRenderer` — no existing code changes. New tools extend `Tool`. |
| **L — Liskov Substitution** | All elements are substitutable where `Element` is expected. All tools are substitutable where `Tool` is expected. |
| **I — Interface Segregation** | `FileReader` / `FileWriter` are separate interfaces. `Renderable` is separate from `Editable`. `Serializable` is separate from `Drawable`. |
| **D — Dependency Inversion** | Core layer depends on abstractions (interfaces), not Flutter. Rendering layer depends on `Element` interfaces, not concrete types. `RoughAdapter` interface allows swapping rendering backends. |

---

## Milestones Summary

| Milestone | Phase | Deliverable | Metric |
|---|---|---|---|
| **M0: Scaffold** | 0 | CI green, core model tests pass | 50+ unit tests |
| **M1: Format** | 1 | `.markdraw` round-trip works | Parse → serialize → parse = identical |
| **M2: Render** | 2 | Visual canvas with pan/zoom | All element types render correctly |
| **M3: Edit (80%)** | 3 | Full drawing interaction | Create, select, move, resize, connect, undo |
| **M4: Text** | 4 | Inline text editing + bound text | Text in shapes, arrow labels |
| **M5: Export** | 5 | PNG, SVG, clipboard, Excalidraw interop | 1112 tests, round-trip verified |
| **M6: Advanced (100%)** | 6 | Groups, frames, images, elbow arrows | 6.1 grouping (1185), 6.2 frames (1260), 6.3 images (1325), 6.4 elbow arrows (~1407 tests) |
| **M7: Ship** | 7 | All platforms polished | App store ready |
| **M8: Grow** | 8 | Collaboration, AI, plugins | Post-launch iteration |
