import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/rendering/interactive/snap_line.dart';

void main() {
  group('SnapLineOrientation', () {
    test('has horizontal and vertical', () {
      expect(SnapLineOrientation.values.length, 2);
      expect(SnapLineOrientation.values,
          containsAll([SnapLineOrientation.horizontal, SnapLineOrientation.vertical]));
    });
  });

  group('SnapLine', () {
    test('horizontal snap line has position (y) and start/end (x extent)', () {
      const line = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 100,
        start: 50,
        end: 300,
      );
      expect(line.orientation, SnapLineOrientation.horizontal);
      expect(line.position, 100);
      expect(line.start, 50);
      expect(line.end, 300);
    });

    test('vertical snap line has position (x) and start/end (y extent)', () {
      const line = SnapLine(
        orientation: SnapLineOrientation.vertical,
        position: 200,
        start: 10,
        end: 400,
      );
      expect(line.orientation, SnapLineOrientation.vertical);
      expect(line.position, 200);
      expect(line.start, 10);
      expect(line.end, 400);
    });

    test('equality by value', () {
      const a = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 100,
        start: 0,
        end: 500,
      );
      const b = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 100,
        start: 0,
        end: 500,
      );
      const c = SnapLine(
        orientation: SnapLineOrientation.vertical,
        position: 100,
        start: 0,
        end: 500,
      );
      const d = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 200,
        start: 0,
        end: 500,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      const a = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 100,
        start: 0,
        end: 500,
      );
      const b = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 100,
        start: 0,
        end: 500,
      );
      expect(a.hashCode, b.hashCode);
    });
  });
}
