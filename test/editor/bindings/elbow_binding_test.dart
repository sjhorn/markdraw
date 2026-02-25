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
      elbowed: true,
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
