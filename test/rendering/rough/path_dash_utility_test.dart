import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:markdraw/markdraw.dart';

void main() {
  group('patternFor', () {
    test('solid returns null', () {
      expect(PathDashUtility.patternFor(StrokeStyle.solid), isNull);
    });

    test('dashed returns [8, 6]', () {
      expect(PathDashUtility.patternFor(StrokeStyle.dashed), [8.0, 6.0]);
    });

    test('dotted returns [1.5, 6]', () {
      expect(PathDashUtility.patternFor(StrokeStyle.dotted), [1.5, 6.0]);
    });
  });

  group('dashPath', () {
    test('solid style returns path unchanged', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      final result = PathDashUtility.dashPath(path, StrokeStyle.solid);
      // Should return the same path (no dashing)
      final origBounds = path.getBounds();
      final resultBounds = result.getBounds();
      expect(resultBounds, origBounds);
    });

    test('dashing a straight line produces segments', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      final result = PathDashUtility.dashPath(path, StrokeStyle.dashed);
      final metrics = result.computeMetrics().toList();
      // A 100px line with 8+6=14px pattern -> ~7 dash segments
      expect(metrics.length, greaterThan(1));
    });

    test('dotted pattern on a straight line produces segments', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      final result = PathDashUtility.dashPath(path, StrokeStyle.dotted);
      final metrics = result.computeMetrics().toList();
      // 1.5+6=7.5px pattern -> ~13 dot segments
      expect(metrics.length, greaterThan(1));
    });

    test('pattern longer than path produces single segment', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(5, 0);
      final result = PathDashUtility.dashPath(path, StrokeStyle.dashed);
      final metrics = result.computeMetrics().toList();
      // 5px path < 8px dash, so just one segment
      expect(metrics.length, 1);
    });

    test('empty path produces empty path', () {
      final path = Path();
      final result = PathDashUtility.dashPath(path, StrokeStyle.dashed);
      final metrics = result.computeMetrics().toList();
      expect(metrics.isEmpty, isTrue);
    });

    test('dashed path stays within original bounds', () {
      final path = Path()
        ..moveTo(10, 20)
        ..lineTo(200, 20);
      final result = PathDashUtility.dashPath(path, StrokeStyle.dashed);
      final origBounds = path.getBounds();
      final resultBounds = result.getBounds();
      expect(resultBounds.left, greaterThanOrEqualTo(origBounds.left));
      expect(resultBounds.right, lessThanOrEqualTo(origBounds.right + 1));
      expect(resultBounds.top, greaterThanOrEqualTo(origBounds.top - 1));
      expect(resultBounds.bottom, lessThanOrEqualTo(origBounds.bottom + 1));
    });

    test('multi-contour path is dashed correctly', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..moveTo(0, 50)
        ..lineTo(100, 50);
      final result = PathDashUtility.dashPath(path, StrokeStyle.dashed);
      final metrics = result.computeMetrics().toList();
      // Both contours should produce segments
      expect(metrics.length, greaterThan(2));
    });
  });
}
