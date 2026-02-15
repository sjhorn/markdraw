import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/math/size.dart';

void main() {
  group('DrawSize', () {
    test('constructs with width and height', () {
      const s = DrawSize(10.0, 20.0);
      expect(s.width, 10.0);
      expect(s.height, 20.0);
    });

    test('zero constant', () {
      expect(DrawSize.zero.width, 0.0);
      expect(DrawSize.zero.height, 0.0);
    });

    test('equality based on width and height', () {
      const a = DrawSize(10.0, 20.0);
      const b = DrawSize(10.0, 20.0);
      const c = DrawSize(10.0, 30.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = DrawSize(10.0, 20.0);
      const b = DrawSize(10.0, 20.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('area', () {
      const s = DrawSize(5.0, 4.0);
      expect(s.area, 20.0);
    });

    test('contains returns true for point within size', () {
      const s = DrawSize(10.0, 10.0);
      expect(s.contains(5.0, 5.0), isTrue);
      expect(s.contains(0.0, 0.0), isTrue);
      expect(s.contains(10.0, 10.0), isTrue);
    });

    test('contains returns false for point outside size', () {
      const s = DrawSize(10.0, 10.0);
      expect(s.contains(11.0, 5.0), isFalse);
      expect(s.contains(5.0, 11.0), isFalse);
      expect(s.contains(-1.0, 5.0), isFalse);
    });

    test('toString returns readable format', () {
      const s = DrawSize(10.0, 20.0);
      expect(s.toString(), 'DrawSize(10.0, 20.0)');
    });
  });
}
