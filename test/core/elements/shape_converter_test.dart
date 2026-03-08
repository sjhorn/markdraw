import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('ShapeConverter.cycleShape', () {
    test('rectangle → diamond', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        strokeColor: '#ff0000',
      );
      final result = ShapeConverter.cycleShape(rect);
      expect(result, isA<DiamondElement>());
      expect(result!.x, 10);
      expect(result.y, 20);
      expect(result.width, 100);
      expect(result.height, 50);
      expect(result.strokeColor, '#ff0000');
    });

    test('diamond → ellipse', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final result = ShapeConverter.cycleShape(diamond);
      expect(result, isA<EllipseElement>());
      expect(result!.x, 10);
    });

    test('ellipse → rectangle', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final result = ShapeConverter.cycleShape(ellipse);
      expect(result, isA<RectangleElement>());
      expect(result!.x, 10);
    });

    test('reverse: rectangle → ellipse', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final result = ShapeConverter.cycleShape(rect, reverse: true);
      expect(result, isA<EllipseElement>());
    });

    test('reverse: ellipse → diamond', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final result = ShapeConverter.cycleShape(ellipse, reverse: true);
      expect(result, isA<DiamondElement>());
    });

    test('reverse: diamond → rectangle', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final result = ShapeConverter.cycleShape(diamond, reverse: true);
      expect(result, isA<RectangleElement>());
    });

    test('returns null for line', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
      );
      expect(ShapeConverter.cycleShape(line), isNull);
    });

    test('returns null for text', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'hello',
      );
      expect(ShapeConverter.cycleShape(text), isNull);
    });

    test('preserves all shared properties', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        angle: 0.5,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        fillStyle: FillStyle.hachure,
        strokeWidth: 3.0,
        strokeStyle: StrokeStyle.dashed,
        roughness: 2.0,
        opacity: 0.8,
        groupIds: ['g1'],
        locked: true,
      );
      final result = ShapeConverter.cycleShape(rect)!;
      expect(result.id, rect.id);
      expect(result.angle, 0.5);
      expect(result.strokeColor, '#ff0000');
      expect(result.backgroundColor, '#00ff00');
      expect(result.fillStyle, FillStyle.hachure);
      expect(result.strokeWidth, 3.0);
      expect(result.strokeStyle, StrokeStyle.dashed);
      expect(result.roughness, 2.0);
      expect(result.opacity, 0.8);
      expect(result.groupIds, ['g1']);
      expect(result.locked, true);
    });

    test('full forward cycle returns to same type', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final step1 = ShapeConverter.cycleShape(rect)!;
      final step2 = ShapeConverter.cycleShape(step1)!;
      final step3 = ShapeConverter.cycleShape(step2)!;
      expect(step3, isA<RectangleElement>());
    });
  });
}
