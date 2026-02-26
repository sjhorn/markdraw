
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('EditorState', () {
    late EditorState state;

    setUp(() {
      state = EditorState(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.select,
      );
    });

    test('initial state has empty scene and selection', () {
      expect(state.scene.elements, isEmpty);
      expect(state.selectedIds, isEmpty);
      expect(state.activeToolType, ToolType.select);
      expect(state.viewport, const ViewportState());
    });

    test('applyResult with AddElementResult adds element to scene', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final newState = state.applyResult(AddElementResult(element));
      expect(newState.scene.elements.length, 1);
      expect(newState.scene.getElementById(const ElementId('r1')), isNotNull);
    });

    test('applyResult with UpdateElementResult updates element', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = state.applyResult(AddElementResult(element));

      final moved = element.copyWith(x: 50, y: 60);
      final newState = state.applyResult(UpdateElementResult(moved));
      final updated = newState.scene.getElementById(const ElementId('r1'))!;
      expect(updated.x, 50);
      expect(updated.y, 60);
      // Version should be bumped by Scene.updateElement
      expect(updated.version, greaterThan(element.version));
    });

    test('applyResult with RemoveElementResult removes element', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = state.applyResult(AddElementResult(element));
      final newState =
          state.applyResult(RemoveElementResult(const ElementId('r1')));
      expect(newState.scene.getElementById(const ElementId('r1')), isNull);
    });

    test('applyResult with SetSelectionResult updates selection', () {
      final ids = {const ElementId('a'), const ElementId('b')};
      final newState = state.applyResult(SetSelectionResult(ids));
      expect(newState.selectedIds, ids);
    });

    test('applyResult with UpdateViewportResult updates viewport', () {
      const viewport = ViewportState(offset: Offset(100, 200), zoom: 2.0);
      final newState = state.applyResult(UpdateViewportResult(viewport));
      expect(newState.viewport, viewport);
    });

    test('applyResult with SwitchToolResult changes active tool', () {
      final newState =
          state.applyResult(SwitchToolResult(ToolType.rectangle));
      expect(newState.activeToolType, ToolType.rectangle);
    });

    test('applyResult with CompoundResult applies all in order', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final compound = CompoundResult([
        AddElementResult(element),
        SetSelectionResult({element.id}),
        SwitchToolResult(ToolType.select),
      ]);
      final newState = state.applyResult(compound);
      expect(newState.scene.elements.length, 1);
      expect(newState.selectedIds, {const ElementId('r1')});
      expect(newState.activeToolType, ToolType.select);
    });

    test('applyResult with null returns same state', () {
      final newState = state.applyResult(null);
      expect(identical(newState, state), isTrue);
    });

    test('applyResult preserves other fields when updating one', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = EditorState(
        scene: Scene().addElement(element),
        viewport: const ViewportState(offset: Offset(5, 5), zoom: 1.5),
        selectedIds: {const ElementId('r1')},
        activeToolType: ToolType.rectangle,
      );
      final newState =
          state.applyResult(SwitchToolResult(ToolType.select));
      expect(newState.scene.elements.length, 1);
      expect(newState.viewport.zoom, 1.5);
      expect(newState.selectedIds, {const ElementId('r1')});
      expect(newState.activeToolType, ToolType.select);
    });

    test('nested CompoundResult applies recursively', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      );
      final e2 = EllipseElement(
        id: const ElementId('e1'),
        x: 50,
        y: 50,
        width: 20,
        height: 20,
      );
      final compound = CompoundResult([
        CompoundResult([
          AddElementResult(e1),
          AddElementResult(e2),
        ]),
        SetSelectionResult({e1.id, e2.id}),
      ]);
      final newState = state.applyResult(compound);
      expect(newState.scene.elements.length, 2);
      expect(newState.selectedIds.length, 2);
    });

    test('copyWith creates new state with replaced fields', () {
      final newState = state.copyWith(activeToolType: ToolType.hand);
      expect(newState.activeToolType, ToolType.hand);
      expect(newState.scene, state.scene);
    });

    test('clipboard defaults to empty list', () {
      expect(state.clipboard, isEmpty);
    });

    test('applyResult with SetClipboardResult updates clipboard', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final newState =
          state.applyResult(SetClipboardResult([element]));
      expect(newState.clipboard, hasLength(1));
      expect(newState.clipboard.first.id, const ElementId('r1'));
    });

    test('SetClipboardResult preserves other state fields', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = EditorState(
        scene: Scene().addElement(element),
        viewport: const ViewportState(offset: Offset(5, 5), zoom: 1.5),
        selectedIds: {const ElementId('r1')},
        activeToolType: ToolType.rectangle,
      );
      final newState =
          state.applyResult(SetClipboardResult([element]));
      expect(newState.scene.elements.length, 1);
      expect(newState.viewport.zoom, 1.5);
      expect(newState.selectedIds, {const ElementId('r1')});
      expect(newState.activeToolType, ToolType.rectangle);
    });

    test('other applyResult branches preserve clipboard', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = state.applyResult(SetClipboardResult([element]));
      expect(state.clipboard, hasLength(1));

      // AddElement should preserve clipboard
      final newState = state.applyResult(AddElementResult(element));
      expect(newState.clipboard, hasLength(1));
    });

    test('clipboard survives through compound result', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      state = state.applyResult(SetClipboardResult([element]));

      final compound = CompoundResult([
        AddElementResult(element),
        SetSelectionResult({element.id}),
      ]);
      final newState = state.applyResult(compound);
      expect(newState.clipboard, hasLength(1));
    });

    test('SetClipboardResult in compound updates clipboard', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final compound = CompoundResult([
        SetClipboardResult([element]),
        AddElementResult(element),
      ]);
      final newState = state.applyResult(compound);
      expect(newState.clipboard, hasLength(1));
      expect(newState.scene.elements.length, 1);
    });

    group('toolLocked', () {
      test('defaults to false', () {
        expect(state.toolLocked, isFalse);
      });

      test('suppresses SwitchToolResult to select when toolLocked is true',
          () {
        state = state.copyWith(
          activeToolType: ToolType.rectangle,
          toolLocked: true,
        );
        final newState =
            state.applyResult(SwitchToolResult(ToolType.select));
        expect(newState.activeToolType, ToolType.rectangle);
      });

      test('allows SwitchToolResult to select when toolLocked is false', () {
        state = state.copyWith(activeToolType: ToolType.rectangle);
        final newState =
            state.applyResult(SwitchToolResult(ToolType.select));
        expect(newState.activeToolType, ToolType.select);
      });

      test('allows non-select SwitchToolResult when toolLocked is true', () {
        state = state.copyWith(
          activeToolType: ToolType.rectangle,
          toolLocked: true,
        );
        final newState =
            state.applyResult(SwitchToolResult(ToolType.hand));
        expect(newState.activeToolType, ToolType.hand);
      });
    });
  });
}
