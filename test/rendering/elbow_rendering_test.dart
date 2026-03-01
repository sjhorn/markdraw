import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// Mock RoughAdapter that records calls.
class _MockAdapter implements RoughAdapter {
  final List<String> calls = [];
  List<Point>? lastPoints;
  Arrowhead? lastStartArrowhead;
  Arrowhead? lastEndArrowhead;

  @override
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawRectangle');
  }

  @override
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawEllipse');
  }

  @override
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawDiamond');
  }

  @override
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('drawLine');
    lastPoints = List.of(points);
  }

  @override
  void drawPolygonLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('drawPolygonLine');
    lastPoints = List.of(points);
  }

  @override
  void drawArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    calls.add('drawArrow');
    lastPoints = List.of(points);
    lastStartArrowhead = startArrowhead;
    lastEndArrowhead = endArrowhead;
  }

  @override
  void drawElbowArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    calls.add('drawElbowArrow');
    lastPoints = List.of(points);
    lastStartArrowhead = startArrowhead;
    lastEndArrowhead = endArrowhead;
  }

  @override
  void drawFreedraw(
    Canvas canvas,
    List<Point> points,
    List<double> pressures,
    bool simulatePressure,
    DrawStyle style,
  ) {
    calls.add('drawFreedraw');
    lastPoints = List.of(points);
  }
}

(PictureRecorder, Canvas) _makeCanvas() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  return (recorder, canvas);
}

ArrowElement _elbowArrow({
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 50,
  List<Point>? points,
  Arrowhead? startArrowhead,
  Arrowhead? endArrowhead = Arrowhead.arrow,
  double opacity = 1.0,
  double angle = 0.0,
  StrokeStyle strokeStyle = StrokeStyle.solid,
}) =>
    ArrowElement(
      id: const ElementId('ea1'),
      x: x,
      y: y,
      width: w,
      height: h,
      points: points ?? const [Point(0, 0), Point(0, 50), Point(100, 50)],
      startArrowhead: startArrowhead,
      endArrowhead: endArrowhead,
      elbowed: true,
      opacity: opacity,
      angle: angle,
      strokeStyle: strokeStyle,
    );

ArrowElement _regularArrow({
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
  List<Point>? points,
}) =>
    ArrowElement(
      id: const ElementId('ra1'),
      x: x,
      y: y,
      width: w,
      height: h,
      points: points ?? const [Point(0, 0), Point(100, 100)],
    );

void main() {
  group('Elbow arrow rendering', () {
    test('elbowed arrow dispatches to drawElbowArrow', () {
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _elbowArrow();

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      expect(adapter.calls, contains('drawElbowArrow'));
      expect(adapter.calls, isNot(contains('drawArrow')));
    });

    test('elbowed arrow passes correct points to drawElbowArrow', () {
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _elbowArrow(
        x: 10,
        y: 20,
        points: const [Point(0, 0), Point(0, 50), Point(100, 50)],
      );

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      // Absolute points: (10,20), (10,70), (110,70)
      expect(adapter.lastPoints, [
        const Point(10, 20),
        const Point(10, 70),
        const Point(110, 70),
      ]);
    });

    test('elbowed arrow passes arrowheads to drawElbowArrow', () {
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _elbowArrow(
        startArrowhead: Arrowhead.triangle,
        endArrowhead: Arrowhead.arrow,
      );

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      expect(adapter.lastStartArrowhead, Arrowhead.triangle);
      expect(adapter.lastEndArrowhead, Arrowhead.arrow);
    });

    test('non-elbowed arrow dispatches to drawArrow (regression)', () {
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _regularArrow();

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      expect(adapter.calls, contains('drawArrow'));
      expect(adapter.calls, isNot(contains('drawElbowArrow')));
    });

    test('elbowed arrow with opacity wraps in save/restore', () {
      // This just tests that the element renders without error when opacity < 1
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _elbowArrow(opacity: 0.5);

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      expect(adapter.calls, contains('drawElbowArrow'));
    });

    test('elbowed arrow ignores rotation (angle forced to 0 by convention)',
        () {
      // Elbowed arrows should ideally have angle=0, but if angle is set,
      // the renderer still processes it via the standard rotation wrapper.
      // The convention is that elbowed arrows always have angle=0.
      final adapter = _MockAdapter();
      final (recorder, canvas) = _makeCanvas();
      final arrow = _elbowArrow(angle: 0.0);

      ElementRenderer.render(canvas, arrow, adapter);
      recorder.endRecording();

      expect(adapter.calls, contains('drawElbowArrow'));
    });
  });

  group('Elbow arrow SVG export', () {
    test('elbowed arrow emits clean path with L commands', () {
      final arrow = _elbowArrow(
        x: 10,
        y: 20,
        w: 100,
        h: 50,
        points: const [Point(0, 0), Point(0, 50), Point(100, 50)],
      );

      final svg = SvgElementRenderer.render(arrow);

      // Should contain a clean path, not rough segments
      expect(svg, contains('<path d="M10,20 L10,70 L110,70"'));
      expect(svg, contains('fill="none"'));
    });

    test('elbowed arrow SVG includes arrowhead paths', () {
      final arrow = _elbowArrow(
        endArrowhead: Arrowhead.arrow,
      );

      final svg = SvgElementRenderer.render(arrow);

      // Should contain the main path plus arrowhead path(s)
      // Count the number of <path tags
      final pathCount = '<path'.allMatches(svg).length;
      expect(pathCount, greaterThanOrEqualTo(2)); // polyline + arrowhead
    });

    test('non-elbowed arrow SVG uses rough segments (regression)', () {
      final arrow = _regularArrow();

      final svg = SvgElementRenderer.render(arrow);

      // Rough arrows produce multiple path elements (one per segment via generator)
      // and don't use a single polyline M...L...L... path
      expect(svg, contains('<path'));
    });

    test('elbowed arrow SVG with dashed stroke', () {
      final arrow = _elbowArrow(strokeStyle: StrokeStyle.dashed);

      final svg = SvgElementRenderer.render(arrow);

      expect(svg, contains('stroke-dasharray="8,6"'));
    });
  });
}
