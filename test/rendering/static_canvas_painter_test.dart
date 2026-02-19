import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart' as core
    show TextElement;
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/rough/draw_style.dart';
import 'package:markdraw/src/rendering/rough/rough_adapter.dart';
import 'package:markdraw/src/rendering/static_canvas_painter.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

/// Mock adapter that tracks call order.
class MockRoughAdapter implements RoughAdapter {
  final List<String> calls = [];

  @override
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('rectangle');
  }

  @override
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('ellipse');
  }

  @override
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('diamond');
  }

  @override
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('line');
  }

  @override
  void drawArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    calls.add('arrow');
  }

  @override
  void drawFreedraw(
    Canvas canvas,
    List<Point> points,
    List<double> pressures,
    bool simulatePressure,
    DrawStyle style,
  ) {
    calls.add('freedraw');
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

  group('StaticCanvasPainter', () {
    test('paints all active elements in order', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        index: 'a0',
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 0,
        width: 100,
        height: 80,
        index: 'a1',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      expect(adapter.calls, ['rectangle', 'ellipse']);
    });

    test('skips isDeleted elements', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 0,
        width: 100,
        height: 80,
        isDeleted: true,
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      expect(adapter.calls, ['rectangle']);
    });

    test('applies viewport offset (pan)', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(offset: Offset(50, 50)),
      );

      // Should not throw — viewport transform is applied
      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
      expect(adapter.calls, ['rectangle']);
    });

    test('applies viewport zoom (scale)', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(zoom: 2.0),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
      expect(adapter.calls, ['rectangle']);
    });

    test('shouldRepaint returns true when scene changes', () {
      var scene1 = Scene();
      scene1 = scene1.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));

      var scene2 = Scene();
      scene2 = scene2.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));

      final painter1 = StaticCanvasPainter(
        scene: scene1,
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: scene2,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when viewport changes', () {
      final scene = Scene();
      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(zoom: 2.0),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when identical', () {
      final scene = Scene();
      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('empty scene paints nothing', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      expect(adapter.calls, isEmpty);
    });

    test('bound text (containerId != null) skipped at top level', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 200,
        height: 100,
      ));
      scene = scene.addElement(core.TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 30,
        width: 100,
        height: 40,
        text: 'Bound text',
        containerId: 'r1',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Only rectangle should be drawn; bound text is skipped
      expect(adapter.calls, ['rectangle']);
    });

    test('paints all 7 element types', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 80,
        index: 'a0',
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 120, y: 0, width: 100, height: 80,
        index: 'a1',
      ));
      scene = scene.addElement(DiamondElement(
        id: const ElementId('d1'),
        x: 240, y: 0, width: 100, height: 80,
        index: 'a2',
      ));
      scene = scene.addElement(LineElement(
        id: const ElementId('l1'),
        x: 0, y: 120, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        index: 'a3',
      ));
      scene = scene.addElement(ArrowElement(
        id: const ElementId('a1'),
        x: 120, y: 120, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endArrowhead: Arrowhead.arrow,
        index: 'a4',
      ));
      scene = scene.addElement(FreedrawElement(
        id: const ElementId('f1'),
        x: 0, y: 200, width: 100, height: 50,
        points: [const Point(0, 0), const Point(50, 25), const Point(100, 0)],
        index: 'a5',
      ));
      scene = scene.addElement(core.TextElement(
        id: const ElementId('t1'),
        x: 120, y: 200, width: 200, height: 40,
        text: 'Hello world',
        index: 'a6',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Text doesn't go through adapter, so 6 adapter calls
      expect(adapter.calls, [
        'rectangle',
        'ellipse',
        'diamond',
        'line',
        'arrow',
        'freedraw',
      ]);
    });

    test('respects fractional index ordering', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      // Add in reverse index order
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200, y: 0, width: 100, height: 80,
        index: 'a2',
      ));
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 80,
        index: 'a0',
      ));
      scene = scene.addElement(DiamondElement(
        id: const ElementId('d1'),
        x: 100, y: 0, width: 100, height: 80,
        index: 'a1',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Should be in index order: rectangle(a0), diamond(a1), ellipse(a2)
      expect(adapter.calls, ['rectangle', 'diamond', 'ellipse']);
    });

    test('viewport offset and zoom combined', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(offset: Offset(50, 25), zoom: 1.5),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
      expect(adapter.calls, ['rectangle']);
    });

    test('shouldRepaint returns true when adapter changes', () {
      final scene = Scene();
      final adapter2 = MockRoughAdapter();

      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter2,
        viewport: const ViewportState(),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('off-screen elements not painted (viewport culling)', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      // On-screen element
      scene = scene.addElement(RectangleElement(
        id: const ElementId('visible'),
        x: 100, y: 100, width: 200, height: 100,
      ));
      // Far off-screen element
      scene = scene.addElement(EllipseElement(
        id: const ElementId('offscreen'),
        x: 5000, y: 5000, width: 100, height: 100,
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Only the visible element should be painted
      expect(adapter.calls, ['rectangle']);
    });

    test('only visible elements painted when some are off-screen', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        index: 'a0',
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: -2000, y: -2000, width: 50, height: 50,
        index: 'a1',
      ));
      scene = scene.addElement(DiamondElement(
        id: const ElementId('d1'),
        x: 300, y: 200, width: 80, height: 80,
        index: 'a2',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Ellipse is off-screen, should be culled
      expect(adapter.calls, ['rectangle', 'diamond']);
    });

    test('panned viewport culls elements no longer visible', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 2000, y: 2000, width: 100, height: 100,
      ));

      // Pan to show the ellipse area, not the rectangle
      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(offset: Offset(1800, 1800)),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Rectangle at (0,0) is off-screen when viewport offset is (1800,1800)
      // Ellipse at (2000,2000) is visible
      expect(adapter.calls, ['ellipse']);
    });
  });
}
