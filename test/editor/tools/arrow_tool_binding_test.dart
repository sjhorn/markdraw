import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tools/arrow_tool.dart';
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

ArrowElement _extractArrow(ToolResult? result) {
  final compound = result! as CompoundResult;
  return (compound.results[0] as AddElementResult).element as ArrowElement;
}

void main() {
  late ArrowTool tool;

  setUp(() {
    tool = ArrowTool();
  });

  group('ArrowTool binding on creation', () {
    test('start point near rect gets startBinding', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // First point near right edge of rect (at x=200)
      tool.onPointerDown(const Point(195, 150), ctx);
      tool.onPointerUp(const Point(195, 150), ctx);

      // Second point far away
      tool.onPointerDown(const Point(400, 150), ctx);
      final result = tool.onPointerUp(const Point(400, 150), ctx,
          isDoubleClick: true);

      final arrow = _extractArrow(result);
      expect(arrow.startBinding, isNotNull);
      expect(arrow.startBinding!.elementId, 'r1');
      expect(arrow.startBinding!.fixedPoint.x, closeTo(1.0, 0.01));
    });

    test('end point near rect gets endBinding', () {
      final rect = _rect(id: 'r1', x: 300, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // First point far away
      tool.onPointerDown(const Point(50, 150), ctx);
      tool.onPointerUp(const Point(50, 150), ctx);

      // Second point near left edge of rect (at x=300)
      tool.onPointerDown(const Point(305, 150), ctx);
      final result = tool.onPointerUp(const Point(305, 150), ctx,
          isDoubleClick: true);

      final arrow = _extractArrow(result);
      expect(arrow.endBinding, isNotNull);
      expect(arrow.endBinding!.elementId, 'r1');
      expect(arrow.endBinding!.fixedPoint.x, closeTo(0.0, 0.1));
    });

    test('both endpoints bound to different rects', () {
      final rect1 = _rect(id: 'r1', x: 0, y: 0, w: 100, h: 100);
      final rect2 = _rect(id: 'r2', x: 300, y: 0, w: 100, h: 100);
      final scene = Scene().addElement(rect1).addElement(rect2);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // First point near right edge of rect1
      tool.onPointerDown(const Point(95, 50), ctx);
      tool.onPointerUp(const Point(95, 50), ctx);

      // Second point near left edge of rect2
      tool.onPointerDown(const Point(305, 50), ctx);
      final result = tool.onPointerUp(const Point(305, 50), ctx,
          isDoubleClick: true);

      final arrow = _extractArrow(result);
      expect(arrow.startBinding, isNotNull);
      expect(arrow.startBinding!.elementId, 'r1');
      expect(arrow.endBinding, isNotNull);
      expect(arrow.endBinding!.elementId, 'r2');
    });

    test('arrow far from shapes gets no bindings', () {
      final rect = _rect(id: 'r1', x: 500, y: 500, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      tool.onPointerDown(const Point(100, 100), ctx);
      final result = tool.onPointerUp(const Point(100, 100), ctx,
          isDoubleClick: true);

      final arrow = _extractArrow(result);
      expect(arrow.startBinding, isNull);
      expect(arrow.endBinding, isNull);
    });

    test('start point snaps to edge', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // Click near left edge (x=100) of rect
      tool.onPointerDown(const Point(90, 150), ctx);
      tool.onPointerUp(const Point(90, 150), ctx);

      // End point far away
      tool.onPointerDown(const Point(400, 150), ctx);
      final result = tool.onPointerUp(const Point(400, 150), ctx,
          isDoubleClick: true);

      final arrow = _extractArrow(result);
      // The start point should be snapped to the left edge
      final startAbs = Point(
        arrow.x + arrow.points.first.x,
        arrow.y + arrow.points.first.y,
      );
      expect(startAbs.x, closeTo(100, 0.5)); // snapped to left edge
      expect(startAbs.y, closeTo(150, 0.5));
    });

    test('overlay shows bindTargetBounds during move near shape', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // Add first point
      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);

      // Move near the rect
      tool.onPointerMove(const Point(105, 150), ctx);
      final overlay = tool.overlay;
      expect(overlay, isNotNull);
      expect(overlay!.bindTargetBounds, isNotNull);
      expect(overlay.bindTargetBounds!.left, 100);
      expect(overlay.bindTargetBounds!.top, 100);
    });

    test('overlay clears bindTargetBounds when moving away', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);

      // Move near shape
      tool.onPointerMove(const Point(105, 150), ctx);
      expect(tool.overlay!.bindTargetBounds, isNotNull);

      // Move far away
      tool.onPointerMove(const Point(500, 500), ctx);
      expect(tool.overlay!.bindTargetBounds, isNull);
    });

    test('finalize via Enter preserves bindings', () {
      final rect = _rect(id: 'r1', x: 100, y: 100, w: 100, h: 100);
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {},
      );

      // First point near right edge
      tool.onPointerDown(const Point(195, 150), ctx);
      tool.onPointerUp(const Point(195, 150), ctx);

      // Second point far away
      tool.onPointerDown(const Point(400, 150), ctx);
      tool.onPointerUp(const Point(400, 150), ctx);

      final result = tool.onKeyEvent('Enter');
      final arrow = _extractArrow(result);
      expect(arrow.startBinding, isNotNull);
      expect(arrow.startBinding!.elementId, 'r1');
    });
  });
}
