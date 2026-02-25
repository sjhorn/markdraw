import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SketchLineSerializer serializer;

  setUp(() {
    serializer = SketchLineSerializer();
  });

  // --- Serializer ---

  group('Serializer groupIds', () {
    test('emits group= for single groupId', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        groupIds: const ['g1'],
        seed: 42,
      );
      final line = serializer.serialize(rect, alias: 'auth');
      expect(line, contains('group=g1'));
    });

    test('emits comma-separated groupIds for multiple groups', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        groupIds: const ['inner', 'outer'],
        seed: 42,
      );
      final line = serializer.serialize(rect, alias: 'auth');
      expect(line, contains('group=inner,outer'));
    });

    test('omits group= when groupIds is empty', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
      );
      final line = serializer.serialize(rect, alias: 'auth');
      expect(line, isNot(contains('group=')));
    });
  });

  // --- Parser ---

  group('Parser groupIds', () {
    test('parses group= with single groupId', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'rect id=auth at 100,200 size 160x80 group=g1 seed=42',
        1,
      );
      expect(result.value, isNotNull);
      expect(result.value!.groupIds, ['g1']);
    });

    test('parses group= with comma-separated groupIds', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'rect id=auth at 100,200 size 160x80 group=inner,outer seed=42',
        1,
      );
      expect(result.value, isNotNull);
      expect(result.value!.groupIds, ['inner', 'outer']);
    });

    test('defaults to empty groupIds when group= absent', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'rect id=auth at 100,200 size 160x80 seed=42',
        1,
      );
      expect(result.value, isNotNull);
      expect(result.value!.groupIds, isEmpty);
    });
  });

  // --- Round-trip per element type ---

  group('Round-trip groupIds', () {
    test('rectangle round-trip preserves groupIds', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        groupIds: const ['g1', 'g2'],
        seed: 42,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['g1', 'g2']);
    });

    test('ellipse round-trip preserves groupIds', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        groupIds: const ['gA'],
        seed: 42,
      );
      final line = serializer.serialize(ellipse, alias: 'e1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['gA']);
    });

    test('diamond round-trip preserves groupIds', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        groupIds: const ['gX'],
        seed: 42,
      );
      final line = serializer.serialize(diamond, alias: 'd1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['gX']);
    });

    test('text round-trip preserves groupIds', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 10,
        y: 20,
        width: 100,
        height: 30,
        text: 'hello',
        groupIds: const ['gT'],
        seed: 42,
      );
      final line = serializer.serialize(text, alias: 't1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['gT']);
    });

    test('line round-trip preserves groupIds', () {
      final lineElem = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [Point(0, 0), Point(100, 100)],
        groupIds: const ['gL'],
        seed: 42,
      );
      final line = serializer.serialize(lineElem, alias: 'l1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['gL']);
    });

    test('freedraw round-trip preserves groupIds', () {
      final fd = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [Point(0, 0), Point(50, 50)],
        groupIds: const ['gF'],
        seed: 42,
      );
      final line = serializer.serialize(fd, alias: 'f1');
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['gF']);
    });
  });

  // --- Document-level round-trip ---

  group('Document-level groupIds round-trip', () {
    test('multiple grouped elements preserve their groupIds', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 50,
        groupIds: const ['g1'],
        seed: 1,
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 200,
        width: 80,
        height: 40,
        groupIds: const ['g1'],
        seed: 2,
      );
      final r3 = RectangleElement(
        id: const ElementId('r3'),
        x: 400,
        y: 400,
        width: 60,
        height: 30,
        seed: 3,
      );

      final lines = [
        serializer.serialize(r1, alias: 'a'),
        serializer.serialize(r2, alias: 'b'),
        serializer.serialize(r3, alias: 'c'),
      ];

      final parser = SketchLineParser();
      final elements = <dynamic>[];
      for (var i = 0; i < lines.length; i++) {
        final result = parser.parseLine(lines[i], i + 1);
        if (result.value != null) elements.add(result.value!);
      }

      expect(elements, hasLength(3));
      expect(elements[0].groupIds, ['g1']);
      expect(elements[1].groupIds, ['g1']);
      expect(elements[2].groupIds, isEmpty);
    });

    test('serializeWithLabel preserves groupIds on shape with label', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        groupIds: const ['g1'],
        seed: 42,
      );
      final line = serializer.serializeWithLabel(rect, 'Hello', alias: 'auth');
      expect(line, contains('group=g1'));

      // Parse it back
      final parser = SketchLineParser();
      final parsed = parser.parseLine(line, 1).value!;
      expect(parsed.groupIds, ['g1']);
    });
  });
}
