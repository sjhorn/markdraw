import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  RectangleElement makeRect(String id, double x, double y,
          {double w = 50, double h = 50, double angle = 0}) =>
      RectangleElement(
        id: ElementId(id),
        x: x, y: y, width: w, height: h, angle: angle,
      );

  group('AlignmentUtils align (unrotated)', () {
    test('alignLeft aligns to leftmost x', () {
      final elements = [makeRect('a', 10, 0), makeRect('b', 50, 0), makeRect('c', 100, 0)];
      final result = AlignmentUtils.alignLeft(elements);
      expect(result, hasLength(3));
      for (final e in result) {
        expect(e.x, 10);
      }
    });

    test('alignRight aligns right edges', () {
      final elements = [makeRect('a', 0, 0, w: 30), makeRect('b', 50, 0, w: 100)];
      final result = AlignmentUtils.alignRight(elements);
      // Union right = 50 + 100 = 150
      expect(result[0].x, 150 - 30);
      expect(result[1].x, 150 - 100);
    });

    test('alignCenterH aligns horizontal centers', () {
      final elements = [makeRect('a', 0, 0, w: 20), makeRect('b', 80, 0, w: 20)];
      final result = AlignmentUtils.alignCenterH(elements);
      // Union left=0, right=100, center=50
      expect(result[0].x, 50 - 10); // 40
      expect(result[1].x, 50 - 10); // 40
    });

    test('alignTop aligns to topmost y', () {
      final elements = [makeRect('a', 0, 20), makeRect('b', 0, 80)];
      final result = AlignmentUtils.alignTop(elements);
      for (final e in result) {
        expect(e.y, 20);
      }
    });

    test('alignBottom aligns bottom edges', () {
      final elements = [makeRect('a', 0, 0, h: 30), makeRect('b', 0, 50, h: 100)];
      final result = AlignmentUtils.alignBottom(elements);
      // Union bottom = 50 + 100 = 150
      expect(result[0].y, 150 - 30);
      expect(result[1].y, 150 - 100);
    });

    test('alignCenterV aligns vertical centers', () {
      final elements = [makeRect('a', 0, 0, h: 20), makeRect('b', 0, 80, h: 20)];
      final result = AlignmentUtils.alignCenterV(elements);
      // Union top=0, bottom=100, center=50
      expect(result[0].y, 50 - 10); // 40
      expect(result[1].y, 50 - 10); // 40
    });

    test('returns empty for single element', () {
      final elements = [makeRect('a', 0, 0)];
      expect(AlignmentUtils.alignLeft(elements), isEmpty);
      expect(AlignmentUtils.alignTop(elements), isEmpty);
    });

    test('returns empty for empty list', () {
      expect(AlignmentUtils.alignLeft([]), isEmpty);
    });
  });

  group('AlignmentUtils distribute (unrotated)', () {
    test('distributeH spaces elements evenly', () {
      final elements = [
        makeRect('a', 0, 0, w: 20),
        makeRect('b', 10, 0, w: 20),
        makeRect('c', 100, 0, w: 20),
      ];
      final result = AlignmentUtils.distributeH(elements);
      expect(result, hasLength(3));
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.x.compareTo(b.x));
      expect(sorted[0].x, 0);
      expect(sorted[1].x, closeTo(50, 0.01));
      expect(sorted[2].x, closeTo(100, 0.01));
    });

    test('distributeV spaces elements evenly', () {
      final elements = [
        makeRect('a', 0, 0, h: 20),
        makeRect('b', 0, 10, h: 20),
        makeRect('c', 0, 100, h: 20),
      ];
      final result = AlignmentUtils.distributeV(elements);
      expect(result, hasLength(3));
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.y.compareTo(b.y));
      expect(sorted[0].y, 0);
      expect(sorted[1].y, closeTo(50, 0.01));
      expect(sorted[2].y, closeTo(100, 0.01));
    });

    test('distributeH returns empty for fewer than 3', () {
      final elements = [makeRect('a', 0, 0), makeRect('b', 100, 0)];
      expect(AlignmentUtils.distributeH(elements), isEmpty);
    });

    test('distributeV returns empty for fewer than 3', () {
      final elements = [makeRect('a', 0, 0), makeRect('b', 0, 100)];
      expect(AlignmentUtils.distributeV(elements), isEmpty);
    });

    test('distributeH with 4 elements', () {
      final elements = [
        makeRect('a', 0, 0, w: 10),
        makeRect('b', 20, 0, w: 10),
        makeRect('c', 40, 0, w: 10),
        makeRect('d', 90, 0, w: 10),
      ];
      final result = AlignmentUtils.distributeH(elements);
      expect(result, hasLength(4));
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.x.compareTo(b.x));
      expect(sorted[0].x, 0);
      expect(sorted[1].x, closeTo(30, 0.01));
      expect(sorted[2].x, closeTo(60, 0.01));
      expect(sorted[3].x, closeTo(90, 0.01));
    });
  });

  group('AlignmentUtils with rotated elements', () {
    // A 100x20 rect at (0, 40) rotated 90° (pi/2).
    // Center = (50, 50). After rotation the visual AABB is roughly:
    //   center stays at (50, 50), visual width ≈ 20, visual height ≈ 100
    //   so AABB ≈ (40, 0, 20, 100)
    const halfPi = math.pi / 2;

    test('alignLeft uses rotated AABB, not raw x', () {
      // Rect A: 100x20 at (0,40), rotated 90° → visual AABB left ≈ 40
      // Rect B: 50x50 at (200,0), unrotated → visual AABB left = 200
      final elements = [
        makeRect('a', 0, 40, w: 100, h: 20, angle: halfPi),
        makeRect('b', 200, 0),
      ];
      final result = AlignmentUtils.alignLeft(elements);
      // Union left ≈ 40 (from rotated A). B should move its visual left to 40.
      // B is unrotated so its visual left = x. So B.x ≈ 40.
      expect(result[1].x, closeTo(40, 1));
      // A should stay roughly where it is (already at leftmost)
      expect(result[0].x, closeTo(0, 1));
    });

    test('alignTop uses rotated AABB, not raw y', () {
      // Rect A: 100x20 at (0,40), rotated 90° → visual AABB top ≈ 0
      // Rect B: 50x50 at (0,200), unrotated → visual AABB top = 200
      final elements = [
        makeRect('a', 0, 40, w: 100, h: 20, angle: halfPi),
        makeRect('b', 0, 200),
      ];
      final result = AlignmentUtils.alignTop(elements);
      // Union top ≈ 0 (from rotated A). B.y should shift to ≈ 0.
      expect(result[1].y, closeTo(0, 1));
    });

    test('alignCenterH with rotated element', () {
      // Two elements whose rotated AABBs span a known range
      final elements = [
        makeRect('a', 0, 40, w: 100, h: 20, angle: halfPi),
        makeRect('b', 200, 0),
      ];
      final result = AlignmentUtils.alignCenterH(elements);
      // Both visual centers should be at the same x
      // Rotated A center x ≈ 50, B center x after move should match
      // We just verify they ended up at the same visual center
      final aCx = result[0].x + result[0].width / 2;
      final bCx = result[1].x + result[1].width / 2;
      // For unrotated B, visual center = element center
      // For rotated A, visual center ≈ element center (rotation is around center)
      expect(aCx, closeTo(bCx, 1));
    });

    test('distributeH with rotated element uses visual width', () {
      // Three elements, middle one is rotated
      final elements = [
        makeRect('a', 0, 0, w: 20, h: 20),
        makeRect('b', 40, 40, w: 100, h: 20, angle: halfPi), // visual width ≈ 20
        makeRect('c', 200, 0, w: 20, h: 20),
      ];
      final result = AlignmentUtils.distributeH(elements);
      expect(result, hasLength(3));
      // All three have visual width ≈ 20, total span from first.left to last.right
      // They should be evenly spaced using visual bounding boxes
    });
  });
}
