import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FlipUtils.flipHorizontal', () {
    test('mirrors single element around its own center (no-op for position)', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 50,
        width: 80,
        height: 40,
      );
      final result = FlipUtils.flipHorizontal([rect]);
      expect(result.length, 1);
      // Single element: center stays the same
      expect(result.first.x, 100);
      expect(result.first.y, 50);
    });

    test('mirrors two elements horizontally', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 150,
        y: 0,
        width: 50,
        height: 50,
      );
      final result = FlipUtils.flipHorizontal([r1, r2]);
      expect(result.length, 2);
      // r1 was at left (0), should now be at right (150)
      expect(result[0].x, 150);
      // r2 was at right (150), should now be at left (0)
      expect(result[1].x, 0);
    });

    test('negates angle on flip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        angle: math.pi / 4,
      );
      final result = FlipUtils.flipHorizontal([rect]);
      expect(result.first.angle, -math.pi / 4);
    });

    test('mirrors line points', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
      );
      final result = FlipUtils.flipHorizontal([line]);
      final flippedLine = result.first as LineElement;
      // Points mirrored: x becomes width - x
      expect(flippedLine.points[0].x, 100);
      expect(flippedLine.points[0].y, 0);
      expect(flippedLine.points[1].x, 0);
      expect(flippedLine.points[1].y, 50);
    });

    test('swaps arrowheads on horizontal flip', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.arrow,
      );
      final result = FlipUtils.flipHorizontal([arrow]);
      final flipped = result.first as ArrowElement;
      expect(flipped.startArrowhead, Arrowhead.arrow);
      expect(flipped.endArrowhead, Arrowhead.dot);
    });

    test('handles arrow with null arrowheads', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
        startArrowhead: null,
        endArrowhead: Arrowhead.arrow,
      );
      final result = FlipUtils.flipHorizontal([arrow]);
      final flipped = result.first as ArrowElement;
      expect(flipped.startArrowhead, Arrowhead.arrow);
      expect(flipped.endArrowhead, isNull);
    });

    test('mirrors freedraw points', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(10, 20), const Point(90, 30)],
      );
      final result = FlipUtils.flipHorizontal([freedraw]);
      final flipped = result.first as FreedrawElement;
      expect(flipped.points[0].x, 90); // 100 - 10
      expect(flipped.points[0].y, 20);
      expect(flipped.points[1].x, 10); // 100 - 90
      expect(flipped.points[1].y, 30);
    });

    test('returns empty for empty input', () {
      expect(FlipUtils.flipHorizontal([]), isEmpty);
    });
  });

  group('FlipUtils.flipVertical', () {
    test('mirrors two elements vertically', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 0,
        y: 150,
        width: 50,
        height: 50,
      );
      final result = FlipUtils.flipVertical([r1, r2]);
      expect(result.length, 2);
      expect(result[0].y, 150);
      expect(result[1].y, 0);
    });

    test('mirrors line points vertically', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
      );
      final result = FlipUtils.flipVertical([line]);
      final flippedLine = result.first as LineElement;
      expect(flippedLine.points[0].x, 0);
      expect(flippedLine.points[0].y, 50);
      expect(flippedLine.points[1].x, 100);
      expect(flippedLine.points[1].y, 0);
    });

    test('does not swap arrowheads on vertical flip', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.arrow,
      );
      final result = FlipUtils.flipVertical([arrow]);
      final flipped = result.first as ArrowElement;
      expect(flipped.startArrowhead, Arrowhead.dot);
      expect(flipped.endArrowhead, Arrowhead.arrow);
    });

    test('negates angle on vertical flip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        angle: 0.5,
      );
      final result = FlipUtils.flipVertical([rect]);
      expect(result.first.angle, -0.5);
    });

    test('returns empty for empty input', () {
      expect(FlipUtils.flipVertical([]), isEmpty);
    });
  });
}
