import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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

    test('draws point handles when pointHandles provided', () {
      final (recorder, canvas) = _makeCanvas();

      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
        pointHandles: [Point(10, 20), Point(200, 300)],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws only point handles when showBoundingBox is false', () {
      final (recorder, canvas) = _makeCanvas();
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 200, height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      final overlay = SelectionOverlay.fromElements([line]);
      // 2-point line should have showBoundingBox=false
      expect(overlay!.showBoundingBox, isFalse);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
        pointHandles: const [Point(0, 0), Point(200, 0)],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws point handles with rotated selection', () {
      final (recorder, canvas) = _makeCanvas();
      final line = LineElement(
        id: const ElementId('l1'),
        x: 100, y: 100, width: 200, height: 0,
        angle: 0.5,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      final overlay = SelectionOverlay.fromElements([line]);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        selection: overlay,
        pointHandles: const [Point(100, 100), Point(300, 100)],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('shouldRepaint returns true when pointHandles change', () {
      const p1 = InteractiveCanvasPainter(
        viewport: ViewportState(),
        pointHandles: [Point(0, 0), Point(100, 100)],
      );
      const p2 = InteractiveCanvasPainter(
        viewport: ViewportState(),
        pointHandles: [Point(0, 0), Point(200, 200)],
      );

      expect(p2.shouldRepaint(p1), isTrue);
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

    test('draws binding indicator when bindTargetBounds provided', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        bindTargetBounds: Bounds.fromLTWH(100, 100, 200, 150),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('does not render binding indicator when null', () {
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

    test('shouldRepaint returns true when bindTargetBounds changes', () {
      final p1 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        bindTargetBounds: Bounds.fromLTWH(0, 0, 100, 100),
      );
      final p2 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        bindTargetBounds: Bounds.fromLTWH(50, 50, 100, 100),
      );

      expect(p2.shouldRepaint(p1), isTrue);
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

    test('accepts InteractionMode and defaults to pointer', () {
      const painter = InteractiveCanvasPainter(
        viewport: ViewportState(),
      );
      expect(painter.interactionMode, InteractionMode.pointer);
    });

    test('paints with touch InteractionMode', () {
      final (recorder, canvas) = _makeCanvas();
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 100, y: 100, width: 200, height: 150,
      );
      final overlay = SelectionOverlay.fromElements([element],
          mode: InteractionMode.touch);

      final painter = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        interactionMode: InteractionMode.touch,
        selection: overlay,
        pointHandles: const [Point(100, 100), Point(300, 250)],
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('draws multi-select with per-element outlines and dashed box', () {
      final (recorder, canvas) = _makeCanvas();
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 50, y: 50, width: 100, height: 80,
      );
      final e2 = EllipseElement(
        id: const ElementId('e1'),
        x: 200, y: 100, width: 150, height: 120,
      );
      final overlay = SelectionOverlay.fromElements([e1, e2]);

      // Verify multi-select has elementBounds populated
      expect(overlay!.elementBounds, hasLength(2));

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

    test('draws multi-select with rotated elements', () {
      final (recorder, canvas) = _makeCanvas();
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 50, y: 50, width: 100, height: 80,
        angle: 0.5,
      );
      final e2 = DiamondElement(
        id: const ElementId('d1'),
        x: 200, y: 100, width: 150, height: 120,
        angle: 1.2,
      );
      final overlay = SelectionOverlay.fromElements([e1, e2]);

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

    test('shouldRepaint returns true when interactionMode changes', () {
      final overlay = SelectionOverlay.fromElements([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 100,
        ),
      ]);

      final p1 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        interactionMode: InteractionMode.pointer,
        selection: overlay,
      );
      final p2 = InteractiveCanvasPainter(
        viewport: const ViewportState(),
        interactionMode: InteractionMode.touch,
        selection: overlay,
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });
  });
}
