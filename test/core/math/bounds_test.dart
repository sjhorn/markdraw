import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/math/size.dart';

void main() {
  group('Bounds', () {
    test('constructs from origin and size', () {
      const b = Bounds(Point(10.0, 20.0), DrawSize(100.0, 50.0));
      expect(b.origin, const Point(10.0, 20.0));
      expect(b.size, const DrawSize(100.0, 50.0));
    });

    test('fromLTWH factory', () {
      final b = Bounds.fromLTWH(10.0, 20.0, 100.0, 50.0);
      expect(b.origin, const Point(10.0, 20.0));
      expect(b.size, const DrawSize(100.0, 50.0));
    });

    test('left, top, right, bottom accessors', () {
      const b = Bounds(Point(10.0, 20.0), DrawSize(100.0, 50.0));
      expect(b.left, 10.0);
      expect(b.top, 20.0);
      expect(b.right, 110.0);
      expect(b.bottom, 70.0);
    });

    test('center', () {
      const b = Bounds(Point(10.0, 20.0), DrawSize(100.0, 50.0));
      expect(b.center, const Point(60.0, 45.0));
    });

    test('contains returns true for point inside', () {
      const b = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      expect(b.containsPoint(const Point(5.0, 5.0)), isTrue);
      expect(b.containsPoint(const Point(0.0, 0.0)), isTrue);
      expect(b.containsPoint(const Point(10.0, 10.0)), isTrue);
    });

    test('contains returns false for point outside', () {
      const b = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      expect(b.containsPoint(const Point(11.0, 5.0)), isFalse);
      expect(b.containsPoint(const Point(5.0, 11.0)), isFalse);
      expect(b.containsPoint(const Point(-1.0, 5.0)), isFalse);
    });

    test('intersects returns true for overlapping bounds', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const b = Bounds(Point(5.0, 5.0), DrawSize(10.0, 10.0));
      expect(a.intersects(b), isTrue);
      expect(b.intersects(a), isTrue);
    });

    test('intersects returns false for non-overlapping bounds', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const b = Bounds(Point(20.0, 20.0), DrawSize(10.0, 10.0));
      expect(a.intersects(b), isFalse);
    });

    test('intersects returns false for adjacent bounds', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const b = Bounds(Point(10.0, 0.0), DrawSize(10.0, 10.0));
      // Adjacent bounds (sharing only an edge) should not intersect
      expect(a.intersects(b), isFalse);
    });

    test('union of two bounds', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const b = Bounds(Point(5.0, 5.0), DrawSize(10.0, 10.0));
      final u = a.union(b);
      expect(u.origin, const Point(0.0, 0.0));
      expect(u.right, 15.0);
      expect(u.bottom, 15.0);
    });

    test('union with non-overlapping bounds', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(5.0, 5.0));
      const b = Bounds(Point(10.0, 10.0), DrawSize(5.0, 5.0));
      final u = a.union(b);
      expect(u.origin, const Point(0.0, 0.0));
      expect(u.right, 15.0);
      expect(u.bottom, 15.0);
    });

    test('equality', () {
      const a = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const b = Bounds(Point(0.0, 0.0), DrawSize(10.0, 10.0));
      const c = Bounds(Point(1.0, 0.0), DrawSize(10.0, 10.0));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString returns readable format', () {
      const b = Bounds(Point(1.0, 2.0), DrawSize(3.0, 4.0));
      expect(b.toString(), 'Bounds(Point(1.0, 2.0), DrawSize(3.0, 4.0))');
    });
  });
}
