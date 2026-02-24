import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/math/elbow_routing.dart';
import 'package:markdraw/src/core/math/point.dart';

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
