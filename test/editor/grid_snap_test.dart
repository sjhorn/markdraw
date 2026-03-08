import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';
import 'package:markdraw/src/editor/grid_snap.dart';

void main() {
  group('snapToGrid', () {
    test('snaps point to nearest grid intersection', () {
      final result = snapToGrid(const Point(13, 27), 20);
      expect(result.x, 20);
      expect(result.y, 20);
    });

    test('rounds up at midpoint', () {
      final result = snapToGrid(const Point(10, 10), 20);
      expect(result.x, 20);
      expect(result.y, 20);
    });

    test('rounds down below midpoint', () {
      final result = snapToGrid(const Point(9, 9), 20);
      expect(result.x, 0);
      expect(result.y, 0);
    });

    test('returns point unchanged when gridSize is null', () {
      final result = snapToGrid(const Point(13, 27), null);
      expect(result.x, 13);
      expect(result.y, 27);
    });

    test('snaps negative coordinates', () {
      final result = snapToGrid(const Point(-13, -27), 20);
      expect(result.x, -20);
      expect(result.y, -20);
    });

    test('point on grid stays on grid', () {
      final result = snapToGrid(const Point(40, 60), 20);
      expect(result.x, 40);
      expect(result.y, 60);
    });
  });

  group('snapValue', () {
    test('snaps value to nearest grid line', () {
      expect(snapValue(13, 20), 20.0);
    });

    test('returns value unchanged when gridSize is null', () {
      expect(snapValue(13, null), 13.0);
    });

    test('snaps negative value', () {
      expect(snapValue(-13, 20), -20.0);
    });

    test('value on grid stays on grid', () {
      expect(snapValue(40, 20), 40.0);
    });
  });
}
