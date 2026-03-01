import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

Element _rect({
  required String id,
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
}) =>
    Element(
      id: ElementId(id),
      type: 'rectangle',
      x: x,
      y: y,
      width: w,
      height: h,
    );

ArrowElement _elbowArrow({
  required String id,
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
  List<Point>? points,
  PointBinding? startBinding,
  PointBinding? endBinding,
}) =>
    ArrowElement(
      id: ElementId(id),
      x: x,
      y: y,
      width: w,
      height: h,
      points: points ?? const [Point(0, 0), Point(100, 100)],
      startBinding: startBinding,
      endBinding: endBinding,
      arrowType: ArrowType.sharpElbow,
    );

ArrowElement _regularArrow({
  required String id,
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
  List<Point>? points,
  PointBinding? startBinding,
  PointBinding? endBinding,
}) =>
    ArrowElement(
      id: ElementId(id),
      x: x,
      y: y,
      width: w,
      height: h,
      points: points ?? const [Point(0, 0), Point(100, 100)],
      startBinding: startBinding,
      endBinding: endBinding,
    );

Scene _scene(List<Element> elements) {
  var scene = Scene();
  for (final e in elements) {
    scene = scene.addElement(e);
  }
  return scene;
}

void main() {
  group('Elbow binding re-routing', () {
    group('move bound shape → elbow arrow re-routes', () {
      test('moving start-bound shape re-routes elbow arrow', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 0);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 0,
          points: const [Point(0, 0), Point(200, 0)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5), // right edge
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5), // left edge
          ),
        );

        // Move rect1 down by 100
        final movedRect1 = rect1.copyWith(y: 100.0);
        final scene = _scene([movedRect1, rect2, arrow]);

        final updated =
            BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });

      test('moving end-bound shape re-routes elbow arrow', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 0);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 0,
          points: const [Point(0, 0), Point(200, 0)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        // Move rect2 down by 200
        final movedRect2 = rect2.copyWith(y: 200.0);
        final scene = _scene([rect1, movedRect2, arrow]);

        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });
    });

    group('resize bound shape → elbow arrow re-routes', () {
      test('resizing start-bound shape re-routes elbow arrow', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
        final rect2 = _rect(id: 'r2', x: 300, y: 0);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 0,
          points: const [Point(0, 0), Point(200, 0)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        // Resize rect1 wider
        final resizedRect1 = rect1.copyWith(width: 200.0);
        final scene = _scene([resizedRect1, rect2, arrow]);

        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
        // Start point should reflect the new right edge at x=200
        final absPoints = _absolutePoints(updated);
        expect(absPoints.first.x, closeTo(200.0, 0.1));
      });

      test('resizing end-bound shape re-routes elbow arrow', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 0, w: 100, h: 100);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 0,
          points: const [Point(0, 0), Point(200, 0)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        // Resize rect2 taller
        final resizedRect2 = rect2.copyWith(height: 200.0);
        final scene = _scene([rect1, resizedRect2, arrow]);

        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });
    });

    group('elbow arrow with one bound + one free endpoint', () {
      test('only start bound re-routes with inferred end heading', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 100,
          points: const [Point(0, 0), Point(200, 100)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
        );

        // Move rect1 to trigger update
        final movedRect1 = rect1.copyWith(y: 50.0);
        final scene = _scene([movedRect1, arrow]);

        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });

      test('only end bound re-routes with inferred start heading', () {
        final rect2 = _rect(id: 'r2', x: 300, y: 0);
        final arrow = _elbowArrow(
          id: 'a1',
          x: 0,
          y: 50,
          w: 300,
          h: 0,
          points: const [Point(0, 0), Point(300, 0)],
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        final movedRect2 = rect2.copyWith(y: 100.0);
        final scene = _scene([movedRect2, arrow]);

        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });
    });

    group('elbow arrow with no bindings', () {
      test('unbound elbowed arrow is returned unchanged', () {
        final arrow = _elbowArrow(
          id: 'a1',
          points: const [Point(0, 0), Point(0, 50), Point(100, 50)],
        );

        final scene = _scene([arrow]);
        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(identical(updated, arrow), isTrue);
      });

      test('elbowed arrow with missing target is unchanged', () {
        final arrow = _elbowArrow(
          id: 'a1',
          startBinding: const PointBinding(
            elementId: 'nonexistent',
            fixedPoint: Point(1.0, 0.5),
          ),
        );

        final scene = _scene([arrow]);
        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(identical(updated, arrow), isTrue);
      });
    });

    group('middle segments preserved on bound shape move', () {
      test('6-point elbow arrow preserves middle segments when end shape moves',
          () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
        final rect2 = _rect(id: 'r2', x: 400, y: 200, w: 100, h: 100);
        // Pre-routed 6-point arrow with custom middle segments
        // Absolute: (100,50)→(150,50)→(150,150)→(300,150)→(300,250)→(400,250)
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 300,
          h: 200,
          points: const [
            Point(0, 0), // abs (100,50)
            Point(50, 0), // abs (150,50)
            Point(50, 100), // abs (150,150)
            Point(200, 100), // abs (300,150)
            Point(200, 200), // abs (300,250)
            Point(300, 200), // abs (400,250)
          ],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5), // right edge
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5), // left edge
          ),
        );

        // Move rect2 down by 50 (left edge now at (400,300))
        final movedRect2 = rect2.copyWith(y: 250.0);
        final scene = _scene([rect1, movedRect2, arrow]);

        final updated =
            BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        final absPoints = _absolutePoints(updated);
        _assertOrthogonal(absPoints);

        // Start should be unchanged
        expect(absPoints.first.x, closeTo(100, 0.1));
        expect(absPoints.first.y, closeTo(50, 0.1));

        // Middle segments P1(150,50) and P2(150,150) should be preserved
        expect(absPoints.any((p) =>
            (p.x - 150).abs() < 0.1 && (p.y - 50).abs() < 0.1), isTrue,
            reason: 'P1 should be preserved at (150,50)');
        expect(absPoints.any((p) =>
            (p.x - 150).abs() < 0.1 && (p.y - 150).abs() < 0.1), isTrue,
            reason: 'P2 should be preserved at (150,150)');
        // P3 at (300,150) should be preserved too
        expect(absPoints.any((p) =>
            (p.x - 300).abs() < 0.1 && (p.y - 150).abs() < 0.1), isTrue,
            reason: 'P3 should be preserved at (300,150)');
      });

      test('segment drag then move bound shape preserves dragged segment', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
        final rect2 = _rect(id: 'r2', x: 400, y: 0, w: 100, h: 100);
        // 4-point arrow where middle segment was dragged to custom position
        // Absolute: (100,50)→(250,50)→(250,50)→(400,50) initially
        // After segment drag: middle at y=80
        // Absolute: (100,50)→(100,80)→(400,80)→(400,50)
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 300,
          h: 30,
          points: const [
            Point(0, 0), // abs (100,50)
            Point(0, 30), // abs (100,80)
            Point(300, 30), // abs (400,80)
            Point(300, 0), // abs (400,50)
          ],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        // Move rect2 down by 60 (left edge now at (400,80))
        final movedRect2 = rect2.copyWith(y: 60.0);
        final scene = _scene([rect1, movedRect2, arrow]);

        final updated =
            BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        final absPoints = _absolutePoints(updated);
        _assertOrthogonal(absPoints);

        // Start unchanged
        expect(absPoints.first.x, closeTo(100, 0.1));
        expect(absPoints.first.y, closeTo(50, 0.1));

        // The dragged middle segment's Y=80 should be preserved
        expect(absPoints.any((p) => (p.y - 80).abs() < 0.1), isTrue,
            reason: 'Dragged middle segment y=80 should be preserved');
      });

      test('2-point elbow arrow falls back to full route', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 0);
        // A 2-point arrow (unusual but possible)
        final arrow = _elbowArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 0,
          points: const [Point(0, 0), Point(200, 0)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        // Move rect1 down — should still work via full route fallback
        final movedRect1 = rect1.copyWith(y: 100.0);
        final scene = _scene([movedRect1, rect2, arrow]);

        final updated =
            BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isTrue);
        _assertOrthogonal(_absolutePoints(updated));
      });
    });

    group('non-elbowed arrows unchanged (regression)', () {
      test('regular arrow updates endpoints without re-routing', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 200);
        final arrow = _regularArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 200,
          points: const [Point(0, 0), Point(100, 100), Point(200, 200)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        final scene = _scene([rect1, rect2, arrow]);
        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        // Regular arrow should preserve its middle points count
        expect(updated.elbowed, isFalse);
        expect(updated.points.length, 3);
      });

      test('regular arrow keeps diagonal segments', () {
        final rect1 = _rect(id: 'r1', x: 0, y: 0);
        final rect2 = _rect(id: 'r2', x: 300, y: 300);
        final arrow = _regularArrow(
          id: 'a1',
          x: 100,
          y: 50,
          w: 200,
          h: 300,
          points: const [Point(0, 0), Point(200, 300)],
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
        );

        final scene = _scene([rect1, rect2, arrow]);
        final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

        expect(updated.elbowed, isFalse);
        expect(updated.points.length, 2);
      });
    });
  });
}

/// Convert an arrow's relative points to absolute points.
List<Point> _absolutePoints(ArrowElement arrow) {
  return arrow.points.map((p) => Point(arrow.x + p.x, arrow.y + p.y)).toList();
}

/// Assert all segments in the path are horizontal or vertical.
void _assertOrthogonal(List<Point> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final isHorizontal = (a.y - b.y).abs() < 0.001;
    final isVertical = (a.x - b.x).abs() < 0.001;
    expect(
      isHorizontal || isVertical,
      isTrue,
      reason: 'Segment $i ($a → $b) is neither horizontal nor vertical',
    );
  }
}
