import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

(PictureRecorder, Canvas) _makeCanvas() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  return (recorder, canvas);
}

void main() {
  group('SelectionRenderer', () {
    test('drawSelectionBox does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(100, 100, 200, 150);

      expect(
        () {
          SelectionRenderer.drawSelectionBox(canvas, bounds);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawSelectionBox with rotated canvas does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(100, 100, 200, 150);

      expect(
        () {
          canvas.save();
          canvas.rotate(0.5);
          SelectionRenderer.drawSelectionBox(canvas, bounds);
          canvas.restore();
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawHandles does not throw with 9 handles', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(100, 100, 200, 150);
      final handles = SelectionOverlay.computeHandles(bounds);

      expect(
        () {
          SelectionRenderer.drawHandles(canvas, handles);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawRotationHandle draws line and circle', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(100, 100, 200, 150);
      final handles = SelectionOverlay.computeHandles(bounds);
      final topCenter = handles
          .firstWhere((h) => h.type == HandleType.topCenter)
          .position;
      final rotation = handles
          .firstWhere((h) => h.type == HandleType.rotation)
          .position;

      expect(
        () {
          SelectionRenderer.drawRotationHandle(
              canvas, rotation, topCenter);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawHoverHighlight does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(50, 50, 300, 200);

      expect(
        () {
          SelectionRenderer.drawHoverHighlight(canvas, bounds);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawMarquee draws rectangle', () {
      final (recorder, canvas) = _makeCanvas();
      const rect = Rect.fromLTWH(10, 20, 300, 200);

      expect(
        () {
          SelectionRenderer.drawMarquee(canvas, rect);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawSnapLine draws horizontal line', () {
      final (recorder, canvas) = _makeCanvas();
      const snapLine = SnapLine(
        orientation: SnapLineOrientation.horizontal,
        position: 150,
        start: 0,
        end: 800,
      );

      expect(
        () {
          SelectionRenderer.drawSnapLine(canvas, snapLine);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawSnapLine draws vertical line', () {
      final (recorder, canvas) = _makeCanvas();
      const snapLine = SnapLine(
        orientation: SnapLineOrientation.vertical,
        position: 250,
        start: 0,
        end: 600,
      );

      expect(
        () {
          SelectionRenderer.drawSnapLine(canvas, snapLine);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawPointHandles does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final points = [const Point(10, 20), const Point(100, 200), const Point(300, 50)];

      expect(
        () {
          SelectionRenderer.drawPointHandles(canvas, points);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawPointHandles with empty list does not throw', () {
      final (recorder, canvas) = _makeCanvas();

      expect(
        () {
          SelectionRenderer.drawPointHandles(canvas, []);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawCreationPreviewLine does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final points = [const Point(10, 20), const Point(100, 200)];

      expect(
        () {
          SelectionRenderer.drawCreationPreviewLine(canvas, points);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawCreationPreviewShape does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(50, 50, 200, 150);

      expect(
        () {
          SelectionRenderer.drawCreationPreviewShape(canvas, bounds);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });

    test('drawBindingIndicator does not throw', () {
      final (recorder, canvas) = _makeCanvas();
      final bounds = Bounds.fromLTWH(100, 100, 200, 150);

      expect(
        () {
          SelectionRenderer.drawBindingIndicator(canvas, bounds);
          recorder.endRecording();
        },
        returnsNormally,
      );
    });
  });
}
