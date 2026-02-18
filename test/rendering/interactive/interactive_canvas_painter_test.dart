import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/interactive/interactive_canvas_painter.dart';
import 'package:markdraw/src/rendering/interactive/selection_overlay.dart';
import 'package:markdraw/src/rendering/interactive/snap_line.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

(PictureRecorder, Canvas) _makeCanvas() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  return (recorder, canvas);
}

void main() {
  group('InteractiveCanvasPainter', () {
    test('paints nothing when all inputs are null/empty', () {
      final (recorder, canvas) = _makeCanvas();

      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws selection box when selection is provided', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 100, y: 100, width: 200, height: 150,
      );
      final overlay = SelectionOverlay.fromElements([element]);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws hover highlight when hoveredBounds is provided', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        hoveredBounds: Bounds.fromLTWH(50, 50, 200, 100),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws marquee rectangle when marqueeRect is provided', () {
      final (recorder, canvas) = _makeCanvas();

      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
        marqueeRect: Rect.fromLTWH(10, 20, 300, 200),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws snap lines when provided', () {
      final (recorder, canvas) = _makeCanvas();

      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
        snapLines: [
          SnapLine(
            orientation: SnapLineOrientation.horizontal,
            position: 100,
            start: 0,
            end: 800,
          ),
          SnapLine(
            orientation: SnapLineOrientation.vertical,
            position: 200,
            start: 0,
            end: 600,
          ),
        ],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws creation preview line when creationPoints provided', () {
      final (recorder, canvas) = _makeCanvas();

      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
        creationPoints: [Point(10, 20), Point(200, 300)],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws creation preview shape when creationBounds provided', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        creationBounds: Bounds.fromLTWH(50, 50, 200, 150),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('applies viewport transform', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 100, y: 100, width: 200, height: 150,
      );
      final overlay = SelectionOverlay.fromElements([element]);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(offset: Offset(50, 25), zoom: 1.5),
        selection: overlay,
        hoveredBounds: Bounds.fromLTWH(50, 50, 100, 80),
        snapLines: const [
          SnapLine(
            orientation: SnapLineOrientation.horizontal,
            position: 100,
            start: 0,
            end: 400,
          ),
        ],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('shouldRepaint returns true when selection changes', () {
      final overlay1 = SelectionOverlay.fromElements([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 100,
        ),
      ]);
      final overlay2 = SelectionOverlay.fromElements([
        RectangleElement(
          id: const ElementId('r2'),
          x: 200, y: 200, width: 50, height: 50,
        ),
      ]);

      final p1 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay1,
      );
      final p2 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay2,
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns true when viewport changes', () {
      const p1 = InteractiveCanvasPainter(
        viewport: ViewportState(),
      );
      const p2 = InteractiveCanvasPainter(
        viewport: ViewportState(zoom: 2.0),
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns true when hoveredBounds changes', () {
      final p1 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        hoveredBounds: Bounds.fromLTWH(0, 0, 100, 100),
      );
      final p2 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        hoveredBounds: Bounds.fromLTWH(50, 50, 100, 100),
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns true when snapLines change', () {
      const p1 = InteractiveCanvasPainter(
        viewport: ViewportState(),
      );
      const p2 = InteractiveCanvasPainter(
        viewport: ViewportState(),
        snapLines: [
          SnapLine(
            orientation: SnapLineOrientation.horizontal,
            position: 100,
            start: 0,
            end: 800,
          ),
        ],
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns false when identical inputs', () {
      final overlay = SelectionOverlay.fromElements([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 100,
        ),
      ]);
      final bounds = Bounds.fromLTWH(50, 50, 100, 80);
      const snapLines = [
        SnapLine(
          orientation: SnapLineOrientation.horizontal,
          position: 100,
          start: 0,
          end: 800,
        ),
      ];

      final p1 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
        hoveredBounds: bounds,
        snapLines: snapLines,
      );
      final p2 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
        hoveredBounds: bounds,
        snapLines: snapLines,
      );

      expect(p2.shouldRepaint(p1), isFalse);
    });

    test('paints all overlay types simultaneously', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 100, y: 100, width: 200, height: 150,
      );
      final overlay = SelectionOverlay.fromElements([element]);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
        hoveredBounds: Bounds.fromLTWH(400, 100, 100, 80),
        marqueeRect: const Rect.fromLTWH(10, 10, 50, 50),
        snapLines: const [
          SnapLine(
            orientation: SnapLineOrientation.horizontal,
            position: 150,
            start: 0,
            end: 800,
          ),
        ],
        creationPoints: const [Point(500, 300), Point(600, 400)],
        creationBounds: Bounds.fromLTWH(200, 400, 100, 80),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });
  });
}
