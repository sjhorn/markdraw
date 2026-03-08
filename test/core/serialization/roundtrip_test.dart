import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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
        id: const ElementId('r1'),
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
    });

    test('alias used as element ID when parsed', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'myRect');
      expect(line, contains('id=myRect'));
      expect(line, isNot(contains('eid=')));
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as RectangleElement;
      expect(parsed.id.value, 'myRect');
      expect(parser.aliases['myRect'], 'myRect');
    });

    test('element without alias has no id= in output', () {
      final original = RectangleElement(
        id: const ElementId('some-uuid'),
        x: 10,
        y: 20,
        width: 50,
        height: 60,
        seed: 7,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      expect(line, isNot(contains('id=')));
      expect(line, isNot(contains('eid=')));
    });

    test('rectangle with non-default properties round-trips', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
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
        roundness: const Roundness.adaptive(value: 8),
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
      expect(parsed.angle, closeTo(original.angle, 0.02));
      expect(parsed.locked, original.locked);
    });

    test('ellipse round-trips', () {
      final original = EllipseElement(
        id: const ElementId('e1'),
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
        id: const ElementId('d1'),
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
        id: const ElementId('t1'),
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
      expect(parsed.width, original.width);
      expect(parsed.height, original.height);
    });

    test('line round-trips', () {
      final original = LineElement(
        id: const ElementId('l1'),
        x: 50,
        y: 75,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
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
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.points, hasLength(3));
      expect(parsed.points[0], const Point(0, 0));
      expect(parsed.points[1], const Point(100, 0));
      expect(parsed.points[2], const Point(100, 100));
      expect(parsed.startArrowhead, Arrowhead.dot);
      expect(parsed.endArrowhead, Arrowhead.triangle);
      expect(parsed.strokeStyle, StrokeStyle.dashed);
    });

    test('arrow without bindings round-trips', () {
      final original = ArrowElement(
        id: const ElementId('a1'),
        x: 30,
        y: 60,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startArrowhead: Arrowhead.bar,
        endArrowhead: Arrowhead.dot,
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original);
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as ArrowElement;
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.points[0], const Point(0, 0));
      expect(parsed.points[1], const Point(200, 0));
      expect(parsed.startArrowhead, Arrowhead.bar);
      expect(parsed.endArrowhead, Arrowhead.dot);
    });

    test('freedraw round-trips', () {
      final original = FreedrawElement(
        id: const ElementId('f1'),
        x: 100,
        y: 200,
        width: 10,
        height: 8,
        points: [const Point(0, 0), const Point(5, 2), const Point(10, 8)],
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
      expect(parsed.x, original.x);
      expect(parsed.y, original.y);
      expect(parsed.width, original.width);
      expect(parsed.height, original.height);
      expect(parsed.points, hasLength(3));
      expect(parsed.points[0], const Point(0, 0));
      expect(parsed.points[1], const Point(5, 2));
      expect(parsed.points[2], const Point(10, 8));
      expect(parsed.pressures, [0.5, 0.7, 0.9]);
      expect(parsed.simulatePressure, isTrue);
      expect(parsed.strokeColor, '#1e1e1e');
    });

    test('fill-style cross-hatch round-trips', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
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
        id: const ElementId('r1'),
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
      const input = '''```markdraw
rect id=auth at 100,200 160x80
ellipse id=db at 225,400 120x80 fill=#e8f5e9
```''';
      final parseResult = DocumentParser.parse(input);
      final output = DocumentSerializer.serialize(parseResult.value);
      expect(output.trim(), input.trim());
    });

    test('sketch with non-default properties', () {
      const input = '''```markdraw
rect id=r at 10,20 50x60 fill=lime color=red stroke=dotted fill-style=hachure stroke-width=3 roughness=2 opacity=0.5 rounded=8 angle=86 locked
```''';
      final parseResult = DocumentParser.parse(input);
      final output = DocumentSerializer.serialize(parseResult.value);
      expect(output.trim(), input.trim());
    });
  });

  group('Color format round-trips', () {
    late SketchLineSerializer serializer;
    late SketchLineParser parser;

    setUp(() {
      serializer = SketchLineSerializer();
      parser = SketchLineParser();
    });

    test('#ff0000 serializes as red and parses back to #ff0000', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        strokeColor: '#ff0000',
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'r');
      expect(line, contains('color=red'));
      final result = parser.parseLine(line, 1);
      expect(result.value!.strokeColor, '#ff0000');
    });

    test('#cccccc serializes as #ccc and parses back to #cccccc', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        backgroundColor: '#cccccc',
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'r');
      expect(line, contains('fill=#ccc'));
      final result = parser.parseLine(line, 1);
      expect(result.value!.backgroundColor, '#cccccc');
    });

    test('non-shortenable hex round-trips unchanged', () {
      final original = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        backgroundColor: '#e3f2fd',
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 'r');
      expect(line, contains('fill=#e3f2fd'));
      final result = parser.parseLine(line, 1);
      expect(result.value!.backgroundColor, '#e3f2fd');
    });

    test('named color input parses and re-serializes as same name', () {
      final result = parser.parseLine(
        'rect id=r at 0,0 100x100 color=red',
        1,
      );
      final parsed = result.value!;
      expect(parsed.strokeColor, '#ff0000');
      final line = serializer.serialize(parsed, alias: 'r');
      expect(line, contains('color=red'));
    });
  });

  group('Document-level round-trips', () {
    test('frontmatter settings round-trip', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(
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
        sections: [const ProseSection('# Hello World\n\nSome content here.')],
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
        id: const ElementId('r1'),
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
          const ProseSection('# Title'),
          SketchSection([rect]),
          const ProseSection('More text'),
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

    test('arrow bindings round-trip with default fixedPoints', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 350,
        y: 200,
        width: 160,
        height: 80,
        seed: 2,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 260,
        y: 240,
        width: 90,
        height: 0,
        points: [const Point(0, 0), const Point(90, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
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

      // Default fixedPoints should NOT emit @x,y suffix
      expect(output, contains('from auth to gw'));
      expect(output, isNot(contains('@')));

      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;
      final parsedArrow =
          sketch.elements.whereType<ArrowElement>().first;
      expect(parsedArrow.startBinding, isNotNull);
      expect(parsedArrow.startBinding!.fixedPoint.x, 1.0);
      expect(parsedArrow.startBinding!.fixedPoint.y, 0.5);
      expect(parsedArrow.endBinding, isNotNull);
      expect(parsedArrow.endBinding!.fixedPoint.x, 0.0);
      expect(parsedArrow.endBinding!.fixedPoint.y, 0.5);
    });

    test('arrow bindings round-trip with non-default fixedPoints as pixels', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 350,
        y: 200,
        width: 160,
        height: 80,
        seed: 2,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 260,
        y: 240,
        width: 90,
        height: 0,
        points: [const Point(0, 0), const Point(90, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.25, 0.75), // 40px, 60px on 160x80
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0.5, 0), // 80px, 0px on 160x80
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

      // Non-default fixedPoints should emit pixel @x,y suffix
      expect(output, contains('from auth@40,60'));
      expect(output, contains('to gw@80,0'));

      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;
      final parsedArrow =
          sketch.elements.whereType<ArrowElement>().first;
      expect(parsedArrow.startBinding, isNotNull);
      expect(parsedArrow.startBinding!.fixedPoint.x, 0.25);
      expect(parsedArrow.startBinding!.fixedPoint.y, 0.75);
      expect(parsedArrow.endBinding, isNotNull);
      expect(parsedArrow.endBinding!.fixedPoint.x, 0.5);
      expect(parsedArrow.endBinding!.fixedPoint.y, 0.0);
    });

    test('arrow bindings round-trip via SceneDocumentConverter auto-aliases', () {
      // Simulates the split-pane live sync scenario: canvas elements have
      // UUID IDs and no manual aliases. SceneDocumentConverter auto-generates
      // aliases like rect1, rect2, arrow1.
      final rect1 = RectangleElement(
        id: const ElementId('uuid-rect-1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: const ElementId('uuid-rect-2'),
        x: 350,
        y: 200,
        width: 160,
        height: 80,
        seed: 2,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('uuid-arrow-1'),
        x: 260,
        y: 240,
        width: 90,
        height: 0,
        points: [const Point(0, 0), const Point(90, 0)],
        startBinding: const PointBinding(
          elementId: 'uuid-rect-1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'uuid-rect-2',
          fixedPoint: Point(0, 0.5),
        ),
        seed: 3,
        versionNonce: 1,
        updated: 0,
      );

      // Use SceneDocumentConverter to auto-generate aliases
      final scene = Scene()
          .addElement(rect1)
          .addElement(rect2)
          .addElement(arrow);
      final doc = SceneDocumentConverter.sceneToDocument(scene);
      final output = DocumentSerializer.serialize(doc);

      // Verify human-friendly aliases are used
      expect(output, contains('id=rect1'));
      expect(output, contains('id=rect2'));
      expect(output, contains('id=arrow1'));
      expect(output, contains('from rect1'));
      expect(output, contains('to rect2'));
      expect(output, isNot(contains('eid=')));
      expect(output, isNot(contains('uuid-')));

      // Parse it back — bindings must resolve
      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;
      final parsedArrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(parsedArrows, hasLength(1));
      final parsedArrow = parsedArrows.first;
      expect(parsedArrow.startBinding, isNotNull,
          reason: 'startBinding should resolve via auto-alias');
      expect(parsedArrow.endBinding, isNotNull,
          reason: 'endBinding should resolve via auto-alias');
    });

    test('bound text properties round-trip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final label = TextElement(
        id: const ElementId('t1'),
        x: 110,
        y: 210,
        width: 140,
        height: 20,
        text: 'Auth Service',
        fontSize: 24,
        fontFamily: 'Nunito',
        textAlign: TextAlign.left,
        verticalAlign: VerticalAlign.top,
        strokeColor: '#ff0000',
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

      // Verify text properties are serialized on shape line
      // (center is the default for bound text, so left must be emitted)
      expect(output, contains('text-size=24'));
      expect(output, contains('text-font=Nunito'));
      expect(output, contains('text-align=left'));
      expect(output, contains('text-valign=top'));
      expect(output, contains('text-color=red'));

      final parsed = DocumentParser.parse(output);
      final sketch = parsed.value.sections.first as SketchSection;
      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.text, 'Auth Service');
      expect(texts.first.fontSize, 24);
      expect(texts.first.fontFamily, 'Nunito');
      expect(texts.first.textAlign, TextAlign.left);
      expect(texts.first.verticalAlign, VerticalAlign.top);
      expect(texts.first.strokeColor, '#ff0000');
      expect(texts.first.containerId, isNotNull);
    });

    test('bound text labels round-trip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final label = TextElement(
        id: const ElementId('t1'),
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
      expect(output, contains('rect id=auth "Auth Service"'));

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
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          seed: 1,
          versionNonce: 1,
          updated: 0,
        ),
        EllipseElement(
          id: const ElementId('e1'),
          x: 200,
          y: 0,
          width: 80,
          height: 80,
          seed: 2,
          versionNonce: 1,
          updated: 0,
        ),
        DiamondElement(
          id: const ElementId('d1'),
          x: 400,
          y: 0,
          width: 60,
          height: 60,
          seed: 3,
          versionNonce: 1,
          updated: 0,
        ),
        TextElement(
          id: const ElementId('t1'),
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
          id: const ElementId('l1'),
          x: 0,
          y: 200,
          width: 100,
          height: 100,
          points: [const Point(0, 0), const Point(100, 100)],
          seed: 5,
          versionNonce: 1,
          updated: 0,
        ),
        ArrowElement(
          id: const ElementId('a1'),
          x: 0,
          y: 300,
          width: 200,
          height: 0,
          points: [const Point(0, 0), const Point(200, 0)],
          seed: 6,
          versionNonce: 1,
          updated: 0,
        ),
        FreedrawElement(
          id: const ElementId('f1'),
          x: 0,
          y: 400,
          width: 50,
          height: 50,
          points: [const Point(0, 0), const Point(25, 25), const Point(50, 50)],
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

    test('arrow with label round-trips', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 400,
        y: 200,
        width: 160,
        height: 80,
        seed: 43,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 260,
        y: 240,
        width: 140,
        height: 0,
        points: [const Point(0, 0), const Point(140, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5),
        ),
        arrowType: ArrowType.round,
        startArrowhead: Arrowhead.dot,
        strokeStyle: StrokeStyle.dashed,
        seed: 44,
        versionNonce: 1,
        updated: 0,
      );
      final label = TextElement(
        id: const ElementId('t1'),
        x: 300,
        y: 230,
        width: 60,
        height: 20,
        text: 'calls',
        fontSize: 16,
        containerId: 'a1',
        seed: 45,
        versionNonce: 1,
        updated: 0,
      );

      final doc = MarkdrawDocument(
        sections: [SketchSection([rect1, rect2, arrow, label])],
        aliases: {'auth': 'r1', 'gw': 'r2', 'conn': 'a1'},
      );
      final output = DocumentSerializer.serialize(doc);

      // Verify arrow-specific data is present
      expect(output, contains('arrow id=conn "calls"'));
      expect(output, contains('from auth'));
      expect(output, contains('to gw'));
      expect(output, contains('arrow-type=round'));
      expect(output, contains('start-arrow=dot'));
      expect(output, contains('stroke=dashed'));
      expect(output, contains('text-size=16'));

      // Parse back
      final parsed = DocumentParser.parse(output);
      expect(parsed.warnings, isEmpty);
      final sketch = parsed.value.sections.first as SketchSection;

      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNotNull);
      expect(arrows.first.endBinding, isNotNull);
      expect(arrows.first.arrowType, ArrowType.round);
      expect(arrows.first.startArrowhead, Arrowhead.dot);
      expect(arrows.first.strokeStyle, StrokeStyle.dashed);

      final texts = sketch.elements.whereType<TextElement>().toList();
      expect(texts, hasLength(1));
      expect(texts.first.text, 'calls');
      expect(texts.first.fontSize, 16);
      expect(texts.first.containerId, isNotNull);
    });

    test('arrow with partial binding round-trips (start bound, end free)', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 500,
        height: 300,
        points: [const Point(0, 0), const Point(500, 300)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        seed: 44,
        versionNonce: 1,
        updated: 0,
      );

      final doc = MarkdrawDocument(
        sections: [SketchSection([rect, arrow])],
        aliases: {'auth': 'r1', 'conn': 'a1'},
      );
      final output = DocumentSerializer.serialize(doc);

      // Verify partial binding serialization
      expect(output, contains('from auth'));
      expect(output, contains('to 500,300'));

      // Parse back
      final parsed = DocumentParser.parse(output);
      expect(parsed.warnings, isEmpty);
      final sketch = parsed.value.sections.first as SketchSection;

      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNotNull);
      expect(arrows.first.endBinding, isNull);

      // Re-serialize should preserve the partial binding
      final output2 = DocumentSerializer.serialize(parsed.value);
      expect(output2, contains('from auth'));
      expect(output2, contains('to 500,300'));
    });

    test('arrow with partial binding round-trips (start free, end bound)', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 400,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 400,
        height: 200,
        points: [const Point(50, 50), const Point(0, 0)],
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0, 0.5),
        ),
        seed: 44,
        versionNonce: 1,
        updated: 0,
      );

      final doc = MarkdrawDocument(
        sections: [SketchSection([rect, arrow])],
        aliases: {'dest': 'r1', 'conn': 'a1'},
      );
      final output = DocumentSerializer.serialize(doc);

      // Verify partial binding serialization
      expect(output, contains('from 50,50'));
      expect(output, contains('to dest'));

      // Parse back
      final parsed = DocumentParser.parse(output);
      expect(parsed.warnings, isEmpty);
      final sketch = parsed.value.sections.first as SketchSection;

      final arrows = sketch.elements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      expect(arrows.first.startBinding, isNull);
      expect(arrows.first.endBinding, isNotNull);
    });
  });

  group('Z-order round-trip', () {
    test('document round-trip preserves element z-order', () {
      // Create a scene with elements in a specific visual order
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        index: 'A',
      );
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 50, y: 50, width: 80, height: 80,
        index: 'B',
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 100, y: 0, width: 100, height: 50,
        index: 'C',
      );

      final scene = Scene()
          .addElement(rect1)
          .addElement(ellipse)
          .addElement(rect2);

      // Convert to document and serialize
      final doc = SceneDocumentConverter.sceneToDocument(scene);
      final text = DocumentSerializer.serialize(doc);

      // Parse back and convert to scene
      final parsed = DocumentParser.parse(text);
      final restoredScene =
          SceneDocumentConverter.documentToScene(parsed.value);

      // Verify z-order is preserved: r1 < e1 < r2
      final ordered =
          restoredScene.orderedElements.where((e) => !e.isDeleted).toList();
      expect(ordered, hasLength(3));
      // First in text = bottom of stack (smallest index)
      expect(ordered[0], isA<RectangleElement>());
      expect(ordered[0].x, 0); // rect1
      expect(ordered[1], isA<EllipseElement>());
      expect(ordered[2], isA<RectangleElement>());
      expect(ordered[2].x, 100); // rect2

      // All should have non-null indices
      for (final e in ordered) {
        expect(e.index, isNotNull);
      }
      expect(ordered[0].index!.compareTo(ordered[1].index!), lessThan(0));
      expect(ordered[1].index!.compareTo(ordered[2].index!), lessThan(0));
    });

    test('parsed elements get fractional indices from document order', () {
      const input = '''```markdraw
rect id=bottom at 0,0 100x50
ellipse id=middle at 50,50 80x80
rect id=top at 100,0 100x50
```''';
      final parsed = DocumentParser.parse(input);
      final scene = SceneDocumentConverter.documentToScene(parsed.value);

      final ordered =
          scene.orderedElements.where((e) => !e.isDeleted).toList();
      expect(ordered, hasLength(3));
      // All should have indices in document order
      expect(ordered[0].id.value, 'bottom');
      expect(ordered[1].id.value, 'middle');
      expect(ordered[2].id.value, 'top');
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

```markdraw
rect "Auth Service" id=auth at 100,200 160x80 fill=#e3f2fd rounded=8
rect "API Gateway" id=gateway at 350,200 160x80 fill=#fff3e0 rounded=8
arrow from auth to gateway stroke=dashed
ellipse "Database" id=db at 225,400 120x80 fill=#e8f5e9
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
      expect(output, contains('```markdraw'));
      expect(output, contains('rect id=auth "Auth Service"'));
      expect(output, contains('from auth to gateway'));
      expect(output, contains('mTLS'));
    });
  });

  group('Font quoting and aliases round-trip', () {
    late SketchLineSerializer serializer;
    late SketchLineParser parser;

    setUp(() {
      serializer = SketchLineSerializer();
      parser = SketchLineParser();
    });

    test('text with quoted font round-trips', () {
      final original = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Hi',
        fontFamily: 'Lilita One',
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(original, alias: 't');
      expect(line, contains('font="Lilita One"'));

      final result = parser.parseLine(line, 1);
      final parsed = result.value! as TextElement;
      expect(parsed.fontFamily, 'Lilita One');
    });

    test('font=hand-drawn parses then serializes without font= (default Excalifont)', () {
      final result = parser.parseLine(
        'text "Hi" at 0,0 font=hand-drawn',
        1,
      );
      final parsed = result.value! as TextElement;
      expect(parsed.fontFamily, 'Excalifont');

      // Excalifont is the default, so serializer omits font=
      final line = serializer.serialize(parsed);
      expect(line, isNot(contains('font=')));
    });

    test('font=code parses to Cascadia and round-trips', () {
      final result = parser.parseLine(
        'text "Hi" at 0,0 font=code',
        1,
      );
      final parsed = result.value! as TextElement;
      expect(parsed.fontFamily, 'Cascadia');

      final line = serializer.serialize(parsed);
      expect(line, contains('font=Cascadia'));

      // Re-parse the serialized line
      final result2 = parser.parseLine(line, 1);
      final reparsed = result2.value! as TextElement;
      expect(reparsed.fontFamily, 'Cascadia');
    });
  });
}
