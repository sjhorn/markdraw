import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ArrowElement _arrow({
  double x = 0,
  double y = 0,
  double width = 200,
  double height = 0,
  required List<Point> points,
}) {
  return ArrowElement(
    id: const ElementId('a1'),
    x: x,
    y: y,
    width: width,
    height: height,
    points: points,
  );
}

void main() {
  group('ArrowLabelUtils', () {
    group('computeArrowMidpoint', () {
      test('two-point arrow at geometric center', () {
        final arrow = _arrow(
          x: 0, y: 0, width: 200, height: 0,
          points: [const Point(0, 0), const Point(200, 0)],
        );
        final mid = ArrowLabelUtils.computeArrowMidpoint(arrow);
        expect(mid.x, closeTo(100, 0.1));
        expect(mid.y, closeTo(0, 0.1));
      });

      test('three-point arrow at half total length', () {
        // L-shaped: (0,0)→(100,0)→(100,100)
        // Total length = 100 + 100 = 200, half = 100
        // Midpoint should be at the corner (100, 0)
        final arrow = _arrow(
          x: 0, y: 0, width: 100, height: 100,
          points: [
            const Point(0, 0),
            const Point(100, 0),
            const Point(100, 100),
          ],
        );
        final mid = ArrowLabelUtils.computeArrowMidpoint(arrow);
        expect(mid.x, closeTo(100, 0.1));
        expect(mid.y, closeTo(0, 0.1));
      });

      test('single-point arrow falls back to bounding box center', () {
        final arrow = _arrow(
          x: 10, y: 20, width: 100, height: 50,
          points: [const Point(0, 0)],
        );
        final mid = ArrowLabelUtils.computeArrowMidpoint(arrow);
        expect(mid.x, closeTo(60, 0.1)); // 10 + 100/2
        expect(mid.y, closeTo(45, 0.1)); // 20 + 50/2
      });
    });

    group('computeLabelPosition', () {
      test('offset above midpoint', () {
        final arrow = _arrow(
          x: 0, y: 100, width: 200, height: 0,
          points: [const Point(0, 0), const Point(200, 0)],
        );
        final mid = ArrowLabelUtils.computeArrowMidpoint(arrow);
        final label = ArrowLabelUtils.computeLabelPosition(arrow);
        expect(label.x, mid.x);
        expect(label.y, lessThan(mid.y));
      });

      test('arrow label position updates when points change', () {
        final arrow1 = _arrow(
          x: 0, y: 0, width: 200, height: 0,
          points: [const Point(0, 0), const Point(200, 0)],
        );
        final arrow2 = _arrow(
          x: 0, y: 0, width: 400, height: 0,
          points: [const Point(0, 0), const Point(400, 0)],
        );
        final label1 = ArrowLabelUtils.computeLabelPosition(arrow1);
        final label2 = ArrowLabelUtils.computeLabelPosition(arrow2);
        expect(label2.x, greaterThan(label1.x));
      });
    });
  });
}
