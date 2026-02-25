import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('DocumentParser', () {
    test('parses empty string', () {
      final result = DocumentParser.parse('');
      expect(result.value.sections, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('parses prose-only document', () {
      const input = '# Title\n\nSome text';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(1));
      expect(result.value.sections.first, isA<ProseSection>());
      expect(
        (result.value.sections.first as ProseSection).content,
        '# Title\n\nSome text',
      );
    });

    test('parses document with frontmatter and prose', () {
      const input = '''---
markdraw: 1
grid: 20
---

# Title

Content here''';
      final result = DocumentParser.parse(input);
      expect(result.value.settings.grid, 20);
      expect(result.value.sections, hasLength(1));
      expect(result.value.sections.first, isA<ProseSection>());
    });

    test('parses document with single sketch block', () {
      const input = '''```sketch
rect id=auth at 100,200 size 160x80 seed=42
ellipse id=db at 225,400 size 120x80 seed=7
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(1));
      expect(result.value.sections.first, isA<SketchSection>());
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<RectangleElement>());
      expect(sketch.elements[1], isA<EllipseElement>());
    });

    test('parses interleaved prose and sketch', () {
      const input = '''# Architecture

Here's how the services connect:

```sketch
rect id=auth at 100,200 size 160x80 seed=42
```

The auth service handles OAuth2 flows.

```sketch
ellipse id=db at 225,400 size 120x80 seed=7
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(4));
      expect(result.value.sections[0], isA<ProseSection>());
      expect(result.value.sections[1], isA<SketchSection>());
      expect(result.value.sections[2], isA<ProseSection>());
      expect(result.value.sections[3], isA<SketchSection>());
    });

    test('registers aliases from sketch elements', () {
      const input = '''```sketch
rect id=auth at 100,200 size 160x80 seed=42
rect id=gateway at 350,200 size 160x80 seed=43
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.aliases, containsPair('auth', isNotNull));
      expect(result.value.aliases, containsPair('gateway', isNotNull));
    });

    test('resolves arrow bindings', () {
      const input = '''```sketch
rect id=auth at 100,200 size 160x80 seed=42
rect id=gateway at 350,200 size 160x80 seed=43
arrow from auth to gateway seed=20
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final arrow = sketch.elements[2] as ArrowElement;
      expect(arrow.startBinding, isNotNull);
      expect(arrow.endBinding, isNotNull);
    });

    test('parses rect with inline label into shape + bound text', () {
      const input = '''```sketch
rect "Auth Service" id=auth at 100,200 size 160x80 seed=42
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      // Should produce both a rect and a bound text element
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<RectangleElement>());
      expect(sketch.elements[1], isA<TextElement>());
      final text = sketch.elements[1] as TextElement;
      expect(text.text, 'Auth Service');
      expect(text.containerId, isNotNull);
    });

    test('frontmatter settings preserved', () {
      const input = '''---
markdraw: 1
background: "#000000"
grid: 10
---

```sketch
rect at 0,0 size 100x100 seed=1
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.settings.background, '#000000');
      expect(result.value.settings.grid, 10);
    });

    test('unknown keywords in sketch produce warnings', () {
      const input = '''```sketch
polygon at 0,0 size 100x100
rect at 0,0 size 100x100 seed=1
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('Unknown keyword'));
      // Valid rect still parsed
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
    });

    test('empty sketch block produces empty section', () {
      const input = '''```sketch
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, isEmpty);
    });

    test('sketch with comments skips comment lines', () {
      const input = '''```sketch
# This is a comment
rect at 0,0 size 100x100 seed=1
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
    });

    test('allElements returns elements from all sections', () {
      const input = '''```sketch
rect id=a at 0,0 size 100x100 seed=1
```

Some prose

```sketch
ellipse id=b at 200,200 size 50x50 seed=2
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.allElements, hasLength(2));
    });

    test('full example document', () {
      const input = '''---
markdraw: 1
background: "#ffffff"
grid: 20
---

# Architecture Overview

Here's how the services connect:

```sketch
rect "Auth Service" id=auth at 100,200 size 160x80 fill=#e3f2fd rounded=8 seed=42
rect "API Gateway" id=gateway at 350,200 size 160x80 fill=#fff3e0 rounded=8 seed=43
arrow from auth to gateway stroke=dashed seed=20
ellipse "Database" id=db at 225,400 size 120x80 fill=#e8f5e9 seed=7
```

The auth service handles OAuth2 flows.''';
      final result = DocumentParser.parse(input);
      expect(result.value.settings.grid, 20);
      expect(result.value.sections, hasLength(3));
      expect(result.value.sections[0], isA<ProseSection>());
      expect(result.value.sections[1], isA<SketchSection>());
      expect(result.value.sections[2], isA<ProseSection>());

      final sketch = result.value.sections[1] as SketchSection;
      // rect + text + rect + text + arrow + ellipse + text = 7
      expect(sketch.elements.length, greaterThanOrEqualTo(4));

      expect(result.value.aliases, containsPair('auth', isNotNull));
      expect(result.value.aliases, containsPair('gateway', isNotNull));
      expect(result.value.aliases, containsPair('db', isNotNull));
    });
  });
}
