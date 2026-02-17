import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/rough/arrowhead_renderer.dart';

void main() {
  group('ArrowheadRenderer.directionAngle', () {
    test('horizontal rightward line', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(0, 0), const Point(100, 0)],
        isStart: false,
      );
      expect(angle, closeTo(0.0, 0.01));
    });

    test('horizontal leftward line', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(100, 0), const Point(0, 0)],
        isStart: false,
      );
      expect(angle, closeTo(math.pi, 0.01));
    });

    test('vertical downward line', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(0, 0), const Point(0, 100)],
        isStart: false,
      );
      expect(angle, closeTo(math.pi / 2, 0.01));
    });

    test('diagonal line at 45 degrees', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(0, 0), const Point(100, 100)],
        isStart: false,
      );
      expect(angle, closeTo(math.pi / 4, 0.01));
    });

    test('start direction uses first two points', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
        isStart: true,
      );
      // Direction from point[1] to point[0] = leftward = pi
      expect(angle, closeTo(math.pi, 0.01));
    });

    test('end direction uses last two points of multi-segment', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
        isStart: false,
      );
      // Direction from point[1] to point[2] = downward = pi/2
      expect(angle, closeTo(math.pi / 2, 0.01));
    });
  });

  group('ArrowheadRenderer.buildPath', () {
    const tip = Point(100, 50);
    const strokeWidth = 2.0;

    test('arrow type produces an open path (two line segments)', () {
      final path = ArrowheadRenderer.buildPath(
        Arrowhead.arrow,
        tip,
        0.0, // rightward
        strokeWidth,
      );
      // Should have path metrics (non-empty)
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('triangle type produces a closed filled path', () {
      final path = ArrowheadRenderer.buildPath(
        Arrowhead.triangle,
        tip,
        0.0,
        strokeWidth,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('bar type produces a perpendicular line', () {
      final path = ArrowheadRenderer.buildPath(
        Arrowhead.bar,
        tip,
        0.0,
        strokeWidth,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('dot type produces a circle-like path', () {
      final path = ArrowheadRenderer.buildPath(
        Arrowhead.dot,
        tip,
        0.0,
        strokeWidth,
      );
      final bounds = path.getBounds();
      // Circle should be roughly square bounds
      expect((bounds.width - bounds.height).abs(), lessThan(1.0));
    });

    test('arrowhead size scales with stroke width', () {
      final smallPath = ArrowheadRenderer.buildPath(
        Arrowhead.arrow,
        tip,
        0.0,
        1.0,
      );
      final largePath = ArrowheadRenderer.buildPath(
        Arrowhead.arrow,
        tip,
        0.0,
        4.0,
      );
      final smallBounds = smallPath.getBounds();
      final largeBounds = largePath.getBounds();
      expect(largeBounds.width, greaterThan(smallBounds.width));
    });

    test('arrow at different angles rotates correctly', () {
      final rightPath = ArrowheadRenderer.buildPath(
        Arrowhead.arrow,
        tip,
        0.0,
        strokeWidth,
      );
      final downPath = ArrowheadRenderer.buildPath(
        Arrowhead.arrow,
        tip,
        math.pi / 2,
        strokeWidth,
      );
      // The bounds should differ in aspect ratio
      final rightBounds = rightPath.getBounds();
      final downBounds = downPath.getBounds();
      // Right-pointing is wider, down-pointing is taller
      expect(rightBounds.width, greaterThan(rightBounds.height));
      expect(downBounds.height, greaterThan(downBounds.width));
    });
  });

  group('ArrowheadRenderer edge cases', () {
    test('single point returns zero angle', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(50, 50)],
        isStart: false,
      );
      expect(angle, 0.0);
    });

    test('two identical points returns zero angle', () {
      final angle = ArrowheadRenderer.directionAngle(
        [const Point(50, 50), const Point(50, 50)],
        isStart: false,
      );
      expect(angle, 0.0);
    });
  });
}
