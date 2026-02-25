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

ArrowElement _arrow({
  required String id,
  double x = 0,
  double y = 0,
  double w = 200,
  double h = 0,
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
      points: points ?? [const Point(0, 0), Point(w, h)],
      startBinding: startBinding,
      endBinding: endBinding,
    );

/// Extracts all UpdateElementResult elements from a result.
List<Element> _extractUpdates(ToolResult? result) {
  if (result is CompoundResult) {
    return result.results
        .whereType<UpdateElementResult>()
        .map((r) => r.element)
        .toList();
  }
  if (result is UpdateElementResult) return [result.element];
  return [];
}

/// Simulate a point drag: pointerDown on a point handle, then move+up.
ToolResult? _pointDrag(
    SelectTool tool, ToolContext ctx, Point from, Point to) {
  tool.onPointerDown(from, ctx);
  tool.onPointerMove(to, ctx);
  return tool.onPointerUp(to, ctx);
}

void main() {
  late SelectTool tool;

  setUp(() {
    tool = SelectTool();
  });

  group('arrow point drag rebinding/unbinding', () {
    test('drag start away from shape → unbind', () {
      final rect = _rect(id: 'r1', x: 0, y: 0);
      final arrow = _arrow(
        id: 'a1',
        x: 100,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Drag the start point (at absolute 100, 50) far away
      final result =
          _pointDrag(tool, ctx, const Point(100, 50), const Point(500, 300));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).first as ArrowElement;
      expect(arrowUpdate.startBinding, isNull,
          reason: 'Start binding should be cleared');
    });

    test('drag end near shape → bind', () {
      final rect = _rect(id: 'r1', x: 400, y: 0, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        // No initial binding
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Drag the last point (at absolute 200, 50) near rect's left edge
      final result =
          _pointDrag(tool, ctx, const Point(200, 50), const Point(405, 50));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).first as ArrowElement;
      expect(arrowUpdate.endBinding, isNotNull,
          reason: 'End binding should be set');
      expect(arrowUpdate.endBinding!.elementId, 'r1');
    });

    test('drag start to different shape → rebind', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0);
      final rect2 = _rect(id: 'r2', x: 0, y: 300, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 100,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene =
          Scene().addElement(rect1).addElement(rect2).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Drag start point near rect2's right edge
      final result =
          _pointDrag(tool, ctx, const Point(100, 50), const Point(95, 350));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).first as ArrowElement;
      expect(arrowUpdate.startBinding, isNotNull);
      expect(arrowUpdate.startBinding!.elementId, 'r2',
          reason: 'Should rebind to rect2');
    });

    test('drag middle point → no binding change', () {
      final rect = _rect(id: 'r1', x: 0, y: 0);
      // Arrow with 3 points — middle point at index 1
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 100,
        y: 0,
        width: 200,
        height: 100,
        points: const [Point(0, 0), Point(100, 50), Point(200, 100)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.0),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Drag the middle point (at absolute 200, 50) somewhere
      final result =
          _pointDrag(tool, ctx, const Point(200, 50), const Point(250, 80));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).first as ArrowElement;
      // Binding should be unchanged — middle points don't affect bindings
      expect(arrowUpdate.startBinding, isNotNull);
      expect(arrowUpdate.startBinding!.elementId, 'r1');
    });

    test('after unbind old target does not affect arrow', () {
      final rect = _rect(id: 'r1', x: 0, y: 0);
      final arrow = _arrow(
        id: 'a1',
        x: 100,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Step 1: Drag start point away to unbind
      final result1 =
          _pointDrag(tool, ctx, const Point(100, 50), const Point(500, 300));
      final updates1 = _extractUpdates(result1);
      final unboundArrow =
          updates1.where((e) => e.id == const ElementId('a1')).first as ArrowElement;
      expect(unboundArrow.startBinding, isNull);

      // Step 2: Now move the rect with the unbound arrow in scene
      final scene2 = scene.updateElement(unboundArrow);
      final ctx2 = ToolContext(
        scene: scene2,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );
      final tool2 = SelectTool();
      tool2.onPointerDown(const Point(50, 50), ctx2);
      tool2.onPointerMove(const Point(150, 50), ctx2);
      final result2 = tool2.onPointerUp(const Point(150, 50), ctx2);

      final updates2 = _extractUpdates(result2);
      // Arrow should NOT be updated since it's no longer bound
      final arrowUpdate2 =
          updates2.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate2, isNull,
          reason: 'Unbound arrow should not be affected by rect move');
    });

    test('overlay shows bindTargetBounds during point drag near shape', () {
      final rect = _rect(id: 'r1', x: 400, y: 0, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('a1')},
      );

      // Start point drag on last point
      tool.onPointerDown(const Point(200, 50), ctx);
      // Move near rect
      tool.onPointerMove(const Point(405, 50), ctx);

      final overlay = tool.overlay;
      expect(overlay, isNotNull);
      expect(overlay!.bindTargetBounds, isNotNull);
      expect(overlay.bindTargetBounds!.left, 400);
    });
  });
}
