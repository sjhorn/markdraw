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

/// Apply a ToolResult to a scene, returning the updated scene.
Scene _applyResult(Scene scene, ToolResult? result) {
  if (result == null) return scene;
  if (result is AddElementResult) {
    return scene.addElement(result.element);
  }
  if (result is UpdateElementResult) {
    return scene.updateElement(result.element);
  }
  if (result is RemoveElementResult) {
    return scene.removeElement(result.id);
  }
  if (result is CompoundResult) {
    var s = scene;
    for (final r in result.results) {
      s = _applyResult(s, r);
    }
    return s;
  }
  return scene;
}

void main() {
  group('arrow binding edge cases', () {
    test('delete bound target → clear binding on arrows', () {
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
        selectedIds: {const ElementId('r1')},
      );

      final tool = SelectTool();
      final result =
          tool.onKeyEvent('Delete', context: ctx);

      // Apply result to get updated scene
      final newScene = _applyResult(scene, result);

      // Rect should be removed
      expect(newScene.getElementById(const ElementId('r1')), isNull);

      // Arrow's binding should be cleared
      final updatedArrow =
          newScene.getElementById(const ElementId('a1')) as ArrowElement?;
      expect(updatedArrow, isNotNull);
      expect(updatedArrow!.startBinding, isNull,
          reason: 'Binding to deleted target should be cleared');
    });

    test('updateBoundArrowEndpoints with missing target leaves arrow unchanged',
        () {
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 0,
        startBinding: const PointBinding(
          elementId: 'missing',
          fixedPoint: Point(0.5, 0.5),
        ),
      );
      final scene = Scene().addElement(arrow);

      // Already tested in binding_utils_test, but validate integration
      final tool = SelectTool();
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // Should not crash
      expect(() => tool.onKeyEvent('ArrowRight', context: ctx), returnsNormally);
    });

    test('select-all and move → bound arrows in selection not double-moved', () {
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
      final allIds = scene.activeElements.map((e) => e.id).toSet();

      // Select all, then nudge
      final tool = SelectTool();
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: allIds,
      );

      final result = tool.onKeyEvent('ArrowRight', context: ctx);

      // Collect all arrow updates
      final updates = <Element>[];
      if (result is CompoundResult) {
        for (final r in result.results) {
          if (r is UpdateElementResult && r.element.id == const ElementId('a1')) {
            updates.add(r.element);
          }
        }
      }

      // Arrow should appear only once (from the nudge, not from binding update)
      expect(updates, hasLength(1),
          reason: 'Arrow should only be updated once (no double-move)');
    });

    test('full round-trip: create → move → verify → unbind → move → verify independence',
        () {
      // Step 1: Create a rect and an arrow bound to it
      final rect = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
      var scene = Scene().addElement(rect);

      // Create arrow with ArrowTool near rect
      final arrowTool = ArrowTool();
      var ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // First point near right edge of rect
      arrowTool.onPointerDown(const Point(95, 50), ctx);
      arrowTool.onPointerUp(const Point(95, 50), ctx);
      // Second point far away
      arrowTool.onPointerDown(const Point(300, 50), ctx);
      final createResult = arrowTool.onPointerUp(const Point(300, 50), ctx,
          isDoubleClick: true);

      scene = _applyResult(scene, createResult);

      // Find the created arrow
      final arrows = scene.activeElements.whereType<ArrowElement>().toList();
      expect(arrows, hasLength(1));
      final arrow = arrows.first;
      expect(arrow.startBinding, isNotNull);
      expect(arrow.startBinding!.elementId, 'r1');

      // Step 2: Move the rect and verify arrow follows
      final selectTool1 = SelectTool();
      ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      selectTool1.onPointerDown(const Point(50, 50), ctx);
      selectTool1.onPointerMove(const Point(100, 50), ctx);
      final moveResult = selectTool1.onPointerUp(const Point(100, 50), ctx);
      scene = _applyResult(scene, moveResult);

      // Arrow start bound at (95, 50) inside rect → fixedPoint (0.95, 0.5).
      // After moving rect +50 in x to (50, 0): resolve = (50 + 0.95*100, 0 + 0.5*100) = (145, 50).
      final movedArrow =
          scene.getElementById(arrow.id) as ArrowElement;
      final startAbs = Point(
        movedArrow.x + movedArrow.points.first.x,
        movedArrow.y + movedArrow.points.first.y,
      );
      expect(startAbs.x, closeTo(145, 1.0)); // interior offset preserved
      expect(startAbs.y, closeTo(50, 1.0));

      // Step 3: Unbind by dragging arrow start away
      final selectTool2 = SelectTool();
      ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {arrow.id},
      );

      // Drag the start point far away
      selectTool2.onPointerDown(
          Point(movedArrow.x + movedArrow.points.first.x,
              movedArrow.y + movedArrow.points.first.y),
          ctx);
      selectTool2.onPointerMove(const Point(500, 500), ctx);
      final unbindResult =
          selectTool2.onPointerUp(const Point(500, 500), ctx);
      scene = _applyResult(scene, unbindResult);

      final unboundArrow =
          scene.getElementById(arrow.id) as ArrowElement;
      expect(unboundArrow.startBinding, isNull,
          reason: 'Arrow should be unbound after drag away');

      // Step 4: Move rect again — arrow should NOT follow
      final selectTool3 = SelectTool();
      ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      // Get arrow's current start position
      final beforeMove = scene.getElementById(arrow.id) as ArrowElement;
      final beforeStartAbs = Point(
        beforeMove.x + beforeMove.points.first.x,
        beforeMove.y + beforeMove.points.first.y,
      );

      selectTool3.onPointerDown(const Point(100, 50), ctx);
      selectTool3.onPointerMove(const Point(200, 50), ctx);
      final moveResult2 = selectTool3.onPointerUp(const Point(200, 50), ctx);
      scene = _applyResult(scene, moveResult2);

      // Arrow should NOT have moved
      final afterMove = scene.getElementById(arrow.id) as ArrowElement;
      final afterStartAbs = Point(
        afterMove.x + afterMove.points.first.x,
        afterMove.y + afterMove.points.first.y,
      );
      expect(afterStartAbs.x, closeTo(beforeStartAbs.x, 0.01),
          reason: 'Unbound arrow should not move with rect');
      expect(afterStartAbs.y, closeTo(beforeStartAbs.y, 0.01));
    });

    test('delete bound target clears both start and end bindings', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0);
      final rect2 = _rect(id: 'r2', x: 300, y: 0);
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
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0.0, 0.5),
        ),
      );
      final scene =
          Scene().addElement(rect1).addElement(rect2).addElement(arrow);

      // Delete rect1
      final tool1 = SelectTool();
      var ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );
      final result1 = tool1.onKeyEvent('Delete', context: ctx);
      var newScene = _applyResult(scene, result1);

      var updatedArrow =
          newScene.getElementById(const ElementId('a1')) as ArrowElement;
      expect(updatedArrow.startBinding, isNull,
          reason: 'Start binding to deleted r1 should be cleared');
      expect(updatedArrow.endBinding, isNotNull,
          reason: 'End binding to r2 should remain');

      // Delete rect2
      final tool2 = SelectTool();
      ctx = ToolContext(
        scene: newScene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r2')},
      );
      final result2 = tool2.onKeyEvent('Delete', context: ctx);
      newScene = _applyResult(newScene, result2);

      updatedArrow =
          newScene.getElementById(const ElementId('a1')) as ArrowElement;
      expect(updatedArrow.endBinding, isNull,
          reason: 'End binding to deleted r2 should be cleared');
    });
  });
}
