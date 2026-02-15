import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/math/point.dart';

void main() {
  group('Point', () {
    test('constructs with x and y', () {
      const p = Point(3.0, 4.0);
      expect(p.x, 3.0);
      expect(p.y, 4.0);
    });

    test('zero constant', () {
      expect(Point.zero.x, 0.0);
      expect(Point.zero.y, 0.0);
    });

    test('equality based on x and y values', () {
      const a = Point(1.0, 2.0);
      const b = Point(1.0, 2.0);
      const c = Point(1.0, 3.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = Point(1.0, 2.0);
      const b = Point(1.0, 2.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('addition', () {
      const a = Point(1.0, 2.0);
      const b = Point(3.0, 4.0);
      expect(a + b, const Point(4.0, 6.0));
    });

    test('subtraction', () {
      const a = Point(5.0, 7.0);
      const b = Point(2.0, 3.0);
      expect(a - b, const Point(3.0, 4.0));
    });

    test('scalar multiplication', () {
      const p = Point(3.0, 4.0);
      expect(p * 2.0, const Point(6.0, 8.0));
    });

    test('distanceTo calculates Euclidean distance', () {
      const a = Point(0.0, 0.0);
      const b = Point(3.0, 4.0);
      expect(a.distanceTo(b), 5.0);
    });

    test('distanceTo is zero for same point', () {
      const a = Point(1.0, 2.0);
      expect(a.distanceTo(a), 0.0);
    });

    test('toString returns readable format', () {
      const p = Point(1.5, 2.5);
      expect(p.toString(), 'Point(1.5, 2.5)');
    });
  });
}
