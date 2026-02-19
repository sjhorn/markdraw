
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/editor_state.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/editor/tools/tool_factory.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  group('Tool integration', () {
    test('createTool produces correct type for each ToolType', () {
      for (final type in ToolType.values) {
        final tool = createTool(type);
        expect(tool.type, type);
      }
    });

    test('full create-element round-trip through EditorState', () {
      var state = EditorState(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.rectangle,
      );

      final tool = createTool(ToolType.rectangle);
      final ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );

      // Simulate drag to create rectangle
      tool.onPointerDown(const Point(10, 20), ctx);
      tool.onPointerMove(const Point(110, 70), ctx);
      final result = tool.onPointerUp(const Point(110, 70), ctx);

      state = state.applyResult(result);

      expect(state.scene.elements.length, 1);
      expect(state.scene.elements.first, isA<RectangleElement>());
      expect(state.selectedIds.length, 1);
      expect(state.activeToolType, ToolType.select);
    });

    test('select-and-move round-trip through EditorState', () {
      // Start with a scene containing one rectangle
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      var state = EditorState(
        scene: Scene().addElement(rect),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.select,
      );

      // Select the element
      final selectTool = SelectTool();
      var ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );
      selectTool.onPointerDown(const Point(50, 40), ctx);
      var result = selectTool.onPointerUp(const Point(50, 40), ctx);
      state = state.applyResult(result);
      expect(state.selectedIds, {rect.id});

      // Move the element
      ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );
      selectTool.onPointerDown(const Point(50, 40), ctx);
      selectTool.onPointerMove(const Point(80, 60), ctx);
      result = selectTool.onPointerUp(const Point(80, 60), ctx);
      state = state.applyResult(result);

      final moved = state.scene.getElementById(rect.id)!;
      expect(moved.x, 40); // 10 + 30
      expect(moved.y, 40); // 20 + 20
    });

    test('hand tool pans viewport through EditorState', () {
      var state = EditorState(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.hand,
      );

      final tool = createTool(ToolType.hand);
      final ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );

      tool.onPointerDown(const Point(0, 0), ctx);
      final result = tool.onPointerMove(
        const Point(0, 0),
        ctx,
        screenDelta: const Offset(50, 30),
      );
      state = state.applyResult(result);

      expect(state.viewport.offset, const Offset(-50, -30));
    });
  });
}
