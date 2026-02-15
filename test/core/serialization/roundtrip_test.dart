import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/roundness.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/serialization/canvas_settings.dart';
import 'package:markdraw/src/core/serialization/document_parser.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/document_serializer.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';
import 'package:markdraw/src/core/serialization/parse_result.dart';
import 'package:markdraw/src/core/serialization/sketch_line_parser.dart';
import 'package:markdraw/src/core/serialization/sketch_line_serializer.dart';

void main() {
  group('Sketch line round-trip (serialize → parse)', () {
    late SketchLineSerializer serializer;
    late SketchLineParser parser;

    setUp(() {
      serializer = SketchLineSerializer();
      parser = SketchLineParser();
    });

    test('rectangle round-trips', () {
      final original = RectangleElement(
        id: ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'auth');
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as RectangleElement;
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.width, original.width);
      expect(parsed.height, original.height);
      expect(parsed.seed, original.seed);
    });

    test('rectangle with non-default properties round-trips', () {
      final original = RectangleElement(
        id: ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 60,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        fillStyle: FillStyle.hachure,
        strokeWidth: 3,
        strokeStyle: StrokeStyle.dotted,
        roughness: 2,
        opacity: 0.5,
        roundness: Roundness.adaptive(value: 8),
        angle: 1.5,
        locked: true,
        seed: 99,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'r');
      final result = parser.parseLine(line, 1);
      final parsed = result.value!;
      expect(parsed.strokeColor, original.strokeColor);
      expect(parsed.backgroundColor, original.backgroundColor);
      expect(parsed.fillStyle, original.fillStyle);
      expect(parsed.strokeWidth, original.strokeWidth);
      expect(parsed.strokeStyle, original.strokeStyle);
      expect(parsed.roughness, original.roughness);
      expect(parsed.opacity, original.opacity);
      expect(parsed.roundness!.value, original.roundness!.value);
      expect(parsed.angle, original.angle);
      expect(parsed.locked, original.locked);
      expect(parsed.seed, original.seed);
    });

    test('ellipse round-trips', () {
      final original = EllipseElement(
        id: ElementId('e1'),
        x: 225,
        y: 400,
        width: 120,
        height: 80,
        backgroundColor: '#e8f5e9',
        seed: 7,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'db');
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as EllipseElement;
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.backgroundColor, original.backgroundColor);
    });

    test('diamond round-trips', () {
      final original = DiamondElement(
        id: ElementId('d1'),
        x: 50,
        y: 50,
        width: 100,
        height: 100,
        seed: 3,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as DiamondElement;
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.width, original.width);
    });

    test('text round-trips', () {
      final original = TextElement(
        id: ElementId('t1'),
        x: 100,
        y: 50,
        width: 200,
        height: 30,
        text: 'High Priority',
        fontSize: 24,
        fontFamily: 'Cascadia',
        textAlign: TextAlign.center,
        strokeColor: '#d32f2f',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as TextElement;
      expect(parsed.text, original.text);
      expect(parsed.fontSize, original.fontSize);
      expect(parsed.fontFamily, original.fontFamily);
      expect(parsed.textAlign, original.textAlign);
      expect(parsed.strokeColor, original.strokeColor);
    });

    test('line round-trips', () {
      final original = LineElement(
        id: ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [Point(0, 0), Point(100, 0), Point(100, 100)],
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.triangle,
        strokeStyle: StrokeStyle.dashed,
        seed: 10,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as LineElement;
      expect(parsed.points, hasLength(3));
      expect(parsed.points[0], Point(0, 0));
      expect(parsed.points[1], Point(100, 0));
      expect(parsed.points[2], Point(100, 100));
      expect(parsed.startArrowhead, Arrowhead.dot);
      expect(parsed.endArrowhead, Arrowhead.triangle);
      expect(parsed.strokeStyle, StrokeStyle.dashed);
    });

    test('arrow without bindings round-trips', () {
      final original = ArrowElement(
        id: ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [Point(0, 0), Point(200, 0)],
        startArrowhead: Arrowhead.bar,
        endArrowhead: Arrowhead.dot,
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as ArrowElement;
      expect(parsed.points[0], Point(0, 0));
      expect(parsed.points[1], Point(200, 0));
      expect(parsed.startArrowhead, Arrowhead.bar);
      expect(parsed.endArrowhead, Arrowhead.dot);
    });

    test('freedraw round-trips', () {
      final original = FreedrawElement(
        id: ElementId('f1'),
        x: 0,
        y: 0,
        width: 10,
        height: 8,
        points: [Point(0, 0), Point(5, 2), Point(10, 8)],
        pressures: [0.5, 0.7, 0.9],
        simulatePressure: true,
        strokeColor: '#1e1e1e',
        seed: 30,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as FreedrawElement;
      expect(parsed.points, hasLength(3));
      expect(parsed.points[0], Point(0, 0));
      expect(parsed.pressures, [0.5, 0.7, 0.9]);
      expect(parsed.simulatePressure, isTrue);
      expect(parsed.strokeColor, '#1e1e1e');
    });

    test('fill-style cross-hatch round-trips', () {
      final original = RectangleElement(
        id: ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fillStyle: FillStyle.crossHatch,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      expect(result.value!.fillStyle, FillStyle.crossHatch);
    });

    test('fill-style zigzag round-trips', () {
      final original = RectangleElement(
        id: ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fillStyle: FillStyle.zigzag,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      expect(result.value!.fillStyle, FillStyle.zigzag);
    });
  });

  group('Parse → serialize string equality', () {
    test('simple sketch block', () {
      const input = '''```sketch
rect id=auth at 100,200 size 160x80 seed=42
ellipse id=db at 225,400 size 120x80 fill=#e8f5e9 seed=7
```''';
      final parseResult = DocumentParser.parse(input);
      final output = DocumentSerializer.serialize(parseResult.value);
      expect(output.trim(), input.trim());
    });

    test('sketch with non-default properties', () {
      const input = '''```sketch
rect id=r at 10,20 size 50x60 fill=#00ff00 color=#ff0000 stroke=dotted fill-style=hachure stroke-width=3 roughness=2 opacity=0.5 rounded=8 angle=1.5 locked seed=99
```''';
      final parseResult = DocumentParser.parse(input);
      final output = DocumentSerializer.serialize(parseResult.value);
      expect(output.trim(), input.trim());
    });
  });

  group('Document-level round-trips', () {
    test('frontmatter settings round-trip', () {
      final doc = MarkdrawDocument(
        settings: CanvasSettings(
          background: '#e0e0e0',
          grid: 20,
        ),
      );
      final output = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(output);
      expect(parsed.value.settings.background, '#e0e0e0');
      expect(parsed.value.settings.grid, 20);
    });

    test('prose sections round-trip', () {
      final doc = MarkdrawDocument(
        sections: [ProseSection('# Hello World\n\nSome content here.')],
      );
      final output = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(output);
      expect(parsed.value.sections, hasLength(1));
      expect(parsed.value.sections.first, isA<ProseSection>());
      final prose = parsed.value.sections.first as ProseSection;
      expect(prose.content, contains('# Hello World'));
      expect(prose.content, contains('Some content here.'));
    });

    test('interleaved prose and sketch round-trip', () {
      final rect = RectangleElement(
        id: ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [
          ProseSection('# Title'),
          SketchSection([rect]),
          ProseSection('More text'),
        ],
        aliases: {'auth': 'r1'},
      );
      final output = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(output);
      expect(parsed.value.sections, hasLength(3));
      expect(parsed.value.sections[0], isA<ProseSection>());
      expect(parsed.value.sections[1], isA<SketchSection>());
      expect(parsed.value.sections[2], isA<ProseSection>());

      final sketch = parsed.value.sections[1] as SketchSection;
      expect(sketch.elements, hasLength(1));
      expect(sketch.elements.first, isA<RectangleElement>());
      expect(sketch.elements.first.x, 100);
      expect(sketch.elements.first.y, 200);
    });

    test('arrow bindings round-trip', () {
      final rect1 = RectangleElement(
        id: ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: ElementId('r2'),
        x: 350,
        y: 200,
        width: 160,
        height: 80,
        seed: 2,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: ElementId('a1'),
        x: 260,
        y: 240,
        width: 90,
        height: 0,
        points: [Point(0, 0), Point(90, 0)],
        startBinding: PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5),
        ),
        seed: 3,
        versionNonce: 1,
        updated: 0,
      );

      final doc = MarkdrawDocument(
        sections: [SketchSection([rect1, rect2, arrow])],
        aliases: {'auth': 'r1', 'gw': 'r2'},
      );
      final output = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(output);

      final sketch = parsed.value.sections.first as SketchSection;
      // Find the arrow
      final parsedArrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(parsedArrows, hasLength(1));
      final parsedArrow = parsedArrows.first;
      expect(parsedArrow.startBinding, isNotNull);
      expect(parsedArrow.endBinding, isNotNull);
    });

    test('bound text labels round-trip', () {
      final rect = RectangleElement(
        id: ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final label = TextElement(
        id: ElementId('t1'),
        x: 110,
        y: 210,
        width: 140,
        height: 20,
        text: 'Auth Service',
        containerId: 'r1',
        seed: 43,
        versionNonce: 1,
        updated: 0,
      );

      final doc = MarkdrawDocument(
        sections: [SketchSection([rect, label])],
        aliases: {'auth': 'r1'},
      );
      final output = DocumentSerializer.serialize(doc);

      // Verify the serialized output has inline label
      expect(output, contains('rect "Auth Service" id=auth'));

      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;

      // Should have both rect and bound text
      final rects = sketch.elements.whereType<RectangleElement>().toList();
      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(rects, hasLength(1));
      expect(texts, hasLength(1));
      expect(texts.first.text, 'Auth Service');
      expect(texts.first.containerId, isNotNull);
    });

    test('every element type round-trips through document', () {
      final elements = <Element>[
        RectangleElement(
          id: ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          seed: 1,
          versionNonce: 1,
          updated: 0,
        ),
        EllipseElement(
          id: ElementId('e1'),
          x: 200,
          y: 0,
          width: 80,
          height: 80,
          seed: 2,
          versionNonce: 1,
          updated: 0,
        ),
        DiamondElement(
          id: ElementId('d1'),
          x: 400,
          y: 0,
          width: 60,
          height: 60,
          seed: 3,
          versionNonce: 1,
          updated: 0,
        ),
        TextElement(
          id: ElementId('t1'),
          x: 0,
          y: 100,
          width: 200,
          height: 30,
          text: 'Hello World',
          seed: 4,
          versionNonce: 1,
          updated: 0,
        ),
        LineElement(
          id: ElementId('l1'),
          x: 0,
          y: 200,
          width: 100,
          height: 100,
          points: [Point(0, 0), Point(100, 100)],
          seed: 5,
          versionNonce: 1,
          updated: 0,
        ),
        ArrowElement(
          id: ElementId('a1'),
          x: 0,
          y: 300,
          width: 200,
          height: 0,
          points: [Point(0, 0), Point(200, 0)],
          seed: 6,
          versionNonce: 1,
          updated: 0,
        ),
        FreedrawElement(
          id: ElementId('f1'),
          x: 0,
          y: 400,
          width: 50,
          height: 50,
          points: [Point(0, 0), Point(25, 25), Point(50, 50)],
          seed: 7,
          versionNonce: 1,
          updated: 0,
        ),
      ];

      final doc = MarkdrawDocument(
        sections: [SketchSection(elements)],
        aliases: {
          'r': 'r1',
          'e': 'e1',
          'd': 'd1',
          't': 't1',
          'l': 'l1',
          'a': 'a1',
          'f': 'f1',
        },
      );

      final output = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;

      expect(
        sketch.elements.whereType<RectangleElement>().length,
        1,
      );
      expect(
        sketch.elements.whereType<EllipseElement>().length,
        1,
      );
      expect(
        sketch.elements.whereType<DiamondElement>().length,
        1,
      );
      expect(
        sketch.elements.whereType<TextElement>().length,
        1,
      );
      expect(
        sketch.elements.whereType<LineElement>()
            .where((e) => e is! ArrowElement)
            .length,
        1,
      );
      expect(
        sketch.elements.whereType<ArrowElement>().length,
        1,
      );
      expect(
        sketch.elements.whereType<FreedrawElement>().length,
        1,
      );
    });
  });

  group('Hand-written document round-trip', () {
    test('full example document parses and re-serializes', () {
      const handWritten = '''---
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

The auth service handles OAuth2 flows. All inter-service
communication uses mTLS.''';

      final result = DocumentParser.parse(handWritten);
      expect(result.warnings, isEmpty);
      expect(result.value.settings.grid, 20);
      expect(result.value.settings.background, '#ffffff');

      // Verify structure
      expect(result.value.sections, hasLength(3));
      expect(result.value.sections[0], isA<ProseSection>());
      expect(result.value.sections[1], isA<SketchSection>());
      expect(result.value.sections[2], isA<ProseSection>());

      // Verify sketch elements
      final sketch = result.value.sections[1] as SketchSection;
      final rects = sketch.elements.whereType<RectangleElement>().toList();
      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      final ellipses = sketch.elements.whereType<EllipseElement>().toList();
      final texts = sketch.elements.whereType<TextElement>().toList();

      expect(rects, hasLength(2));
      expect(arrows, hasLength(1));
      expect(ellipses, hasLength(1));
      expect(texts, hasLength(3)); // 3 labels (auth, gateway, db)

      // Arrow bindings resolved
      expect(arrows.first.startBinding, isNotNull);
      expect(arrows.first.endBinding, isNotNull);

      // Aliases present
      expect(result.value.aliases, containsPair('auth', isNotNull));
      expect(result.value.aliases, containsPair('gateway', isNotNull));
      expect(result.value.aliases, containsPair('db', isNotNull));

      // Re-serialize
      final output = DocumentSerializer.serialize(result.value);

      // Verify key content is preserved
      expect(output, contains('markdraw: 1'));
      expect(output, contains('grid: 20'));
      expect(output, contains('# Architecture Overview'));
      expect(output, contains('```sketch'));
      expect(output, contains('rect "Auth Service"'));
      expect(output, contains('from auth to gateway'));
      expect(output, contains('mTLS'));
    });
  });
}
