import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/math/point.dart';

void main() {
  group('FreedrawElement', () {
    FreedrawElement createFreedraw({
      List<Point> points = const [Point(0, 0), Point(10, 5), Point(20, 10)],
      List<double> pressures = const [0.5, 0.7, 0.9],
      bool simulatePressure = false,
    }) {
      return FreedrawElement(
        id: const ElementId('fd-1'),
        x: 0.0,
        y: 0.0,
        width: 20.0,
        height: 10.0,
        points: points,
        pressures: pressures,
        simulatePressure: simulatePressure,
      );
    }

    test('constructs with type freedraw', () {
      final fd = createFreedraw();
      expect(fd.type, 'freedraw');
    });

    test('stores points and pressures', () {
      final fd = createFreedraw();
      expect(fd.points.length, 3);
      expect(fd.pressures.length, 3);
      expect(fd.points[0], const Point(0, 0));
      expect(fd.pressures[2], 0.9);
    });

    test('simulatePressure defaults to false', () {
      final fd = createFreedraw();
      expect(fd.simulatePressure, false);
    });

    test('copyWith preserves freedraw properties', () {
      final fd = createFreedraw();
      final modified = fd.copyWith(x: 50.0);
      expect(modified.points.length, 3);
      expect(modified.x, 50.0);
    });

    test('copyWithFreedraw changes freedraw-specific properties', () {
      final fd = createFreedraw();
      final modified = fd.copyWithFreedraw(
        points: const [Point(0, 0), Point(5, 5)],
        simulatePressure: true,
      );
      expect(modified.points.length, 2);
      expect(modified.simulatePressure, true);
    });

    test('bumpVersion returns FreedrawElement', () {
      final fd = createFreedraw();
      expect(fd.bumpVersion(), isA<FreedrawElement>());
    });
  });
}
