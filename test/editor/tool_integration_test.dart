
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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

    test('create → select → resize via handle round-trip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 200,
        height: 100,
      );
      var state = EditorState(
        scene: Scene().addElement(rect),
        viewport: const ViewportState(),
        selectedIds: {rect.id},
        activeToolType: ToolType.select,
      );

      final selectTool = SelectTool();
      final ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );

      // Drag bottomRight handle (300, 200) → (350, 250)
      selectTool.onPointerDown(const Point(300, 200), ctx);
      selectTool.onPointerMove(const Point(350, 250), ctx);
      final result = selectTool.onPointerUp(const Point(350, 250), ctx);
      state = state.applyResult(result);

      final resized = state.scene.getElementById(rect.id)!;
      expect(resized.width, 250);
      expect(resized.height, 150);
    });

    test('create → select → rotate round-trip', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 200,
        height: 100,
      );
      var state = EditorState(
        scene: Scene().addElement(rect),
        viewport: const ViewportState(),
        selectedIds: {rect.id},
        activeToolType: ToolType.select,
      );

      final selectTool = SelectTool();
      final ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );

      // Drag rotation handle (200, 80) → (250, 100)
      selectTool.onPointerDown(const Point(200, 80), ctx);
      selectTool.onPointerMove(const Point(250, 100), ctx);
      final result = selectTool.onPointerUp(const Point(250, 100), ctx);
      state = state.applyResult(result);

      final rotated = state.scene.getElementById(rect.id)!;
      expect(rotated.angle, isNot(0.0));
    });

    test('select all → move → verify both moved', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 50,
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 200,
        width: 80,
        height: 40,
      );
      var state = EditorState(
        scene: Scene().addElement(r1).addElement(r2),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.select,
      );

      final selectTool = SelectTool();

      // Select all
      var ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );
      var result = selectTool.onKeyEvent('a', ctrl: true, context: ctx);
      state = state.applyResult(result);
      expect(state.selectedIds, {r1.id, r2.id});

      // Move all — click on r1 center (60, 35) and drag
      ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
      );
      selectTool.onPointerDown(const Point(60, 35), ctx);
      selectTool.onPointerMove(const Point(80, 55), ctx);
      result = selectTool.onPointerUp(const Point(80, 55), ctx);
      state = state.applyResult(result);

      final moved1 = state.scene.getElementById(r1.id)!;
      final moved2 = state.scene.getElementById(r2.id)!;
      expect(moved1.x, 30); // 10 + 20
      expect(moved1.y, 30); // 10 + 20
      expect(moved2.x, 220); // 200 + 20
      expect(moved2.y, 220); // 200 + 20
    });

    test('copy → paste round-trip through EditorState', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 50,
      );
      var state = EditorState(
        scene: Scene().addElement(rect),
        viewport: const ViewportState(),
        selectedIds: {rect.id},
        activeToolType: ToolType.select,
      );

      final selectTool = SelectTool();

      // Copy
      var ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
        clipboard: state.clipboard,
      );
      var result = selectTool.onKeyEvent('c', ctrl: true, context: ctx);
      state = state.applyResult(result);
      expect(state.clipboard, hasLength(1));

      // Paste
      ctx = ToolContext(
        scene: state.scene,
        viewport: state.viewport,
        selectedIds: state.selectedIds,
        clipboard: state.clipboard,
      );
      result = selectTool.onKeyEvent('v', ctrl: true, context: ctx);
      state = state.applyResult(result);

      expect(state.scene.activeElements, hasLength(2));
      expect(state.selectedIds, hasLength(1));
      // Pasted element is at offset
      final pasted = state.scene.activeElements
          .firstWhere((e) => e.id != rect.id);
      expect(pasted.x, 20); // 10 + 10
      expect(pasted.y, 20); // 10 + 10
    });
  });
}
