import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('link serialization', () {
    final serializer = SketchLineSerializer();

    test('element with URL link serializes and parses back correctly', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        link: 'https://example.com',
      );

      final line = serializer.serialize(element, alias: 'r1');
      expect(line, contains('link="https://example.com"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, 'https://example.com');
    });

    test('element with element link (#id) round-trips correctly', () {
      final element = EllipseElement(
        id: const ElementId('e1'),
        x: 0,
        y: 0,
        width: 80,
        height: 80,
        link: '#target123',
      );

      final line = serializer.serialize(element, alias: 'e1');
      expect(line, contains('link="#target123"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, '#target123');
    });

    test('element without link omits link= from output', () {
      final element = RectangleElement(
        id: const ElementId('r2'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );

      final line = serializer.serialize(element, alias: 'r2');
      expect(line, isNot(contains('link=')));
    });

    test('element with empty link omits link= from output', () {
      final element = DiamondElement(
        id: const ElementId('d1'),
        x: 0,
        y: 0,
        width: 60,
        height: 60,
        link: '',
      );

      final line = serializer.serialize(element, alias: 'd1');
      expect(line, isNot(contains('link=')));
    });

    test('link serialization works for text elements', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 24,
        text: 'Click me',
        link: 'https://dart.dev',
      );

      final line = serializer.serialize(element, alias: 't1');
      expect(line, contains('link="https://dart.dev"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, 'https://dart.dev');
    });

    test('link serialization works for arrow elements', () {
      final element = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        link: 'https://flutter.dev',
      );

      final line = serializer.serialize(element, alias: 'a1');
      expect(line, contains('link="https://flutter.dev"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, 'https://flutter.dev');
    });

    test('link serialization works for freedraw elements', () {
      final element = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
        points: [const Point(0, 0), const Point(50, 50)],
        link: '#another',
      );

      final line = serializer.serialize(element, alias: 'f1');
      expect(line, contains('link="#another"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, '#another');
    });

    test('link with spaces in URL round-trips correctly', () {
      final element = RectangleElement(
        id: const ElementId('r3'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        link: 'https://example.com/my page',
      );

      final line = serializer.serialize(element, alias: 'r3');
      expect(line, contains('link="https://example.com/my page"'));

      final parser = SketchLineParser();
      final result = parser.parseLine(line, 1);
      expect(result.value, isNotNull);
      expect(result.value!.link, 'https://example.com/my page');
    });

    test('full document round-trip preserves links', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        link: 'https://example.com',
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 200,
        width: 80,
        height: 80,
      ));

      final doc = SceneDocumentConverter.sceneToDocument(scene);
      final serialized = DocumentSerializer.serialize(doc);

      // Verify the serialized output contains the link
      expect(serialized, contains('link="https://example.com"'));

      final parsed = DocumentParser.parse(serialized);

      final roundTripped =
          SceneDocumentConverter.documentToScene(parsed.value);

      // Find the rectangle by type
      final rect = roundTripped.activeElements
          .firstWhere((e) => e is RectangleElement);
      expect(rect.link, 'https://example.com');

      // The ellipse should have no link
      final ellipse = roundTripped.activeElements
          .firstWhere((e) => e is EllipseElement);
      expect(ellipse.link, isNull);
    });
  });
}
