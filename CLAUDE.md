# Markdraw Widget

## Project Overview
An Excalidraw-inspired drawing tool built in Dart/Flutter with a human-readable markdown serialization format. TDD · SOLID · Cross-platform (iOS, Android, Web, macOS, Windows, Linux)

Note roadmap in ./ROADMAP.md

Aim to build a working example in ./example of each part as we go. Its ok to use separate named.dart files as we test with the final product coming together in the main.dart

We will follow TDD Workflow per the section below and implement SOLID Principles per the section below. As we complete a TDD workflow cycle we will commit to git with a meaningful comment or when we complete a phase. We will also aim to update our ROADMAP.md as we go with the cycle.

## Development Principles

### TDD Workflow
1. **Write test first** - Define expected behavior before implementation
2. **Red → Green → Refactor** - Failing test → Pass → Optimize
3. **Test file mirrors source** - `lib/src/core/span_list.dart` → `test/core/span_list_test.dart`
4. **Minimum 80% coverage** - Critical paths require 100%

### SOLID Principles
- **S**: Each class has one responsibility (e.g., `TileCache` only manages cache, not rendering)
- **O**: Extend via interfaces, not modification (e.g., `CellRenderer` abstract class)
- **L**: Subtypes must be substitutable (e.g., `SparseWorksheetData` implements `WorksheetData`)
- **I**: Small, focused interfaces (e.g., separate `Paintable`, `HitTestable`)
- **D**: Depend on abstractions (e.g., `TileManager` takes `TileCache` interface, not concrete)

### Dart Idioms
- Prefer `final` and immutable models
- Use factory constructors for complex initialization
- Extension methods for utility functions
- `typedef` for function signatures
- Named parameters with required keyword

## Testing Strategy

### Unit Tests
- All pure functions and models
- Mock dependencies via interfaces
- Property-based tests for math operations

### Widget Tests
- `RenderObject` behavior via `TestRenderingFlutterBinding`
- Gesture simulation
- Layout verification

### Integration Tests
- Scroll + zoom combinations
- Large dataset performance
- Memory leak detection

### Performance Benchmarks
```dart
// Target metrics
const scrollFps = 60;        // Maintain 60fps while scrolling
const zoomFps = 30;          // Acceptable during zoom animation
const tileRenderMs = 8;      // Max time to render single tile
const hitTestUs = 100;       // Max hit test latency
```

## Critical Performance Rules

1. **Never allocate in paint()** - Pre-allocate paints, paths
2. **Batch draw calls** - Group gridlines into single path
3. **LOD by zoom** - Skip text below 25% zoom
4. **Tile size = 256px** - Optimal GPU texture size
5. **LRU cache tiles** - Max 100 tiles in memory
6. **Prefetch 1 ring** - Tiles beyond viewport edge

## Commands
```bash
# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html

# Run specific test file
flutter test test/core/span_list_test.dart

# Performance profiling
flutter run --profile --trace-skia
```

### Testing Tips
- **Always pipe test output to a file** and grep for errors. Flutter test output uses `\r` carriage returns that make inline grep unreliable:
  ```bash
  flutter test 2>&1 | tr '\r' '\n' | tail -5   # Check final pass/fail
  flutter test 2>&1 | tr '\r' '\n' | grep -i "fail\|error\|exception"
  ```

Prefered:
```bash
flutter test 2<&1 > /tmp/test.txt
```
and grep the /tmp/test.txt file

## Code Review Checklist
- [ ] Tests written before implementation
- [ ] All public APIs documented
- [ ] No magic numbers (use constants)
- [ ] Interfaces for external dependencies
- [ ] Immutable models where possible
- [ ] Memory disposal in `dispose()` methods
- [ ] Performance-critical code benchmarked

## Release Process

Follow these steps in order. Fix any issues before proceeding to the next step.

### 1. Static Analysis
```bash
# Run the analyzer — must have zero issues
flutter analyze

# Apply automated fixes for any issues
dart fix --apply

# Re-run analyzer to confirm clean
flutter analyze
```

### 2. Tests
```bash
# Run all tests — must all pass
flutter test
```

### 3. Coverage
```bash
# Generate coverage data
flutter test --coverage

# Generate HTML report and review
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Verify minimum 80% coverage (critical paths 100%)
```

### 4. Benchmarks
```bash
# Run performance profiling
flutter run --profile --trace-skia
```
Confirm targets: scroll 60fps, zoom 30fps, tile render <8ms, hit test <100us.

### 5. Version & Changelog
- Bump version in `pubspec.yaml` following [semver](https://semver.org/)
  - **patch** (1.0.x): bug fixes
  - **minor** (1.x.0): new features, backwards compatible
  - **major** (x.0.0): breaking API changes
- Add entry to `CHANGELOG.md` under new version heading with date
- Update any version references in `README.md` if needed

### 6. Commit & Tag
```bash
git add -A
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
git push && git push --tags
```

### 7. Publish to pub.dev
```bash
# Dry run first — fix any issues it reports
flutter pub publish --dry-run

# Publish for real
flutter pub publish
```

### Quick Reference Checklist
- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — all pass
- [ ] `flutter test --coverage` — meets 80% minimum
- [ ] Benchmarks reviewed
- [ ] `pubspec.yaml` version bumped
- [ ] `CHANGELOG.md` updated
- [ ] Committed and tagged `vX.Y.Z`
- [ ] Pushed with tags
- [ ] `flutter pub publish --dry-run` — no issues
- [ ] `flutter pub publish` — published