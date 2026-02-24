import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart' as core;
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart' as core
    show TextElement;
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/element_renderer.dart';
import 'package:markdraw/src/rendering/rough/draw_style.dart';
import 'package:markdraw/src/rendering/rough/rough_adapter.dart';

/// A mock RoughAdapter that records which methods were called and
/// captures the arguments for verification.
class MockRoughAdapter implements RoughAdapter {
  final List<String> calls = [];
  Bounds? lastBounds;
  List<Point>? lastPoints;

  @override
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawRectangle');
    lastBounds = bounds;
  }

  @override
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawEllipse');
    lastBounds = bounds;
  }

  @override
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('drawDiamond');
    lastBounds = bounds;
  }

  @override
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('drawLine');
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

void main() {
  late MockRoughAdapter adapter;

  setUp(() {
    adapter = MockRoughAdapter();
  });

  group('ElementRenderer', () {
    test('dispatches rectangle to drawRectangle', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: ElementId.generate(),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawRectangle']);
    });

    test('dispatches ellipse to drawEllipse', () {
      final (recorder, canvas) = _makeCanvas();
      final element = EllipseElement(
        id: ElementId.generate(),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawEllipse']);
    });

    test('dispatches diamond to drawDiamond', () {
      final (recorder, canvas) = _makeCanvas();
      final element = DiamondElement(
        id: ElementId.generate(),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawDiamond']);
    });

    test('dispatches line to drawLine', () {
      final (recorder, canvas) = _makeCanvas();
      final element = LineElement(
        id: ElementId.generate(),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawLine']);
    });

    test('dispatches arrow to drawArrow', () {
      final (recorder, canvas) = _makeCanvas();
      final element = ArrowElement(
        id: ElementId.generate(),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endArrowhead: Arrowhead.arrow,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawArrow']);
    });

    test('dispatches freedraw to drawFreedraw', () {
      final (recorder, canvas) = _makeCanvas();
      final element = FreedrawElement(
        id: ElementId.generate(),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawFreedraw']);
    });

    test('dispatches text to TextRenderer (not adapter)', () {
      final (recorder, canvas) = _makeCanvas();
      final element = core.TextElement(
        id: ElementId.generate(),
        x: 10,
        y: 20,
        width: 200,
        height: 40,
        text: 'Hello',
      );

      // Should not throw and should NOT call any adapter method
      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, isEmpty);
    });

    test('element with angle applies canvas rotation', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: ElementId.generate(),
        x: 50,
        y: 50,
        width: 100,
        height: 80,
        angle: math.pi / 4, // 45 degrees
      );

      // Should not throw — rotation is applied via canvas.save/rotate/restore
      expect(
        () => ElementRenderer.render(canvas, element, adapter),
        returnsNormally,
      );
      recorder.endRecording();

      expect(adapter.calls, ['drawRectangle']);
    });

    test('unknown element type does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final element = core.Element(
        id: ElementId.generate(),
        type: 'unknown_type',
        x: 10,
        y: 20,
        width: 100,
        height: 80,
      );

      expect(
        () => ElementRenderer.render(canvas, element, adapter),
        returnsNormally,
      );
      recorder.endRecording();

      expect(adapter.calls, isEmpty);
    });

    test('element with zero angle skips rotation', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: ElementId.generate(),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        angle: 0.0,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawRectangle']);
    });

    test('rectangle bounds include element position', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: ElementId.generate(),
        x: 100,
        y: 200,
        width: 50,
        height: 30,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.lastBounds!.left, 100);
      expect(adapter.lastBounds!.top, 200);
      expect(adapter.lastBounds!.size.width, 50);
      expect(adapter.lastBounds!.size.height, 30);
    });
  });

  group('Line/arrow/freedraw position', () {
    test('line at non-zero origin renders with offset points', () {
      final (recorder, canvas) = _makeCanvas();
      final element = LineElement(
        id: ElementId.generate(),
        x: 100,
        y: 200,
        width: 50,
        height: 50,
        points: [const Point(0, 0), const Point(50, 50)],
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawLine']);
      // Points passed to adapter should be offset by element position
      expect(adapter.lastPoints![0], const Point(100, 200));
      expect(adapter.lastPoints![1], const Point(150, 250));
    });

    test('arrow at non-zero origin renders with offset points', () {
      final (recorder, canvas) = _makeCanvas();
      final element = ArrowElement(
        id: ElementId.generate(),
        x: 100,
        y: 200,
        width: 80,
        height: 0,
        points: [const Point(0, 0), const Point(80, 0)],
        endArrowhead: Arrowhead.arrow,
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawArrow']);
      expect(adapter.lastPoints![0], const Point(100, 200));
      expect(adapter.lastPoints![1], const Point(180, 200));
    });

    test('freedraw at non-zero origin renders with offset points', () {
      final (recorder, canvas) = _makeCanvas();
      final element = FreedrawElement(
        id: ElementId.generate(),
        x: 50,
        y: 75,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(50, 50),
          const Point(100, 0),
        ],
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.calls, ['drawFreedraw']);
      expect(adapter.lastPoints![0], const Point(50, 75));
      expect(adapter.lastPoints![1], const Point(100, 125));
      expect(adapter.lastPoints![2], const Point(150, 75));
    });

    test('line at origin renders points unchanged', () {
      final (recorder, canvas) = _makeCanvas();
      final element = LineElement(
        id: ElementId.generate(),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
      );

      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();

      expect(adapter.lastPoints![0], const Point(0, 0));
      expect(adapter.lastPoints![1], const Point(100, 100));
    });
  });
}
