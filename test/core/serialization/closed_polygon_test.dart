import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

LineElement _closedLine({
  String id = 'l1',
  List<Point>? points,
}) =>
    LineElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: points ??
          const [Point(0, 0), Point(100, 0), Point(50, 100), Point(0, 0)],
      closed: true,
    );

LineElement _openLine({
  String id = 'l2',
  List<Point>? points,
}) =>
    LineElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: points ?? const [Point(0, 0), Point(100, 100)],
    );

MarkdrawDocument _doc(List<LineElement> elements) =>
    MarkdrawDocument(sections: [SketchSection(elements)]);

void main() {
  group('.markdraw serialization', () {
    final serializer = SketchLineSerializer();

    test('serialize closed line emits closed flag', () {
      final line = _closedLine();
      final text = serializer.serialize(line, alias: 'l1');

      expect(text, contains('closed'));
      expect(text, startsWith('line'));
    });

    test('serialize open line omits closed flag', () {
      final line = _openLine();
      final text = serializer.serialize(line, alias: 'l2');

      expect(text, isNot(contains('closed')));
    });

    test('parse closed line', () {
      final parser = SketchLineParser();
      const text =
          'line id=l1 points=[[0,0],[100,0],[50,100],[0,0]] closed seed=1';
      final result = parser.parseLine(text, 1);

      expect(result.value, isA<LineElement>());
      final line = result.value! as LineElement;
      expect(line.closed, isTrue);
    });

    test('parse open line', () {
      final parser = SketchLineParser();
      const text = 'line id=l2 points=[[0,0],[100,100]] seed=1';
      final result = parser.parseLine(text, 1);

      expect(result.value, isA<LineElement>());
      final line = result.value! as LineElement;
      expect(line.closed, isFalse);
    });

    test('round-trip closed line', () {
      final line = _closedLine();
      final text = serializer.serialize(line, alias: 'l1');

      final parser = SketchLineParser();
      final result = parser.parseLine(text, 1);
      final parsed = result.value! as LineElement;

      expect(parsed.closed, isTrue);
      expect(parsed.points.length, line.points.length);
    });

    test('round-trip open line unchanged', () {
      final line = _openLine();
      final text = serializer.serialize(line, alias: 'l2');

      final parser = SketchLineParser();
      final result = parser.parseLine(text, 1);
      final parsed = result.value! as LineElement;

      expect(parsed.closed, isFalse);
    });
  });

  group('Excalidraw JSON serialization', () {
    test('serialize closed line includes polygon: true', () {
      final line = _closedLine();
      final json = ExcalidrawJsonCodec.serialize(_doc([line]));
      final data = jsonDecode(json) as Map<String, dynamic>;
      final elements = data['elements'] as List;
      final first = elements.first as Map<String, dynamic>;

      expect(first['polygon'], isTrue);
    });

    test('serialize open line omits polygon', () {
      final line = _openLine();
      final json = ExcalidrawJsonCodec.serialize(_doc([line]));
      final data = jsonDecode(json) as Map<String, dynamic>;
      final elements = data['elements'] as List;
      final first = elements.first as Map<String, dynamic>;

      expect(first.containsKey('polygon'), isFalse);
    });

    test('parse polygon line from JSON', () {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'elements': [
          {
            'id': 'l1',
            'type': 'line',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'points': [
              [0, 0],
              [100, 0],
              [50, 100],
              [0, 0],
            ],
            'polygon': true,
            'seed': 1,
          },
        ],
      });

      final result = ExcalidrawJsonCodec.parse(json);
      final elements = result.value.allElements;
      expect(elements.length, 1);
      final line = elements.first as LineElement;
      expect(line.closed, isTrue);
    });

    test('parse non-polygon line from JSON', () {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'elements': [
          {
            'id': 'l2',
            'type': 'line',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'points': [
              [0, 0],
              [100, 100],
            ],
            'seed': 1,
          },
        ],
      });

      final result = ExcalidrawJsonCodec.parse(json);
      final line = result.value.allElements.first as LineElement;
      expect(line.closed, isFalse);
    });

    test('round-trip closed line through JSON', () {
      final line = _closedLine();
      final json = ExcalidrawJsonCodec.serialize(_doc([line]));
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements.first as LineElement;

      expect(parsed.closed, isTrue);
      expect(parsed.points.length, line.points.length);
    });

    test('round-trip open line through JSON', () {
      final line = _openLine();
      final json = ExcalidrawJsonCodec.serialize(_doc([line]));
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements.first as LineElement;

      expect(parsed.closed, isFalse);
    });
  });

  group('Clipboard', () {
    test('copy/paste preserves closed flag', () {
      final line = _closedLine();
      final text = ClipboardCodec.serialize([line]);
      final parsed = ClipboardCodec.parse(text);

      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      final parsedLine = parsed.first as LineElement;
      expect(parsedLine.closed, isTrue);
    });

    test('copy/paste open line has closed false', () {
      final line = _openLine();
      final text = ClipboardCodec.serialize([line]);
      final parsed = ClipboardCodec.parse(text);

      expect(parsed, isNotNull);
      final parsedLine = parsed!.first as LineElement;
      expect(parsedLine.closed, isFalse);
    });
  });
}
