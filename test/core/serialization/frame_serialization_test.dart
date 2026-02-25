import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SketchLineSerializer serializer;

  setUp(() {
    serializer = SketchLineSerializer();
  });

  group('Serializer', () {
    test('serializes frame element with label', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        label: 'Section A',
        seed: 42,
      );
      final line = serializer.serialize(frame, alias: 'sec');
      expect(line, contains('frame'));
      expect(line, contains('"Section A"'));
      expect(line, contains('id=sec'));
      expect(line, contains('at 100,200'));
      expect(line, contains('size 400x300'));
      expect(line, contains('seed=42'));
    });

    test('serializes frame element with default label', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 200,
        height: 100,
        seed: 1,
      );
      final line = serializer.serialize(frame, alias: 'f1');
      expect(line, contains('"Frame"'));
    });

    test('serializes frameId on child element', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 50,
        frameId: 'sec',
        seed: 7,
      );
      final line = serializer.serialize(rect, alias: 'box');
      expect(line, contains('frame=sec'));
    });

    test('omits frameId when null', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 50,
        seed: 7,
      );
      final line = serializer.serialize(rect, alias: 'box');
      expect(line, isNot(contains('frame=')));
    });
  });

  group('Parser', () {
    test('parses frame element', () {
      final parser = SketchLineParser();
      final result =
          parser.parseLine('frame "Section A" id=sec at 100,200 size 400x300 seed=42', 1);
      final element = result.value;
      expect(element, isA<FrameElement>());
      final frame = element as FrameElement;
      expect(frame.label, 'Section A');
      expect(frame.x, 100);
      expect(frame.y, 200);
      expect(frame.width, 400);
      expect(frame.height, 300);
      expect(frame.seed, 42);
    });

    test('parses frame with default label when no quoted string', () {
      final parser = SketchLineParser();
      final result =
          parser.parseLine('frame id=f1 at 0,0 size 200x100 seed=1', 1);
      final frame = result.value as FrameElement;
      expect(frame.label, 'Frame');
    });

    test('parses frameId on child element', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
          'rect id=box at 120,220 size 80x40 frame=sec seed=7', 1);
      final element = result.value!;
      expect(element.frameId, 'sec');
    });

    test('frameId is null when absent', () {
      final parser = SketchLineParser();
      final result =
          parser.parseLine('rect id=box at 120,220 size 80x40 seed=7', 1);
      final element = result.value!;
      expect(element.frameId, isNull);
    });
  });

  group('Round-trip', () {
    test('frame element round-trips', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        label: 'Section A',
        seed: 42,
      );
      final line = serializer.serialize(frame, alias: 'sec');
      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      final parsed = result.value as FrameElement;
      expect(parsed.label, 'Section A');
      expect(parsed.x, 100);
      expect(parsed.y, 200);
      expect(parsed.width, 400);
      expect(parsed.height, 300);
      expect(parsed.seed, 42);
    });

    test('frame element without alias round-trips', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 50,
        y: 60,
        width: 200,
        height: 150,
        label: 'My Frame',
        seed: 99,
      );
      final line = serializer.serialize(frame);
      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      final parsed = result.value as FrameElement;
      expect(parsed.label, 'My Frame');
      expect(parsed.x, 50);
      expect(parsed.y, 60);
      expect(parsed.width, 200);
      expect(parsed.height, 150);
    });

    test('child with frameId round-trips', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 50,
        frameId: 'sec',
        seed: 7,
      );
      final line = serializer.serialize(rect, alias: 'box');
      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      final parsed = result.value!;
      expect(parsed.frameId, 'sec');
    });

    test('child without frameId round-trips as null', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 50,
        seed: 7,
      );
      final line = serializer.serialize(rect, alias: 'box');
      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value!.frameId, isNull);
    });
  });
}
