import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/bindings/binding_utils.dart';

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

Element _ellipse({required String id, double x = 0, double y = 0}) => Element(
      id: ElementId(id),
      type: 'ellipse',
      x: x,
      y: y,
      width: 100,
      height: 100,
    );

Element _diamond({required String id, double x = 0, double y = 0}) => Element(
      id: ElementId(id),
      type: 'diamond',
      x: x,
      y: y,
      width: 100,
      height: 100,
    );

Element _text({required String id}) => Element(
      id: ElementId(id),
      type: 'text',
      x: 0,
      y: 0,
      width: 100,
      height: 20,
    );

LineElement _line({required String id}) => LineElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: const [Point(0, 0), Point(100, 100)],
    );

ArrowElement _arrow({
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

FreedrawElement _freedraw({required String id}) => FreedrawElement(
      id: ElementId(id),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: const [Point(0, 0), Point(50, 50), Point(100, 100)],
    );

void main() {
  group('isBindable', () {
    test('rectangle is bindable', () {
      expect(BindingUtils.isBindable(_rect(id: 'r1')), isTrue);
    });

    test('ellipse is bindable', () {
      expect(BindingUtils.isBindable(_ellipse(id: 'e1')), isTrue);
    });

    test('diamond is bindable', () {
      expect(BindingUtils.isBindable(_diamond(id: 'd1')), isTrue);
    });

    test('text is not bindable', () {
      expect(BindingUtils.isBindable(_text(id: 't1')), isFalse);
    });

    test('line is not bindable', () {
      expect(BindingUtils.isBindable(_line(id: 'l1')), isFalse);
    });

    test('arrow is not bindable', () {
      expect(BindingUtils.isBindable(_arrow(id: 'a1')), isFalse);
    });

    test('freedraw is not bindable', () {
      expect(BindingUtils.isBindable(_freedraw(id: 'f1')), isFalse);
    });
  });

  group('findBindTarget', () {
    test('finds nearest bindable element within radius', () {
      final rect = _rect(id: 'r1', x: 100, y: 100);
      final scene = Scene().addElement(rect);
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(115, 100), // near left edge
        snapRadius: 20,
      );
      expect(target, isNotNull);
      expect(target!.id, ElementId('r1'));
    });

    test('returns null when no element within radius', () {
      final rect = _rect(id: 'r1', x: 100, y: 100);
      final scene = Scene().addElement(rect);
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(50, 50), // far from rect
        snapRadius: 20,
      );
      expect(target, isNull);
    });

    test('ignores non-bindable elements', () {
      final line = _line(id: 'l1');
      final scene = Scene().addElement(line);
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(50, 50),
        snapRadius: 20,
      );
      expect(target, isNull);
    });

    test('excludes element by id', () {
      final rect = _rect(id: 'r1', x: 0, y: 0);
      final scene = Scene().addElement(rect);
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(10, 10),
        snapRadius: 20,
        excludeId: ElementId('r1'),
      );
      expect(target, isNull);
    });

    test('finds nearest when multiple elements qualify', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 50, h: 50);
      final rect2 = _rect(id: 'r2', x: 60, y: 0, w: 50, h: 50);
      final scene = Scene().addElement(rect1).addElement(rect2);
      // Point is between them but closer to rect2's left edge (60) than rect1's right edge (50)
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(57, 25),
        snapRadius: 20,
      );
      expect(target!.id, ElementId('r2'));
    });

    test('ignores deleted elements', () {
      var rect = _rect(id: 'r1', x: 0, y: 0);
      rect = rect.copyWith(isDeleted: true) as Element;
      final scene = Scene().addElement(rect);
      final target = BindingUtils.findBindTarget(
        scene,
        const Point(10, 10),
        snapRadius: 20,
      );
      expect(target, isNull);
    });
  });

  group('computeFixedPoint', () {
    // rect at (100, 100) with size 100x100
    // bounds: left=100, top=100, right=200, bottom=200
    final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);

    test('projects to left edge', () {
      final fp = BindingUtils.computeFixedPoint(rect, const Point(95, 150));
      expect(fp.x, closeTo(0.0, 0.01)); // left edge
      expect(fp.y, closeTo(0.5, 0.01)); // vertically centered
    });

    test('projects to right edge', () {
      final fp = BindingUtils.computeFixedPoint(rect, const Point(210, 150));
      expect(fp.x, closeTo(1.0, 0.01)); // right edge
      expect(fp.y, closeTo(0.5, 0.01)); // vertically centered
    });

    test('projects to top edge', () {
      final fp = BindingUtils.computeFixedPoint(rect, const Point(150, 90));
      expect(fp.x, closeTo(0.5, 0.01)); // horizontally centered
      expect(fp.y, closeTo(0.0, 0.01)); // top edge
    });

    test('projects to bottom edge', () {
      final fp = BindingUtils.computeFixedPoint(rect, const Point(150, 210));
      expect(fp.x, closeTo(0.5, 0.01)); // horizontally centered
      expect(fp.y, closeTo(1.0, 0.01)); // bottom edge
    });

    test('projects corner point to nearest edge', () {
      // Point near top-left corner — closer to top edge
      final fp = BindingUtils.computeFixedPoint(rect, const Point(105, 90));
      // Should project to top edge at x fraction ~0.05
      expect(fp.y, closeTo(0.0, 0.01)); // top edge
      expect(fp.x, closeTo(0.05, 0.01));
    });

    test('projects interior point to nearest edge', () {
      // Point inside near left edge
      final fp = BindingUtils.computeFixedPoint(rect, const Point(110, 140));
      expect(fp.x, closeTo(0.0, 0.01)); // left edge is nearest
      expect(fp.y, closeTo(0.4, 0.01));
    });
  });

  group('resolveBindingPoint', () {
    test('resolves left edge center', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final binding = PointBinding(
        elementId: 'r1',
        fixedPoint: const Point(0.0, 0.5),
      );
      final resolved = BindingUtils.resolveBindingPoint(rect, binding);
      expect(resolved.x, closeTo(100, 0.01)); // left edge
      expect(resolved.y, closeTo(150, 0.01)); // vertical center
    });

    test('resolves right edge center', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final binding = PointBinding(
        elementId: 'r1',
        fixedPoint: const Point(1.0, 0.5),
      );
      final resolved = BindingUtils.resolveBindingPoint(rect, binding);
      expect(resolved.x, closeTo(200, 0.01));
      expect(resolved.y, closeTo(150, 0.01));
    });

    test('resolves top edge center', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final binding = PointBinding(
        elementId: 'r1',
        fixedPoint: const Point(0.5, 0.0),
      );
      final resolved = BindingUtils.resolveBindingPoint(rect, binding);
      expect(resolved.x, closeTo(150, 0.01));
      expect(resolved.y, closeTo(100, 0.01));
    });

    test('resolves bottom edge center', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final binding = PointBinding(
        elementId: 'r1',
        fixedPoint: const Point(0.5, 1.0),
      );
      final resolved = BindingUtils.resolveBindingPoint(rect, binding);
      expect(resolved.x, closeTo(150, 0.01));
      expect(resolved.y, closeTo(200, 0.01));
    });

    test('round-trips with computeFixedPoint', () {
      final rect = _rect(id: 'r1', x: 50, y: 80, w: 120, h: 60);
      final scenePoint = const Point(50, 100); // left edge, 20px down
      final fp = BindingUtils.computeFixedPoint(rect, scenePoint);
      final binding = PointBinding(elementId: 'r1', fixedPoint: fp);
      final resolved = BindingUtils.resolveBindingPoint(rect, binding);
      // Should be on the left edge (x=50) with the y component from the fixedPoint
      expect(resolved.x, closeTo(50, 0.5));
    });
  });

  group('updateBoundArrowEndpoints', () {
    test('updates start-bound arrow', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 0,
        w: 100,
        h: 100,
        points: [const Point(0, 0), const Point(100, 100)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.0, 0.5), // left edge center
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);
      // Start point should now be at rect's left edge center (100, 150)
      // converted to absolute: x + points[0].x
      final startAbs = Point(updated.x + updated.points.first.x,
          updated.y + updated.points.first.y);
      expect(startAbs.x, closeTo(100, 0.01));
      expect(startAbs.y, closeTo(150, 0.01));
    });

    test('updates end-bound arrow', () {
      final rect = _rect(id: 'r1', x: 200, y: 200, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 0,
        w: 200,
        h: 200,
        points: [const Point(0, 0), const Point(200, 200)],
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.5, 0.0), // top edge center
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);
      final endAbs = Point(updated.x + updated.points.last.x,
          updated.y + updated.points.last.y);
      expect(endAbs.x, closeTo(250, 0.01));
      expect(endAbs.y, closeTo(200, 0.01));
    });

    test('updates both endpoints', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
      final rect2 = _rect(id: 'r2', x: 200, y: 200, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 50,
        y: 50,
        w: 200,
        h: 200,
        points: [const Point(0, 0), const Point(200, 200)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5), // right edge center
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0.0, 0.5), // left edge center
        ),
      );
      final scene =
          Scene().addElement(rect1).addElement(rect2).addElement(arrow);
      final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);

      final startAbs = Point(updated.x + updated.points.first.x,
          updated.y + updated.points.first.y);
      final endAbs = Point(updated.x + updated.points.last.x,
          updated.y + updated.points.last.y);

      expect(startAbs.x, closeTo(100, 0.01)); // right edge of r1
      expect(startAbs.y, closeTo(50, 0.01)); // vertical center of r1
      expect(endAbs.x, closeTo(200, 0.01)); // left edge of r2
      expect(endAbs.y, closeTo(250, 0.01)); // vertical center of r2
    });

    test('leaves arrow unchanged if target not found', () {
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 0,
        w: 100,
        h: 100,
        points: [const Point(0, 0), const Point(100, 100)],
        startBinding: const PointBinding(
          elementId: 'missing',
          fixedPoint: Point(0.5, 0.5),
        ),
      );
      final scene = Scene().addElement(arrow);
      final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);
      // Arrow should be unchanged
      expect(updated.x, arrow.x);
      expect(updated.y, arrow.y);
      expect(updated.points, arrow.points);
    });

    test('returns same arrow when no bindings', () {
      final arrow = _arrow(id: 'a1');
      final scene = Scene().addElement(arrow);
      final updated = BindingUtils.updateBoundArrowEndpoints(arrow, scene);
      expect(updated.x, arrow.x);
      expect(updated.points, arrow.points);
    });
  });

  group('findBoundArrows', () {
    test('finds arrows bound at start', () {
      final rect = _rect(id: 'r1');
      final arrow = _arrow(
        id: 'a1',
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.5, 0.0),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final bound = BindingUtils.findBoundArrows(scene, ElementId('r1'));
      expect(bound, hasLength(1));
      expect(bound.first.id, ElementId('a1'));
    });

    test('finds arrows bound at end', () {
      final rect = _rect(id: 'r1');
      final arrow = _arrow(
        id: 'a1',
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.5, 1.0),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final bound = BindingUtils.findBoundArrows(scene, ElementId('r1'));
      expect(bound, hasLength(1));
      expect(bound.first.id, ElementId('a1'));
    });

    test('returns empty when no arrows bound', () {
      final rect = _rect(id: 'r1');
      final arrow = _arrow(id: 'a1');
      final scene = Scene().addElement(rect).addElement(arrow);
      final bound = BindingUtils.findBoundArrows(scene, ElementId('r1'));
      expect(bound, isEmpty);
    });

    test('finds multiple arrows bound to same element', () {
      final rect = _rect(id: 'r1');
      final arrow1 = _arrow(
        id: 'a1',
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.0, 0.5),
        ),
      );
      final arrow2 = _arrow(
        id: 'a2',
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene =
          Scene().addElement(rect).addElement(arrow1).addElement(arrow2);
      final bound = BindingUtils.findBoundArrows(scene, ElementId('r1'));
      expect(bound, hasLength(2));
    });
  });
}
