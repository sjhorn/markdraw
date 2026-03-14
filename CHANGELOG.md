## 0.1.0

First published release. Full-featured Excalidraw-inspired drawing widget for Flutter.

### Core
* Immutable element model with 10 element types: rectangle, ellipse, diamond, line, arrow, freedraw, text, image, frame, elbow arrow
* Scene graph with fractional index ordering and soft deletion
* Undo/redo with drag coalescing (HistoryManager, 100-step depth)

### Serialization
* Human-readable `.markdraw` format with YAML frontmatter and `sketch` blocks
* Excalidraw JSON import/export (`.excalidraw`)
* Library format support (`.markdrawlib` and `.excalidrawlib`)
* SVG export with embedded `.markdraw` data for round-trip
* PNG export with configurable scale and background
* Document name via `@name` directive

### Rendering
* Hand-drawn aesthetic via `rough_flutter` adapter
* Dual-canvas architecture: static (element rendering) + interactive (selection, handles, snap lines)
* Viewport pan/zoom with culling
* Google Fonts integration with bundled Excalifont
* Font resolver with bundled, Google Fonts, and system fallback strategies
* Image element rendering with LRU cache and crop support
* Frame clipping (Canvas clipRect + SVG clipPath)
* Clean (non-rough) rendering for elbow arrows and frames

### Tools & Interaction
* 12 tools: select, rectangle, ellipse, diamond, line, arrow, freedraw, text, hand, frame, laser, eraser
* Arrow binding with snap-to-shape and visual indicator
* Elbow arrow routing (Manhattan algorithm with heading inference)
* Multi-element select, move, resize (proportional), rotate
* Aspect-ratio-locked resize for images (Shift to unlock)
* Point and segment drag editing for lines/arrows
* Copy/paste/cut/duplicate with system clipboard sync
* Nudge (arrow keys, Shift for 10px)
* Flip horizontal/vertical (Shift+H/V)
* Shape cycling (Tab/Shift+Tab: rectangle, diamond, ellipse)
* Copy/paste styles (Ctrl+Alt+C/V)
* Paste as plaintext text element (Ctrl+Shift+V)
* Flowchart creation (Ctrl+Arrow) and navigation (Alt+Arrow)
* Snap to objects (Alt+S) with visual guide lines
* Find on canvas (Ctrl/Cmd+F) with smart zoom
* Link system with inline overlay and URL launching

### Element Features
* Element grouping (Ctrl+G) with nested groups and drill-down click
* Frames with auto-assign, child clipping, label editing, opacity cascading
* Image elements with file store, crop, and aspect-ratio resize
* Element locking (Ctrl+Shift+L) with gray dashed indicator
* Bound text in shapes and arrow labels
* Inline text editing with auto-resize

### UI & Widget
* `MarkdrawEditor` — single configurable widget with toolbar, panels, and zoom controls
* `MarkdrawController` — ChangeNotifier for programmatic control
* `MarkdrawEditorConfig` — immutable configuration
* `MarkdrawFileHandler` — wires file_picker for save/open/export
* `MarkdrawApp` — MaterialApp wrapper managing ThemeMode
* Responsive layout: desktop (floating toolbar, side panels) + compact (bottom bar, sheets) at 600px breakpoint
* Touch-aware interaction mode with scaled handles and hit radii
* Dark mode theming
* Zen mode (Alt+Z) and view mode (Alt+R)
* Color picker shortcuts (S/G/Shift+F) with inline eyedropper
* Laser pointer (K) with fading trail
* Copy as PNG to clipboard (Shift+Alt+C)
* Live markdown split-pane editor with bidirectional sync
* Library panel with drag-and-drop, import/export
* Property panel with full style editing
* 70+ keyboard shortcuts

### Testing
* 2,247 tests (unit, widget, golden)
* Zero analyzer issues

## 0.0.2

* Added live markdown split-pane editor with bidirectional canvas/text sync
* New `MarkdrawSplitPane` widget and `showMarkdownButton` config option
* Markdown toggle button in desktop toolbar (Material Symbols `markdown` icon)
* Added `material_symbols_icons` dependency

## 0.0.1

* Project scaffold with Flutter package structure
* README with project description and `.markdraw` format example
* CLAUDE.md with development principles and TDD workflow
* ROADMAP.md with full phased development plan
