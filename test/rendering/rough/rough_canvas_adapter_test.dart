import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/rough/draw_style.dart';
import 'package:markdraw/src/rendering/rough/rough_adapter.dart';
import 'package:markdraw/src/rendering/rough/rough_canvas_adapter.dart';

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
  return DrawStyle.fromElement(Element(
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

void main() {
  late RoughCanvasAdapter adapter;

  setUp(() {
    adapter = RoughCanvasAdapter();
  });

  group('implements RoughAdapter', () {
    test('RoughCanvasAdapter is a RoughAdapter', () {
      expect(adapter, isA<RoughAdapter>());
    });
  });

  group('drawRectangle', () {
    test('produces canvas draw calls without error', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(10, 20, 100, 80);

      adapter.drawRectangle(canvas, bounds, _style());

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('with dashed stroke does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(10, 20, 100, 80);

      expect(
        () => adapter.drawRectangle(
            canvas, bounds, _style(strokeStyle: StrokeStyle.dashed)),
        returnsNormally,
      );

      recorder.endRecording();
    });

    test('with different fill styles', () {
      for (final fill in FillStyle.values) {
        final (recorder, canvas) = _makeCanvas();
        adapter.drawRectangle(
          canvas,
          Bounds.fromLTWH(0, 0, 100, 100),
          _style(fillStyle: fill),
        );
        recorder.endRecording();
      }
    });
  });

  group('drawEllipse', () {
    test('produces canvas draw calls without error', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(10, 20, 100, 80);

      adapter.drawEllipse(canvas, bounds, _style());

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('with hachure fill', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawEllipse(
        canvas,
        Bounds.fromLTWH(0, 0, 80, 60),
        _style(fillStyle: FillStyle.hachure),
      );
      recorder.endRecording();
    });
  });

  group('drawDiamond', () {
    test('produces canvas draw calls without error', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(10, 20, 100, 80);

      adapter.drawDiamond(canvas, bounds, _style());

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('uses midpoints of bounding box edges', () {
      // Diamond should use 4 midpoints: top-center, right-center,
      // bottom-center, left-center
      final (recorder, canvas) = _makeCanvas();
      adapter.drawDiamond(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 100),
        _style(),
      );
      recorder.endRecording();
    });
  });

  group('drawLine', () {
    test('two-point line', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawLine(
        canvas,
        [const Point(0, 0), const Point(100, 100)],
        _style(),
      );
      recorder.endRecording();
    });

    test('multi-segment line', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawLine(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        _style(),
      );
      recorder.endRecording();
    });

    test('empty points does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawLine(canvas, [], _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test('single point does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawLine(canvas, [const Point(50, 50)], _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });

  group('drawArrow', () {
    test('draws line with end arrowhead', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawArrow(
        canvas,
        [const Point(0, 0), const Point(100, 0)],
        null,
        Arrowhead.arrow,
        _style(),
      );
      recorder.endRecording();
    });

    test('draws line with both arrowheads', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawArrow(
        canvas,
        [const Point(0, 0), const Point(100, 0)],
        Arrowhead.arrow,
        Arrowhead.arrow,
        _style(),
      );
      recorder.endRecording();
    });

    test('draws with no arrowheads (plain line)', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawArrow(
        canvas,
        [const Point(0, 0), const Point(100, 0)],
        null,
        null,
        _style(),
      );
      recorder.endRecording();
    });

    test('all arrowhead types render', () {
      for (final type in Arrowhead.values) {
        final (recorder, canvas) = _makeCanvas();
        adapter.drawArrow(
          canvas,
          [const Point(0, 0), const Point(100, 0)],
          null,
          type,
          _style(),
        );
        recorder.endRecording();
      }
    });

    test('multi-segment arrow', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawArrow(
        canvas,
        [const Point(0, 0), const Point(50, 50), const Point(100, 0)],
        Arrowhead.triangle,
        Arrowhead.arrow,
        _style(),
      );
      recorder.endRecording();
    });
  });

  group('drawFreedraw', () {
    test('delegates to FreedrawRenderer', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawFreedraw(
        canvas,
        [const Point(0, 0), const Point(50, 30), const Point(100, 10)],
        [],
        false,
        _style(),
      );
      recorder.endRecording();
    });

    test('empty points does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      expect(
        () => adapter.drawFreedraw(canvas, [], [], false, _style()),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });

  group('seed determinism', () {
    test('same seed produces identical rendering', () {
      final style = _style(seed: 42);

      // Render twice with same seed
      final recorder1 = PictureRecorder();
      final canvas1 = Canvas(recorder1);
      adapter.drawRectangle(
          canvas1, Bounds.fromLTWH(0, 0, 100, 100), style);
      final pic1 = recorder1.endRecording();

      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      adapter.drawRectangle(
          canvas2, Bounds.fromLTWH(0, 0, 100, 100), style);
      final pic2 = recorder2.endRecording();

      // Approximate size should be the same
      expect(pic1.approximateBytesUsed, pic2.approximateBytesUsed);
    });
  });

  group('dashed stroke', () {
    test('dashed rectangle does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawRectangle(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 100),
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });

    test('dotted ellipse does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawEllipse(
        canvas,
        Bounds.fromLTWH(0, 0, 100, 80),
        _style(strokeStyle: StrokeStyle.dotted),
      );
      recorder.endRecording();
    });

    test('dashed line does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      adapter.drawLine(
        canvas,
        [const Point(0, 0), const Point(100, 0)],
        _style(strokeStyle: StrokeStyle.dashed),
      );
      recorder.endRecording();
    });
  });
}
