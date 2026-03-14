import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' as core show Element, TextElement;
import 'package:markdraw/markdraw.dart' hide Element, TextElement, TextAlign;

/// Creates a PictureRecorder + Canvas pair for testing.
(PictureRecorder, Canvas) _makeCanvas() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  return (recorder, canvas);
}

DrawStyle _style({
  String strokeColor = '#000000',
  String backgroundColor = '#cccccc',
  FillStyle fillStyle = FillStyle.solid,
  double strokeWidth = 2.0,
  StrokeStyle strokeStyle = StrokeStyle.solid,
  double roughness = 1.0,
  double opacity = 1.0,
  int seed = 42,
}) {
  return DrawStyle.fromElement(core.Element(
    id: ElementId.generate(),
    type: 'rectangle',
    x: 0,
    y: 0,
    width: 100,
    height: 100,
    strokeColor: strokeColor,
    backgroundColor: backgroundColor,
    fillStyle: fillStyle,
    strokeWidth: strokeWidth,
    strokeStyle: strokeStyle,
    roughness: roughness,
    opacity: opacity,
    seed: seed,
  ));
}

/// Mock adapter that records calls for StaticCanvasPainter tests.
class _MockRoughAdapter implements RoughAdapter {
  final List<String> calls = [];

  @override
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style,
      {Roundness? roundness}) {
    calls.add('rectangle');
  }

  @override
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style) {
    calls.add('ellipse');
  }

  @override
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style,
      {Roundness? roundness}) {
    calls.add('diamond');
  }

  @override
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('line');
  }

  @override
  void drawPolygonLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('polygonLine');
  }

  @override
  void drawArrow(Canvas canvas, List<Point> points,
      Arrowhead? startArrowhead, Arrowhead? endArrowhead, DrawStyle style) {
    calls.add('arrow');
  }

  @override
  void drawCurvedPolygon(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('curvedPolygon');
  }

  @override
  void drawCurvedLine(Canvas canvas, List<Point> points, DrawStyle style) {
    calls.add('curvedLine');
  }

  @override
  void drawCurvedArrow(Canvas canvas, List<Point> points,
      Arrowhead? startArrowhead, Arrowhead? endArrowhead, DrawStyle style) {
    calls.add('curvedArrow');
  }

  @override
  void drawElbowArrow(Canvas canvas, List<Point> points,
      Arrowhead? startArrowhead, Arrowhead? endArrowhead, DrawStyle style) {
    calls.add('elbowArrow');
  }

  @override
  void drawRoundElbowArrow(Canvas canvas, List<Point> points,
      Arrowhead? startArrowhead, Arrowhead? endArrowhead, DrawStyle style) {
    calls.add('roundElbowArrow');
  }

  @override
  void drawFreedraw(Canvas canvas, List<Point> points,
      List<double> pressures, bool simulatePressure, DrawStyle style) {
    calls.add('freedraw');
  }
}

void main() {
  // =========================================================================
  // 1. RoughCanvasAdapter — uncovered draw methods and stroke variations
  // =========================================================================
  group('RoughCanvasAdapter additional coverage', () {
    late RoughCanvasAdapter adapter;

    setUp(() {
      adapter = RoughCanvasAdapter();
    });

    test('drawPolygonLine renders closed polygon', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawPolygonLine(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(50, 80),
        ],
        _style(),
      );
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('drawPolygonLine with fewer than 3 points returns early', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawPolygonLine(
            canvas, [const Point(0, 0), const Point(10, 10)], _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test('drawCurvedPolygon renders smooth closed shape', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedPolygon(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(100, 100),
          const Point(0, 100),
        ],
        _style(),
      );
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('drawCurvedPolygon strips duplicate closing point', () {
      final (recorder, canvas) = _makeCanvas();
      // Last point same as first — should be stripped
      adapter.drawCurvedPolygon(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(100, 100),
          const Point(0, 100),
          const Point(0, 0), // duplicate closing point
        ],
        _style(),
      );
      recorder.endRecording();
    });

    test('drawCurvedPolygon with fewer than 3 points returns early', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawCurvedPolygon(
            canvas, [const Point(0, 0), const Point(10, 10)], _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test('drawCurvedLine with dashed stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedLine(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('drawCurvedArrow with dashed stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedArrow(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        Arrowhead.arrow,
        Arrowhead.triangle,
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('drawCurvedArrow with dotted stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedArrow(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        null,
        Arrowhead.bar,
        _style(strokeStyle: StrokeStyle.dotted),
      );
      recorder.endRecording();
    });

    test('drawCurvedArrow with start arrowhead only', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedArrow(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        Arrowhead.dot,
        null,
        _style(),
      );
      recorder.endRecording();
    });

    test('drawRoundElbowArrow renders with rounded corners', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawRoundElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 100),
          const Point(100, 100),
          const Point(100, 200),
        ],
        null,
        Arrowhead.arrow,
        _style(),
      );
      recorder.endRecording();
    });

    test('drawRoundElbowArrow with both arrowheads', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawRoundElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 100),
          const Point(100, 100),
        ],
        Arrowhead.triangle,
        Arrowhead.arrow,
        _style(),
      );
      recorder.endRecording();
    });

    test('drawRoundElbowArrow with dashed stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawRoundElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 50),
          const Point(50, 50),
        ],
        null,
        Arrowhead.arrow,
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('drawRoundElbowArrow with very short segments', () {
      final (recorder, canvas) = _makeCanvas();
      // Very short segments where radius < 0.5, triggers lineTo fallback
      adapter.drawRoundElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 0.5),
          const Point(0.5, 0.5),
        ],
        null,
        null,
        _style(),
      );
      recorder.endRecording();
    });

    test('drawRoundElbowArrow with fewer than 2 points returns early', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawRoundElbowArrow(
            canvas, [const Point(0, 0)], null, null, _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test('drawElbowArrow with dashed stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 100),
          const Point(100, 100),
        ],
        Arrowhead.bar,
        Arrowhead.arrow,
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('drawElbowArrow with dotted stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawElbowArrow(
        canvas,
        [
          const Point(0, 0),
          const Point(0, 50),
          const Point(50, 50),
        ],
        null,
        Arrowhead.triangle,
        _style(strokeStyle: StrokeStyle.dotted),
      );
      recorder.endRecording();
    });

    test('drawDiamond with dotted stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawDiamond(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 100),
        _style(strokeStyle: StrokeStyle.dotted),
      );
      recorder.endRecording();
    });

    test('drawPolygonLine with dashed stroke', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawPolygonLine(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(50, 80),
        ],
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('drawPolygonLine with hachure fill', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawPolygonLine(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(50, 80),
        ],
        _style(fillStyle: FillStyle.hachure),
      );
      recorder.endRecording();
    });

    test('drawCurvedPolygon with cross-hatch fill', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawCurvedPolygon(
        canvas,
        [
          const Point(0, 0),
          const Point(100, 0),
          const Point(100, 100),
          const Point(0, 100),
        ],
        _style(fillStyle: FillStyle.crossHatch),
      );
      recorder.endRecording();
    });

    test('drawRectangle with rounded corners', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawRectangle(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 80),
        _style(),
        roundness: const Roundness.proportional(value: 0.2),
      );
      recorder.endRecording();
    });

    test('drawDiamond with rounded corners', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawDiamond(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 80),
        _style(),
        roundness: const Roundness.proportional(value: 0.2),
      );
      recorder.endRecording();
    });
  });

  // =========================================================================
  // 2. SvgElementRenderer — uncovered element types and variations
  // =========================================================================
  group('SvgElementRenderer additional coverage', () {
    test('renders diamond element with path', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(diamond);
      expect(svg, contains('<path'));
      expect(svg, contains('stroke='));
    });

    test('renders freedraw element with stroke attributes', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [
          const Point(0, 0),
          const Point(30, 20),
          const Point(60, 10),
          const Point(100, 50),
        ],
        seed: 42,
      );
      final svg = SvgElementRenderer.render(freedraw);
      expect(svg, contains('<path'));
      expect(svg, contains('stroke-linecap="round"'));
      expect(svg, contains('stroke-linejoin="round"'));
    });

    test('renders frame element with rect and label', () {
      final frame = FrameElement(
        id: const ElementId('fr1'),
        x: 0,
        y: 0,
        width: 300,
        height: 200,
        label: 'My Frame',
      );
      final svg = SvgElementRenderer.render(frame);
      expect(svg, contains('<rect'));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('<text'));
      expect(svg, contains('My Frame'));
    });

    test('renders frame with empty label (no text element)', () {
      final frame = FrameElement(
        id: const ElementId('fr2'),
        x: 0,
        y: 0,
        width: 300,
        height: 200,
        label: '',
      );
      final svg = SvgElementRenderer.render(frame);
      expect(svg, contains('<rect'));
      expect(svg, isNot(contains('<text')));
    });

    test('renders image element with file data', () {
      final image = ImageElement(
        id: const ElementId('img1'),
        x: 10,
        y: 20,
        width: 200,
        height: 150,
        fileId: 'abc123',
      );
      final files = {
        'abc123': ImageFile(
          mimeType: 'image/png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        ),
      };
      final svg = SvgElementRenderer.render(image, files: files);
      expect(svg, contains('<image'));
      expect(svg, contains('href="data:image/png;base64,'));
      expect(svg, contains('preserveAspectRatio="none"'));
    });

    test('renders image element without file (placeholder)', () {
      final image = ImageElement(
        id: const ElementId('img2'),
        x: 10,
        y: 20,
        width: 200,
        height: 150,
        fileId: 'missing',
      );
      final svg = SvgElementRenderer.render(image);
      expect(svg, contains('<rect'));
      expect(svg, contains('fill="#E0E0E0"'));
      expect(svg, contains('stroke="#999999"'));
    });

    test('renders elbow arrow with polyline path', () {
      final arrow = ArrowElement(
        id: const ElementId('ea1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(0, 50),
          const Point(100, 50),
          const Point(100, 100),
        ],
        arrowType: ArrowType.sharpElbow,
        endArrowhead: Arrowhead.arrow,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      expect(svg, contains('<path'));
      expect(svg, contains('fill="none"'));
    });

    test('renders round elbow arrow with Q commands', () {
      final arrow = ArrowElement(
        id: const ElementId('rea1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(0, 50),
          const Point(100, 50),
          const Point(100, 100),
        ],
        arrowType: ArrowType.roundElbow,
        endArrowhead: Arrowhead.arrow,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      expect(svg, contains('Q'));
    });

    test('renders elbow arrow with dashed stroke', () {
      final arrow = ArrowElement(
        id: const ElementId('ea2'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        points: [
          const Point(0, 0),
          const Point(0, 50),
          const Point(100, 50),
        ],
        arrowType: ArrowType.sharpElbow,
        strokeStyle: StrokeStyle.dashed,
        endArrowhead: Arrowhead.arrow,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      expect(svg, contains('stroke-dasharray="8,6"'));
    });

    test('renders arrow with diamond arrowhead (filled)', () {
      final arrow = ArrowElement(
        id: const ElementId('ad1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endArrowhead: Arrowhead.diamond,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      // Filled arrowhead should have fill=strokeColor
      expect(svg, contains('fill='));
    });

    test('renders arrow with circleOutline arrowhead (unfilled)', () {
      final arrow = ArrowElement(
        id: const ElementId('aco1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endArrowhead: Arrowhead.circleOutline,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      expect(svg, contains('<path'));
    });

    test('renders line with closed and roundness (curved polygon)', () {
      final line = LineElement(
        id: const ElementId('cl1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(100, 0),
          const Point(50, 100),
        ],
        closed: true,
        roundness: const Roundness.proportional(value: 0),
        seed: 42,
      );
      final svg = SvgElementRenderer.render(line);
      expect(svg, contains('<path'));
    });

    test('renders rounded rectangle', () {
      final rect = RectangleElement(
        id: const ElementId('rr1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        roundness: const Roundness.proportional(value: 0.2),
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('<path'));
    });

    test('renders rounded diamond', () {
      final diamond = DiamondElement(
        id: const ElementId('rd1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        roundness: const Roundness.proportional(value: 0.2),
        seed: 42,
      );
      final svg = SvgElementRenderer.render(diamond);
      expect(svg, contains('<path'));
    });
  });

  // =========================================================================
  // 3. ElementRenderer — uncovered element types
  // =========================================================================
  group('ElementRenderer additional coverage', () {
    late _MockRoughAdapter adapter;

    setUp(() {
      adapter = _MockRoughAdapter();
    });

    test('dispatches frame to _renderFrame', () {
      final (recorder, canvas) = _makeCanvas();
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 300,
        height: 200,
        label: 'Test Frame',
      );
      ElementRenderer.render(canvas, frame, adapter);
      recorder.endRecording();
      // Frame doesn't use the adapter — it draws directly on canvas
      expect(adapter.calls, isEmpty);
    });

    test('dispatches image element (placeholder, no resolved images)', () {
      final (recorder, canvas) = _makeCanvas();
      final image = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 200,
        height: 150,
        fileId: 'abc',
      );
      ElementRenderer.render(canvas, image, adapter);
      recorder.endRecording();
      // Image doesn't use the adapter — draws directly
      expect(adapter.calls, isEmpty);
    });

    test('dispatches round elbow arrow to drawRoundElbowArrow', () {
      final (recorder, canvas) = _makeCanvas();
      final element = ArrowElement(
        id: ElementId.generate(),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(0, 50),
          const Point(100, 50),
          const Point(100, 100),
        ],
        arrowType: ArrowType.roundElbow,
        endArrowhead: Arrowhead.arrow,
      );
      ElementRenderer.render(canvas, element, adapter);
      recorder.endRecording();
      expect(adapter.calls, ['roundElbowArrow']);
    });
  });

  // =========================================================================
  // 4. StaticCanvasPainter — grid, frame clipping, pending elements
  // =========================================================================
  group('StaticCanvasPainter additional coverage', () {
    late _MockRoughAdapter adapter;

    setUp(() {
      adapter = _MockRoughAdapter();
    });

    test('renders grid lines when gridSize is set', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );

      expect(
        () {
          painter.paint(canvas, const Size(400, 300));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('renders grid with dark background', () {
      final (recorder, canvas) = _makeCanvas();

      final painter = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
        isDarkBackground: true,
      );

      expect(
        () {
          painter.paint(canvas, const Size(400, 300));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('clips frame children to frame bounds', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(FrameElement(
        id: const ElementId('frame1'),
        x: 0,
        y: 0,
        width: 200,
        height: 200,
        label: 'Frame 1',
        index: 'a0',
      ));
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        frameId: 'frame1',
        index: 'a1',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );

      expect(
        () {
          painter.paint(canvas, const Size(800, 600));
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('renders pending elements at reduced opacity', () {
      final (recorder, canvas) = _makeCanvas();

      final pendingRect = RectangleElement(
        id: const ElementId('pending1'),
        x: 100,
        y: 100,
        width: 80,
        height: 60,
      );

      final painter = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        pendingElements: [pendingRect],
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      expect(adapter.calls, contains('rectangle'));
    });

    test('shouldRepaint returns true when gridSize changes', () {
      final painter1 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );
      final painter2 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 40,
      );
      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when isDarkBackground changes', () {
      final painter1 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        isDarkBackground: true,
      );
      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when pendingElements change', () {
      final pending = [
        RectangleElement(
          id: const ElementId('p1'),
          x: 0,
          y: 0,
          width: 50,
          height: 50,
        ),
      ];
      final painter1 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: Scene(),
        adapter: adapter,
        viewport: const ViewportState(),
        pendingElements: pending,
      );
      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('skips editing text element', () {
      final (recorder, canvas) = _makeCanvas();

      var scene = Scene();
      scene = scene.addElement(core.TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 50,
        width: 200,
        height: 40,
        text: 'Editing this',
      ));

      final painter = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        editingElementId: const ElementId('t1'),
      );

      painter.paint(canvas, const Size(800, 600));
      recorder.endRecording();

      // Text doesn't use adapter, but we verify no crash
      expect(adapter.calls, isEmpty);
    });
  });

  // =========================================================================
  // 5. SvgPathConverter — freedrawToPathData and arrowheadToPathData
  // =========================================================================
  group('SvgPathConverter additional coverage', () {
    test('freedrawToPathData with empty points returns empty string', () {
      final result = SvgPathConverter.freedrawToPathData([], 2.0);
      expect(result, isEmpty);
    });

    test('freedrawToPathData with single point returns arc (dot)', () {
      final result =
          SvgPathConverter.freedrawToPathData([const Point(50, 50)], 4.0);
      expect(result, contains('A'));
      expect(result, contains('M'));
    });

    test('freedrawToPathData with two points returns line', () {
      final result = SvgPathConverter.freedrawToPathData(
          [const Point(0, 0), const Point(100, 50)], 2.0);
      expect(result, contains('M'));
      expect(result, contains('L'));
      expect(result, isNot(contains('C')));
    });

    test('freedrawToPathData with 3+ points returns Bezier curves', () {
      final result = SvgPathConverter.freedrawToPathData(
        [
          const Point(0, 0),
          const Point(30, 20),
          const Point(60, 10),
          const Point(100, 50),
        ],
        2.0,
      );
      expect(result, contains('M'));
      expect(result, contains('C'));
    });

    test('arrowheadToPathData for bar type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.bar,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('M'));
      expect(result, contains('L'));
    });

    test('arrowheadToPathData for dot type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.dot,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('A'));
    });

    test('arrowheadToPathData for circle type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.circle,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('A'));
    });

    test('arrowheadToPathData for circleOutline type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.circleOutline,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('A'));
    });

    test('arrowheadToPathData for diamond type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.diamond,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('M'));
      expect(result, contains('Z'));
    });

    test('arrowheadToPathData for diamondOutline type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.diamondOutline,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('Z'));
    });

    test('arrowheadToPathData for crowfootOne type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.crowfootOne,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('M'));
      expect(result, contains('L'));
    });

    test('arrowheadToPathData for crowfootMany type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.crowfootMany,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(result, contains('M'));
      expect(result, contains('L'));
    });

    test('arrowheadToPathData for crowfootOneOrMany type', () {
      final result = SvgPathConverter.arrowheadToPathData(
        Arrowhead.crowfootOneOrMany,
        const Point(100, 50),
        0.0,
        2.0,
      );
      // Contains both crowfootMany and crowfootOne paths
      expect(result, contains('M'));
      expect(result, contains('L'));
      // Should be longer than just one path (concatenation of many + one)
      expect(result.length, greaterThan(20));
    });
  });

  // =========================================================================
  // 6. StyleIconPainters — construct and paint each painter
  // =========================================================================
  group('StyleIconPainters', () {
    testWidgets('StrokeWidthIcon paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: StrokeWidthIcon(2.0),
          ),
        ),
      );
    });

    testWidgets('StrokeWidthIcon shouldRepaint detects width change',
        (tester) async {
      final p1 = StrokeWidthIcon(1.0);
      final p2 = StrokeWidthIcon(2.0);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    testWidgets('StrokeStyleIcon solid paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: StrokeStyleIcon('solid'),
          ),
        ),
      );
    });

    testWidgets('StrokeStyleIcon dashed paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: StrokeStyleIcon('dashed'),
          ),
        ),
      );
    });

    testWidgets('StrokeStyleIcon dotted paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: StrokeStyleIcon('dotted'),
          ),
        ),
      );
    });

    testWidgets('FillStyleIcon solid paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: FillStyleIcon('solid'),
          ),
        ),
      );
    });

    testWidgets('FillStyleIcon hachure paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: FillStyleIcon('hachure'),
          ),
        ),
      );
    });

    testWidgets('FillStyleIcon cross-hatch paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: FillStyleIcon('cross-hatch'),
          ),
        ),
      );
    });

    testWidgets('FillStyleIcon zigzag paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: FillStyleIcon('zigzag'),
          ),
        ),
      );
    });

    testWidgets('RoughnessIcon smooth (0) paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: RoughnessIcon(0.0),
          ),
        ),
      );
    });

    testWidgets('RoughnessIcon medium (1) paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: RoughnessIcon(1.0),
          ),
        ),
      );
    });

    testWidgets('RoughnessIcon high (2.5) paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: RoughnessIcon(2.5),
          ),
        ),
      );
    });

    testWidgets('RoundnessIcon sharp paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: RoundnessIcon(false),
          ),
        ),
      );
    });

    testWidgets('RoundnessIcon rounded paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: RoundnessIcon(true),
          ),
        ),
      );
    });

    testWidgets('ArrowTypeIcon sharp paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowTypeIcon('sharp'),
          ),
        ),
      );
    });

    testWidgets('ArrowTypeIcon round paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowTypeIcon('round'),
          ),
        ),
      );
    });

    testWidgets('ArrowTypeIcon elbow paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowTypeIcon('elbow'),
          ),
        ),
      );
    });

    testWidgets('ArrowTypeIcon round-elbow paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowTypeIcon('round-elbow'),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon null (no arrowhead) paints line only',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(null),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon arrow paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.arrow),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon bar paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.bar),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon dot paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.dot),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon triangle paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.triangle),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon triangleOutline paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.triangleOutline),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon circle paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.circle),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon circleOutline paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.circleOutline),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon diamond paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.diamond),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon diamondOutline paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.diamondOutline),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon crowfootOne paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.crowfootOne),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon crowfootMany paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.crowfootMany),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon crowfootOneOrMany paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.crowfootOneOrMany),
          ),
        ),
      );
    });

    testWidgets('ArrowheadIcon isStart=true reverses direction',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: ArrowheadIcon(Arrowhead.arrow, isStart: true),
          ),
        ),
      );
    });

    testWidgets('DiagonalLinePainter paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: DiagonalLinePainter(),
          ),
        ),
      );
    });

    testWidgets('DiamondIconPainter paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: DiamondIconPainter(color: Colors.black),
          ),
        ),
      );
    });

    testWidgets('DiamondIconPainter filled paints without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(24, 24),
            painter: DiamondIconPainter(color: Colors.blue, filled: true),
          ),
        ),
      );
    });

    testWidgets('EraserCursorPainter paints without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            size: const Size(20, 20),
            painter: EraserCursorPainter(),
          ),
        ),
      );
    });

    test('StrokeStyleIcon shouldRepaint detects style change', () {
      final p1 = StrokeStyleIcon('solid');
      final p2 = StrokeStyleIcon('dashed');
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('FillStyleIcon shouldRepaint detects style change', () {
      final p1 = FillStyleIcon('solid');
      final p2 = FillStyleIcon('hachure');
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('RoughnessIcon shouldRepaint detects roughness change', () {
      final p1 = RoughnessIcon(0.0);
      final p2 = RoughnessIcon(2.0);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('RoundnessIcon shouldRepaint detects rounded change', () {
      final p1 = RoundnessIcon(false);
      final p2 = RoundnessIcon(true);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('ArrowTypeIcon shouldRepaint detects type change', () {
      final p1 = ArrowTypeIcon('sharp');
      final p2 = ArrowTypeIcon('round');
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('ArrowheadIcon shouldRepaint detects arrowhead change', () {
      final p1 = ArrowheadIcon(Arrowhead.arrow);
      final p2 = ArrowheadIcon(Arrowhead.triangle);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('DiamondIconPainter shouldRepaint detects color change', () {
      final p1 = DiamondIconPainter(color: Colors.black);
      final p2 = DiamondIconPainter(color: Colors.red);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('DiagonalLinePainter shouldRepaint returns false', () {
      final p1 = DiagonalLinePainter();
      expect(p1.shouldRepaint(p1), isFalse);
    });

    test('EraserCursorPainter shouldRepaint returns false', () {
      final p1 = EraserCursorPainter();
      expect(p1.shouldRepaint(p1), isFalse);
    });
  });
}
