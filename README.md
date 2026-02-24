# markdraw

An Excalidraw-inspired drawing widget for Flutter with a human-readable markdown serialization format.

Cross-platform: iOS, Android, Web, macOS, Windows, Linux.

## The `.markdraw` Format

Drawings are saved as markdown files with embedded sketch blocks — human-readable, git-friendly, and diffable:

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

The auth service handles OAuth2 flows.
````

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  markdraw: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Platform Notes

The `ios/`, `android/`, `macos/`, `windows/`, and `linux/` directories are gitignored. After cloning, run `flutter create .` to regenerate them, then apply these manual changes:

- **iOS**: Add `<key>UISupportsDocumentBrowser</key><true/>` to `ios/Runner/Info.plist` — required for file picker save dialogs to work correctly.

## Development

```bash
# Run all tests
flutter test

# Run tests and check output
flutter test 2>&1 > /tmp/test.txt

# Static analysis
flutter analyze

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development plan.

- **Phase 0** — Foundation: core math types, element model, scene graph
- **Phase 1** — Markdown serialization: `.markdraw` parser and serializer
- **Phase 2** — Rendering: hand-drawn aesthetic via `rough_flutter`
- **Phase 3** — Interaction: tools, selection, undo/redo
- **Phase 4** — Text editing and bound text
- **Phase 5** — Export (PNG, SVG, clipboard, Excalidraw interop)
- **Phase 6** — Advanced features (groups, frames, images)
- **Phase 7** — Platform polish
- **Phase 8** — Collaboration and plugins

## License

MIT — see [LICENSE](LICENSE).
