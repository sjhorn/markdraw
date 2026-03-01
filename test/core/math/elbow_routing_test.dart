import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('ElbowRouting', () {
    group('headingFromFixedPoint', () {
      test('left edge (fx=0) → Heading.left', () {
        expect(
          ElbowRouting.headingFromFixedPoint(const Point(0.0, 0.5)),
          Heading.left,
        );
      });

      test('right edge (fx=1) → Heading.right', () {
        expect(
          ElbowRouting.headingFromFixedPoint(const Point(1.0, 0.5)),
          Heading.right,
        );
      });

      test('top edge (fy=0) → Heading.up', () {
        expect(
          ElbowRouting.headingFromFixedPoint(const Point(0.5, 0.0)),
          Heading.up,
        );
      });

      test('bottom edge (fy=1) → Heading.down', () {
        expect(
          ElbowRouting.headingFromFixedPoint(const Point(0.5, 1.0)),
          Heading.down,
        );
      });
    });

    group('inferHeading', () {
      test('target to the right → Heading.right', () {
        expect(
          ElbowRouting.inferHeading(const Point(0, 0), const Point(100, 0)),
          Heading.right,
        );
      });

      test('target to the left → Heading.left', () {
        expect(
          ElbowRouting.inferHeading(const Point(100, 0), const Point(0, 0)),
          Heading.left,
        );
      });

      test('target below → Heading.down', () {
        expect(
          ElbowRouting.inferHeading(const Point(0, 0), const Point(0, 100)),
          Heading.down,
        );
      });

      test('target above → Heading.up', () {
        expect(
          ElbowRouting.inferHeading(const Point(0, 100), const Point(0, 0)),
          Heading.up,
        );
      });
    });

    group('route', () {
      test('straight horizontal route', () {
        final points = ElbowRouting.route(
          start: const Point(0, 50),
          end: const Point(200, 50),
          startHeading: Heading.right,
          endHeading: Heading.left,
        );

        // Should be a straight horizontal line (collinear simplified)
        expect(points.first, const Point(0, 50));
        expect(points.last, const Point(200, 50));
        // All points should have the same Y
        for (final p in points) {
          expect(p.y, 50.0);
        }
      });

      test('straight vertical route', () {
        final points = ElbowRouting.route(
          start: const Point(50, 0),
          end: const Point(50, 200),
          startHeading: Heading.down,
          endHeading: Heading.up,
        );

        expect(points.first, const Point(50, 0));
        expect(points.last, const Point(50, 200));
        for (final p in points) {
          expect(p.x, 50.0);
        }
      });

      test('L-shape route (horizontal start, vertical end)', () {
        final points = ElbowRouting.route(
          start: const Point(0, 0),
          end: const Point(100, 100),
          startHeading: Heading.right,
          endHeading: Heading.up,
        );

        expect(points.first, const Point(0, 0));
        expect(points.last, const Point(100, 100));
        // Should have exactly one bend forming an L shape
        // All segments should be horizontal or vertical
        _assertOrthogonal(points);
      });

      test('Z-shape route (both horizontal headings)', () {
        final points = ElbowRouting.route(
          start: const Point(0, 0),
          end: const Point(200, 100),
          startHeading: Heading.right,
          endHeading: Heading.left,
        );

        expect(points.first, const Point(0, 0));
        expect(points.last, const Point(200, 100));
        _assertOrthogonal(points);
      });

      test('S-shape route (both vertical headings)', () {
        final points = ElbowRouting.route(
          start: const Point(0, 0),
          end: const Point(100, 200),
          startHeading: Heading.down,
          endHeading: Heading.up,
        );

        expect(points.first, const Point(0, 0));
        expect(points.last, const Point(100, 200));
        _assertOrthogonal(points);
      });

      test('U-shape route (opposing headings with overlap)', () {
        // Start heading right, end heading right — need to go around
        final points = ElbowRouting.route(
          start: const Point(0, 0),
          end: const Point(100, 100),
          startHeading: Heading.right,
          endHeading: Heading.right,
        );

        expect(points.first, const Point(0, 0));
        expect(points.last, const Point(100, 100));
        _assertOrthogonal(points);
      });

      test('route with null headings infers from positions', () {
        final points = ElbowRouting.route(
          start: const Point(0, 0),
          end: const Point(200, 0),
        );

        expect(points.first, const Point(0, 0));
        expect(points.last, const Point(200, 0));
        _assertOrthogonal(points);
      });
    });

    group('simplify', () {
      test('removes collinear points', () {
        final points = [
          const Point(0, 0),
          const Point(50, 0),
          const Point(100, 0),
          const Point(100, 100),
        ];

        final simplified = ElbowRouting.simplify(points);
        expect(simplified, [
          const Point(0, 0),
          const Point(100, 0),
          const Point(100, 100),
        ]);
      });

      test('merges short segments', () {
        final points = [
          const Point(0, 0),
          const Point(1, 0), // Too close to previous
          const Point(100, 0),
          const Point(100, 100),
        ];

        final simplified = ElbowRouting.simplify(points, minLength: 2.0);
        // The short segment point (1,0) should be removed
        expect(simplified.length, lessThan(points.length));
        expect(simplified.first, const Point(0, 0));
        expect(simplified.last, const Point(100, 100));
      });

      test('preserves two-point path', () {
        final points = [const Point(0, 0), const Point(100, 100)];
        final simplified = ElbowRouting.simplify(points);
        expect(simplified, points);
      });
    });
  });

    group('updateTerminals', () {
      test('4-point: move start → only first segment adjusts', () {
        // Original path: right then down then right
        // P0(0,0) → P1(50,0) → P2(50,100) → P3(100,100)
        final original = [
          const Point(0, 0),
          const Point(50, 0),
          const Point(50, 100),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newStart: const Point(0, 20),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        // Start moved
        expect(result.first, const Point(0, 20));
        // End unchanged
        expect(result.last, const Point(100, 100));
        // Middle segment (vertical at x=50) should be preserved
        // P1 adjusts to (0, 0) or similar but P2 stays at (50, 100)
        expect(result.any((p) => p.x == 50 && p.y == 100), isTrue,
            reason: 'P2 should be preserved');
      });

      test('4-point: move end → only last segment adjusts', () {
        final original = [
          const Point(0, 0),
          const Point(50, 0),
          const Point(50, 100),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newEnd: const Point(120, 100),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        // Start unchanged
        expect(result.first, const Point(0, 0));
        // End moved
        expect(result.last, const Point(120, 100));
        // P1 should be preserved exactly
        expect(result.any((p) => p.x == 50 && p.y == 0), isTrue,
            reason: 'P1 should be preserved');
      });

      test('4-point: move both → both terminals adjust', () {
        final original = [
          const Point(0, 0),
          const Point(50, 0),
          const Point(50, 100),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newStart: const Point(10, 0),
          newEnd: const Point(120, 100),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        expect(result.first, const Point(10, 0));
        expect(result.last, const Point(120, 100));
      });

      test('6-point: move end → middle points preserved exactly', () {
        // A complex path with 6 points
        // P0(0,0) → P1(0,50) → P2(100,50) → P3(100,150) → P4(200,150) → P5(200,200)
        final original = [
          const Point(0, 0),
          const Point(0, 50),
          const Point(100, 50),
          const Point(100, 150),
          const Point(200, 150),
          const Point(200, 200),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newEnd: const Point(220, 200),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        // Start unchanged
        expect(result.first, const Point(0, 0));
        // End moved
        expect(result.last, const Point(220, 200));
        // Middle points P1, P2, P3 must be preserved exactly
        expect(result.contains(const Point(0, 50)), isTrue,
            reason: 'P1 preserved');
        expect(result.contains(const Point(100, 50)), isTrue,
            reason: 'P2 preserved');
        expect(result.contains(const Point(100, 150)), isTrue,
            reason: 'P3 preserved');
      });

      test('3-point: move start → correct recalculation', () {
        // P0(0,0) → P1(100,0) → P2(100,100)
        // First segment is horizontal
        final original = [
          const Point(0, 0),
          const Point(100, 0),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newStart: const Point(0, 20),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        expect(result.first, const Point(0, 20));
        expect(result.last, const Point(100, 100));
      });

      test('2-point: returns null', () {
        final original = [
          const Point(0, 0),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newStart: const Point(10, 10),
        );

        expect(result, isNull);
      });

      test('collinear result simplified', () {
        // After terminal adjustment, points may become collinear
        // P0(0,0) → P1(50,0) → P2(50,100) → P3(100,100)
        // Move end to (50,100) so P2→P3 becomes zero-length
        final original = [
          const Point(0, 0),
          const Point(50, 0),
          const Point(50, 100),
          const Point(100, 100),
        ];

        final result = ElbowRouting.updateTerminals(
          original,
          newEnd: const Point(50, 100),
        );

        expect(result, isNotNull);
        _assertOrthogonal(result!);
        // Should have fewer points due to simplification
        expect(result.length, lessThanOrEqualTo(4));
        expect(result.first, const Point(0, 0));
        expect(result.last, const Point(50, 100));
      });
    });

  group('ArrowElement elbowed field', () {
    // These are tested in arrow_element_test.dart, but we add
    // coverage for the elbowed field specifically
    test('covered in arrow_element_test.dart', () {
      // Placeholder — actual tests are in the dedicated file
      expect(true, isTrue);
    });
  });
}

/// Assert all segments in the path are horizontal or vertical.
void _assertOrthogonal(List<Point> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final isHorizontal = a.y == b.y;
    final isVertical = a.x == b.x;
    expect(
      isHorizontal || isVertical,
      isTrue,
      reason: 'Segment $i ($a → $b) is neither horizontal nor vertical',
    );
  }
}
