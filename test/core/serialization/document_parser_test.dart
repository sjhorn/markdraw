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

    test('parses document with single markdraw block', () {
      const input = '''```markdraw
rect id=auth at 100,200 size 160x80
ellipse id=db at 225,400 size 120x80
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(1));
      expect(result.value.sections.first, isA<SketchSection>());
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<RectangleElement>());
      expect(sketch.elements[1], isA<EllipseElement>());
    });

    test('parses legacy ```sketch fence for backward compatibility', () {
      const input = '''```sketch
rect id=r at 10,20 50x60
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(1));
      expect(result.value.sections.first, isA<SketchSection>());
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
      expect(sketch.elements[0], isA<RectangleElement>());
    });

    test('parses interleaved prose and sketch', () {
      const input = '''# Architecture

Here's how the services connect:

```markdraw
rect id=auth at 100,200 size 160x80
```

The auth service handles OAuth2 flows.

```markdraw
ellipse id=db at 225,400 size 120x80
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.sections, hasLength(4));
      expect(result.value.sections[0], isA<ProseSection>());
      expect(result.value.sections[1], isA<SketchSection>());
      expect(result.value.sections[2], isA<ProseSection>());
      expect(result.value.sections[3], isA<SketchSection>());
    });

    test('registers aliases from sketch elements', () {
      const input = '''```markdraw
rect id=auth at 100,200 size 160x80
rect id=gateway at 350,200 size 160x80
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.aliases, containsPair('auth', isNotNull));
      expect(result.value.aliases, containsPair('gateway', isNotNull));
    });

    test('resolves arrow bindings', () {
      const input = '''```markdraw
rect id=auth at 100,200 size 160x80
rect id=gateway at 350,200 size 160x80
arrow from auth to gateway
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final arrow = sketch.elements[2] as ArrowElement;
      expect(arrow.startBinding, isNotNull);
      expect(arrow.endBinding, isNotNull);
    });

    test('parses rect with inline label into shape + bound text', () {
      const input = '''```markdraw
rect "Auth Service" id=auth at 100,200 size 160x80
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

```markdraw
rect at 0,0 size 100x100
```''';
      final result = DocumentParser.parse(input);
      expect(result.value.settings.background, '#000000');
      expect(result.value.settings.grid, 10);
    });

    test('unknown keywords in sketch produce warnings', () {
      const input = '''```markdraw
polygon at 0,0 size 100x100
rect at 0,0 size 100x100
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('Unknown keyword'));
      // Valid rect still parsed
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
    });

    test('empty sketch block produces empty section', () {
      const input = '''```markdraw
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, isEmpty);
    });

    test('sketch with comments skips comment lines', () {
      const input = '''```markdraw
# This is a comment
rect at 0,0 size 100x100
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
    });

    test('allElements returns elements from all sections', () {
      const input = '''```markdraw
rect id=a at 0,0 size 100x100
```

Some prose

```markdraw
ellipse id=b at 200,200 size 50x50
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

```markdraw
rect "Auth Service" id=auth at 100,200 size 160x80 fill=#e3f2fd rounded=8
rect "API Gateway" id=gateway at 350,200 size 160x80 fill=#fff3e0 rounded=8
arrow from auth to gateway stroke=dashed
ellipse "Database" id=db at 225,400 size 120x80 fill=#e8f5e9
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

  group('Bound text color', () {
    test('parses text-color on shape with label', () {
      const input = '''```markdraw
rect "Label" id=r at 0,0 100x50 text-color=red
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.strokeColor, '#ff0000');
    });

    test('defaults to black when text-color omitted', () {
      const input = '''```markdraw
rect "Label" id=r at 0,0 100x50
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.strokeColor, '#000000');
    });
  });

  group('Bound text with id before label', () {
    test('rect id=rect1 "test" parses shape + bound text', () {
      const input = '''```markdraw
rect id=rect1 "test" at 100,100 size 100x100
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<RectangleElement>());
      final rect = sketch.elements[0] as RectangleElement;
      expect(rect.x, 100);
      expect(rect.y, 100);
      expect(sketch.elements[1], isA<TextElement>());
      final text = sketch.elements[1] as TextElement;
      expect(text.text, 'test');
      expect(text.containerId, rect.id.value);
    });

    test('ellipse id=ellipse1 "label" parses shape + bound text', () {
      const input = '''```markdraw
ellipse id=ellipse1 "label" at 50,50 size 80x60
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<EllipseElement>());
      final text = sketch.elements[1] as TextElement;
      expect(text.text, 'label');
      expect(text.containerId, isNotNull);
    });

    test('diamond id=diamond1 "label" parses shape + bound text', () {
      const input = '''```markdraw
diamond id=diamond1 "label" at 50,50 size 80x60
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0], isA<DiamondElement>());
      final text = sketch.elements[1] as TextElement;
      expect(text.text, 'label');
      expect(text.containerId, isNotNull);
    });

    test('arrow id=arrow1 "label" with from/to parses arrow + bound text', () {
      const input = '''```markdraw
rect id=a at 0,0 size 50x50
rect id=b at 200,200 size 50x50
arrow id=arrow1 "calls" from a to b
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.text, 'calls');
      expect(texts.first.containerId, isNotNull);
    });

    test('shape with id before label preserves text properties', () {
      const input = '''```markdraw
rect id=rect1 "styled" at 0,0 size 100x50 text-size=24 text-color=blue
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final text = sketch.elements[1] as TextElement;
      expect(text.text, 'styled');
      expect(text.fontSize, 24);
      expect(text.strokeColor, '#0000ff');
    });

    test('bound text with quoted font name', () {
      const input = '''```markdraw
rect "Label" at 0,0 100x50 text-font="Lilita One"
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final text = sketch.elements[1] as TextElement;
      expect(text.fontFamily, 'Lilita One');
    });

    test('bound text with font alias hand-drawn', () {
      const input = '''```markdraw
rect "Label" at 0,0 100x50 text-font=hand-drawn
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final text = sketch.elements[1] as TextElement;
      expect(text.fontFamily, 'Excalifont');
    });

    test('bound text with named font size', () {
      const input = '''```markdraw
rect "Label" at 0,0 100x50 text-size=large
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final text = sketch.elements[1] as TextElement;
      expect(text.fontSize, 28.0);
    });

    test('bound text with font-size alias', () {
      const input = '''```markdraw
rect "Label" at 0,0 100x50 font-size=small
```''';
      final result = DocumentParser.parse(input);
      final sketch = result.value.sections.first as SketchSection;
      final text = sketch.elements[1] as TextElement;
      expect(text.fontSize, 16.0);
    });
  });

  group('Arrow label parsing', () {
    test('parses arrow with inline label into arrow + bound text', () {
      const input = '''```markdraw
rect id=auth at 100,200 160x80
rect id=gw at 400,200 160x80
arrow "calls" from auth to gw
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, isEmpty);
      final sketch = result.value.sections.first as SketchSection;
      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNotNull);
      expect(arrows.first.endBinding, isNotNull);

      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.text, 'calls');
      expect(texts.first.containerId, isNotNull);
    });

    test('parses arrow with inline label and text properties', () {
      const input = '''```markdraw
rect id=auth at 100,200 160x80
rect id=gw at 400,200 160x80
arrow "API" from auth to gw text-size=16 text-color=red
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, isEmpty);
      final sketch = result.value.sections.first as SketchSection;

      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.text, 'API');
      expect(texts.first.fontSize, 16);
      expect(texts.first.strokeColor, '#ff0000');
    });
  });

  group('Partial binding parsing', () {
    test('parses arrow with coordinate endpoint', () {
      const input = '''```markdraw
rect id=auth at 100,200 160x80
arrow from auth to 500,300
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, isEmpty);
      final sketch = result.value.sections.first as SketchSection;
      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNotNull);
      expect(arrows.first.endBinding, isNull);
    });

    test('parses arrow with coordinate start', () {
      const input = '''```markdraw
rect id=dest at 400,200 160x80
arrow from 100,50 to dest
```''';
      final result = DocumentParser.parse(input);
      expect(result.warnings, isEmpty);
      final sketch = result.value.sections.first as SketchSection;
      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNull);
      expect(arrows.first.endBinding, isNotNull);
    });
  });
}
