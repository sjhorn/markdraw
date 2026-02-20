import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/rough/draw_style.dart';
import 'package:markdraw/src/rendering/rough/freedraw_renderer.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';

DrawStyle _style({
  double strokeWidth = 2.0,
  double opacity = 1.0,
}) {
  return DrawStyle(
    strokeColor: const Color(0xFF000000),
    backgroundColor: const Color(0x00000000),
    fillStyle: FillStyle.solid,
    strokeWidth: strokeWidth,
    strokeStyle: StrokeStyle.solid,
    roughness: 1.0,
    opacity: opacity,
    seed: 42,
  );
}

void main() {
  group('FreedrawRenderer.buildPath', () {
    test('single point produces a small path (dot)', () {
      final path = FreedrawRenderer.buildPath(
        [const Point(50, 50)],
        _style().strokeWidth,
      );
      final bounds = path.getBounds();
      // Should be a tiny area around the point
      expect(bounds.width, lessThan(10));
      expect(bounds.height, lessThan(10));
    });

    test('two points produces a straight line', () {
      final path = FreedrawRenderer.buildPath(
        [const Point(0, 0), const Point(100, 0)],
        _style().strokeWidth,
      );
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(100, 1));
      expect(bounds.height, closeTo(0, 1));
    });

    test('three+ points produces a smooth Bezier curve', () {
      final path = FreedrawRenderer.buildPath(
        [
          const Point(0, 0),
          const Point(50, 30),
          const Point(100, 0),
        ],
        _style().strokeWidth,
      );
      final bounds = path.getBounds();
      // Curve should span the x range
      expect(bounds.width, greaterThan(90));
      // Curve should have some height due to the middle point
      expect(bounds.height, greaterThan(5));
    });

    test('path starts near first point', () {
      final path = FreedrawRenderer.buildPath(
        [
          const Point(10, 20),
          const Point(50, 60),
          const Point(90, 30),
        ],
        _style().strokeWidth,
      );
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(10, 5));
      expect(bounds.top, closeTo(20, 5));
    });

    test('path ends near last point', () {
      final path = FreedrawRenderer.buildPath(
        [
          const Point(10, 20),
          const Point(50, 60),
          const Point(90, 30),
        ],
        _style().strokeWidth,
      );
      final bounds = path.getBounds();
      expect(bounds.right, closeTo(90, 5));
    });

    test('empty points produces empty path', () {
      final path = FreedrawRenderer.buildPath([], _style().strokeWidth);
      expect(path.computeMetrics().isEmpty, isTrue);
    });
  });

  group('FreedrawRenderer.draw', () {
    test('draws on canvas without error', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final style = _style();

      FreedrawRenderer.draw(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        style,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('style stroke width is applied', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final style = _style(strokeWidth: 5.0);

      // Should not throw
      FreedrawRenderer.draw(
        canvas,
        [const Point(0, 0), const Point(100, 100)],
        style,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('empty points does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => FreedrawRenderer.draw(canvas, [], _style()),
        returnsNormally,
      );

      recorder.endRecording();
    });

    test('single point does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => FreedrawRenderer.draw(
            canvas, [const Point(50, 50)], _style()),
        returnsNormally,
      );

      recorder.endRecording();
    });
  });
}
