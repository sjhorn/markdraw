import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

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
  double w = 100,
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

/// Extracts all UpdateElementResult elements from a CompoundResult.
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

/// Simulates a drag from [from] to [to] on a SelectTool with given context.
ToolResult? _drag(SelectTool tool, ToolContext ctx, Point from, Point to,
    {bool shift = false}) {
  tool.onPointerDown(from, ctx, shift: shift);
  // Move enough to trigger drag
  tool.onPointerMove(to, ctx);
  return tool.onPointerUp(to, ctx);
}

void main() {
  late SelectTool tool;

  setUp(() {
    tool = SelectTool();
  });

  group('bound arrow updates on move', () {
    test('move rect → bound arrow start follows', () {
      // Arrow bound at start to right edge of rect
      final rect = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 100,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5), // right edge center
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      // Drag rect 50px right
      final result = _drag(tool, ctx, const Point(50, 50), const Point(100, 50));
      final updates = _extractUpdates(result);

      // Find the arrow update
      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate, isNotNull, reason: 'Arrow should be updated');

      // Arrow start should now be at (150, 50) — moved right edge center
      final a = arrowUpdate! as ArrowElement;
      final startAbs = Point(a.x + a.points.first.x, a.y + a.points.first.y);
      expect(startAbs.x, closeTo(150, 0.5));
      expect(startAbs.y, closeTo(50, 0.5));
    });

    test('move rect → bound arrow end follows', () {
      final rect = _rect(id: 'r1', x: 200, y: 0, w: 100, h: 100);
      final arrow = _arrow(
        id: 'a1',
        x: 0,
        y: 50,
        w: 200,
        h: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.0, 0.5), // left edge center
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      // Drag rect 50px right
      final result =
          _drag(tool, ctx, const Point(250, 50), const Point(300, 50));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate, isNotNull);

      final a = arrowUpdate! as ArrowElement;
      final endAbs = Point(a.x + a.points.last.x, a.y + a.points.last.y);
      expect(endAbs.x, closeTo(250, 0.5)); // left edge of moved rect
      expect(endAbs.y, closeTo(50, 0.5));
    });

    test('two arrows bound to same rect both update', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final arrow1 = _arrow(
        id: 'a1',
        x: 0,
        y: 150,
        w: 100,
        h: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(0.0, 0.5),
        ),
      );
      final arrow2 = _arrow(
        id: 'a2',
        x: 200,
        y: 150,
        w: 100,
        h: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene = Scene()
          .addElement(rect)
          .addElement(arrow1)
          .addElement(arrow2);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      final result =
          _drag(tool, ctx, const Point(150, 150), const Point(200, 150));
      final updates = _extractUpdates(result);

      final a1 = updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      final a2 = updates.where((e) => e.id == const ElementId('a2')).firstOrNull;
      expect(a1, isNotNull, reason: 'arrow1 should be updated');
      expect(a2, isNotNull, reason: 'arrow2 should be updated');
    });

    test('unbound shape move produces no arrow updates', () {
      final rect = _rect(id: 'r1', x: 0, y: 0);
      final arrow = _arrow(id: 'a1', x: 200, y: 200); // no bindings
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      final result = _drag(tool, ctx, const Point(50, 50), const Point(100, 50));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate, isNull);
    });

    test('arrow in selection set is not double-moved', () {
      // Both rect and bound arrow are selected
      final rect = _rect(id: 'r1', x: 0, y: 0);
      final arrow = _arrow(
        id: 'a1',
        x: 100,
        y: 50,
        w: 100,
        h: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1'), const ElementId('a1')},
      );

      final result = _drag(tool, ctx, const Point(50, 50), const Point(100, 50));
      final updates = _extractUpdates(result);

      // Arrow should only appear once in updates (from multi-move, not from binding)
      final arrowUpdates =
          updates.where((e) => e.id == const ElementId('a1')).toList();
      expect(arrowUpdates, hasLength(1));
    });

    test('nudge rect → bound arrow follows', () {
      final rect = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
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

      final result =
          tool.onKeyEvent('ArrowRight', context: ctx);
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate, isNotNull);
    });

    test('arrow bound both ends → move one rect → only that end moves', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
      final rect2 = _rect(id: 'r2', x: 300, y: 0, w: 100, h: 100);
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
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
      );

      // Move rect1 50px down
      final result = _drag(tool, ctx, const Point(50, 50), const Point(50, 100));
      final updates = _extractUpdates(result);

      final arrowUpdate =
          updates.where((e) => e.id == const ElementId('a1')).firstOrNull;
      expect(arrowUpdate, isNotNull);

      final a = arrowUpdate! as ArrowElement;
      // Start should be at rect1's moved right edge center: (100, 100)
      final startAbs = Point(a.x + a.points.first.x, a.y + a.points.first.y);
      expect(startAbs.y, closeTo(100, 0.5)); // moved down 50
      // End should still be at rect2's left edge center: (300, 50) — unchanged
      final endAbs = Point(a.x + a.points.last.x, a.y + a.points.last.y);
      expect(endAbs.x, closeTo(300, 0.5));
      expect(endAbs.y, closeTo(50, 0.5));
    });
  });
}
