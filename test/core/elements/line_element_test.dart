import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('LineElement', () {
    LineElement createLine({
      List<Point> points = const [Point(0, 0), Point(100, 100)],
      Arrowhead? startArrowhead,
      Arrowhead? endArrowhead,
    }) {
      return LineElement(
        id: const ElementId('line-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
        points: points,
        startArrowhead: startArrowhead,
        endArrowhead: endArrowhead,
      );
    }

    test('constructs with type line', () {
      final l = createLine();
      expect(l.type, 'line');
    });

    test('stores points', () {
      final l = createLine();
      expect(l.points.length, 2);
      expect(l.points[0], const Point(0, 0));
      expect(l.points[1], const Point(100, 100));
    });

    test('supports arrowheads', () {
      final l = createLine(
        startArrowhead: Arrowhead.arrow,
        endArrowhead: Arrowhead.triangle,
      );
      expect(l.startArrowhead, Arrowhead.arrow);
      expect(l.endArrowhead, Arrowhead.triangle);
    });

    test('arrowheads default to null', () {
      final l = createLine();
      expect(l.startArrowhead, isNull);
      expect(l.endArrowhead, isNull);
    });

    test('copyWith preserves line properties', () {
      final l = createLine(startArrowhead: Arrowhead.arrow);
      final modified = l.copyWith(x: 50.0);
      expect(modified.points.length, 2);
      expect(modified.startArrowhead, Arrowhead.arrow);
    });

    test('copyWithLine changes line-specific properties', () {
      final l = createLine();
      final modified = l.copyWithLine(
        points: const [Point(0, 0), Point(50, 50), Point(100, 0)],
        endArrowhead: Arrowhead.bar,
      );
      expect(modified.points.length, 3);
      expect(modified.endArrowhead, Arrowhead.bar);
    });

    test('bumpVersion returns LineElement', () {
      final l = createLine();
      expect(l.bumpVersion(), isA<LineElement>());
    });

    group('closed', () {
      test('defaults to false', () {
        final l = createLine();
        expect(l.closed, isFalse);
      });

      test('can be set to true via constructor', () {
        final l = LineElement(
          id: const ElementId('line-1'),
          x: 0,
          y: 0,
          width: 100,
          height: 100,
          points: const [Point(0, 0), Point(100, 0), Point(50, 100), Point(0, 0)],
          closed: true,
        );
        expect(l.closed, isTrue);
      });

      test('copyWithLine sets closed', () {
        final l = createLine();
        final modified = l.copyWithLine(closed: true);
        expect(modified.closed, isTrue);
      });

      test('copyWithLine preserves closed when not specified', () {
        final l = LineElement(
          id: const ElementId('line-1'),
          x: 0,
          y: 0,
          width: 100,
          height: 100,
          points: const [Point(0, 0), Point(100, 100)],
          closed: true,
        );
        final modified = l.copyWithLine(
          points: const [Point(0, 0), Point(50, 50)],
        );
        expect(modified.closed, isTrue);
      });

      test('copyWith preserves closed', () {
        final l = LineElement(
          id: const ElementId('line-1'),
          x: 0,
          y: 0,
          width: 100,
          height: 100,
          points: const [Point(0, 0), Point(100, 100)],
          closed: true,
        );
        final modified = l.copyWith(x: 50.0);
        expect(modified.closed, isTrue);
      });
    });
  });

  group('Arrowhead', () {
    test('has expected variants', () {
      expect(Arrowhead.values, contains(Arrowhead.arrow));
      expect(Arrowhead.values, contains(Arrowhead.bar));
      expect(Arrowhead.values, contains(Arrowhead.dot));
      expect(Arrowhead.values, contains(Arrowhead.triangle));
    });
  });
}
