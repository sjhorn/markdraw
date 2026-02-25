import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ArrowElement _elbowArrow({
  String id = 'a1',
  List<Point>? points,
  PointBinding? startBinding,
  PointBinding? endBinding,
}) =>
    ArrowElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 50,
      points: points ?? const [Point(0, 0), Point(0, 50), Point(100, 50)],
      endArrowhead: Arrowhead.arrow,
      startBinding: startBinding,
      endBinding: endBinding,
      elbowed: true,
    );

ArrowElement _regularArrow({
  String id = 'a2',
  List<Point>? points,
}) =>
    ArrowElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: points ?? const [Point(0, 0), Point(100, 100)],
      endArrowhead: Arrowhead.arrow,
    );

MarkdrawDocument _doc(List<ArrowElement> elements) =>
    MarkdrawDocument(sections: [SketchSection(elements)]);

void main() {
  group('.markdraw serialization', () {
    final serializer = SketchLineSerializer();

    test('serialize elbowed arrow emits elbowed flag', () {
      final arrow = _elbowArrow();
      final line = serializer.serialize(arrow, alias: 'a1');

      expect(line, contains('elbowed'));
      expect(line, startsWith('arrow'));
    });

    test('serialize non-elbowed arrow omits elbowed flag', () {
      final arrow = _regularArrow();
      final line = serializer.serialize(arrow, alias: 'a2');

      expect(line, isNot(contains('elbowed')));
    });

    test('parse elbowed arrow', () {
      final parser = SketchLineParser();
      const line =
          'arrow id=a1 points=[[0,0],[0,50],[100,50]] elbowed seed=1';
      final result = parser.parseLine(line, 1);

      expect(result.value, isA<ArrowElement>());
      final arrow = result.value! as ArrowElement;
      expect(arrow.elbowed, isTrue);
    });

    test('parse non-elbowed arrow', () {
      final parser = SketchLineParser();
      const line = 'arrow id=a2 points=[[0,0],[100,100]] seed=1';
      final result = parser.parseLine(line, 1);

      expect(result.value, isA<ArrowElement>());
      final arrow = result.value! as ArrowElement;
      expect(arrow.elbowed, isFalse);
    });

    test('round-trip elbowed arrow', () {
      final arrow = _elbowArrow();
      final line = serializer.serialize(arrow, alias: 'a1');

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as ArrowElement;

      expect(parsed.elbowed, isTrue);
      expect(parsed.points.length, arrow.points.length);
    });

    test('round-trip non-elbowed arrow unchanged', () {
      final arrow = _regularArrow();
      final line = serializer.serialize(arrow, alias: 'a2');

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      final parsed = result.value! as ArrowElement;

      expect(parsed.elbowed, isFalse);
    });
  });

  group('Excalidraw JSON serialization', () {
    test('serialize elbowed arrow includes elbowed: true', () {
      final arrow = _elbowArrow();
      final json = ExcalidrawJsonCodec.serialize(_doc([arrow]));
      final data = jsonDecode(json) as Map<String, dynamic>;
      final elements = data['elements'] as List;
      final first = elements.first as Map<String, dynamic>;

      expect(first['elbowed'], isTrue);
    });

    test('serialize non-elbowed arrow omits elbowed', () {
      final arrow = _regularArrow();
      final json = ExcalidrawJsonCodec.serialize(_doc([arrow]));
      final data = jsonDecode(json) as Map<String, dynamic>;
      final elements = data['elements'] as List;
      final first = elements.first as Map<String, dynamic>;

      expect(first.containsKey('elbowed'), isFalse);
    });

    test('parse elbowed arrow from JSON', () {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'elements': [
          {
            'id': 'a1',
            'type': 'arrow',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 50,
            'points': [
              [0, 0],
              [0, 50],
              [100, 50],
            ],
            'elbowed': true,
            'endArrowhead': 'arrow',
            'seed': 1,
          },
        ],
      });

      final result = ExcalidrawJsonCodec.parse(json);
      final elements = result.value.allElements;
      expect(elements.length, 1);
      final arrow = elements.first as ArrowElement;
      expect(arrow.elbowed, isTrue);
    });

    test('round-trip elbowed arrow through JSON', () {
      final arrow = _elbowArrow();
      final json = ExcalidrawJsonCodec.serialize(_doc([arrow]));
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements.first as ArrowElement;

      expect(parsed.elbowed, isTrue);
      expect(parsed.points.length, arrow.points.length);
    });

    test('round-trip non-elbowed arrow through JSON', () {
      final arrow = _regularArrow();
      final json = ExcalidrawJsonCodec.serialize(_doc([arrow]));
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements.first as ArrowElement;

      expect(parsed.elbowed, isFalse);
    });
  });

  group('Clipboard', () {
    test('copy/paste preserves elbowed flag', () {
      final arrow = _elbowArrow();
      final text = ClipboardCodec.serialize([arrow]);
      final parsed = ClipboardCodec.parse(text);

      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      final parsedArrow = parsed.first as ArrowElement;
      expect(parsedArrow.elbowed, isTrue);
    });
  });
}
