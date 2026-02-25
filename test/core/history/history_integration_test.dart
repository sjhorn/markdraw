import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// Helper to create a basic EditorState.
EditorState _baseState([Scene? scene]) => EditorState(
      scene: scene ?? Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
      activeToolType: ToolType.select,
    );

/// Helper to create a rectangle element.
RectangleElement _rect(String id,
        {double x = 0, double y = 0, double w = 100, double h = 50}) =>
    RectangleElement(
        id: ElementId(id), x: x, y: y, width: w, height: h);

void main() {
  group('Undo/Redo Integration', () {
    late HistoryManager history;
    late EditorState state;

    setUp(() {
      history = HistoryManager();
      state = _baseState();
    });

    /// Apply a result, pushing to history if scene-changing.
    EditorState applyWithHistory(
        EditorState s, HistoryManager h, ToolResult result) {
      if (isSceneChangingResult(result)) {
        h.push(s.scene);
      }
      return s.applyResult(result);
    }

    test('create element then undo removes it', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));
      expect(state.scene.activeElements, hasLength(1));

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.activeElements, isEmpty);
    });

    test('create element then undo then redo restores it', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.activeElements, isEmpty);

      final redone = history.redo(state.scene);
      state = state.copyWith(scene: redone!);
      expect(state.scene.activeElements, hasLength(1));
      expect(state.scene.activeElements.first.id, const ElementId('r1'));
    });

    test('move element then undo restores position', () {
      final rect = _rect('r1', x: 10, y: 20);
      state = applyWithHistory(state, history, AddElementResult(rect));

      final moved = rect.copyWith(x: 50, y: 60);
      state = applyWithHistory(state, history, UpdateElementResult(moved));
      expect(state.scene.getElementById(const ElementId('r1'))!.x, 50);

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.getElementById(const ElementId('r1'))!.x, 10);
    });

    test('resize element then undo restores bounds', () {
      final rect = _rect('r1', w: 100, h: 50);
      state = applyWithHistory(state, history, AddElementResult(rect));

      final resized = rect.copyWith(width: 200, height: 100);
      state = applyWithHistory(state, history, UpdateElementResult(resized));
      expect(state.scene.getElementById(const ElementId('r1'))!.width, 200);

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.getElementById(const ElementId('r1'))!.width, 100);
    });

    test('delete element then undo restores it', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));

      state = applyWithHistory(
          state, history, RemoveElementResult(const ElementId('r1')));
      expect(state.scene.activeElements, isEmpty);

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.activeElements, hasLength(1));
    });

    test('duplicate element then undo removes copy', () {
      final rect = _rect('r1', x: 10, y: 20);
      state = applyWithHistory(state, history, AddElementResult(rect));

      final copy = _rect('r1-copy', x: 20, y: 30);
      state = applyWithHistory(state, history, AddElementResult(copy));
      expect(state.scene.activeElements, hasLength(2));

      final undone = history.undo(state.scene);
      state = state.copyWith(scene: undone!);
      expect(state.scene.activeElements, hasLength(1));
      expect(state.scene.activeElements.first.id, const ElementId('r1'));
    });

    test('create two elements then undo twice removes both', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      state = applyWithHistory(state, history, AddElementResult(_rect('r2')));
      expect(state.scene.activeElements, hasLength(2));

      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.scene.activeElements, hasLength(1));
      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.scene.activeElements, isEmpty);
    });

    test('create two then undo twice then redo twice restores both', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      state = applyWithHistory(state, history, AddElementResult(_rect('r2')));

      state = state.copyWith(scene: history.undo(state.scene)!);
      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.scene.activeElements, isEmpty);

      state = state.copyWith(scene: history.redo(state.scene)!);
      expect(state.scene.activeElements, hasLength(1));
      state = state.copyWith(scene: history.redo(state.scene)!);
      expect(state.scene.activeElements, hasLength(2));
    });

    test('create then move then undo move — element at original position', () {
      final rect = _rect('r1', x: 10, y: 20);
      state = applyWithHistory(state, history, AddElementResult(rect));

      final moved = rect.copyWith(x: 50, y: 60);
      state = applyWithHistory(state, history, UpdateElementResult(moved));

      // Undo just the move
      state = state.copyWith(scene: history.undo(state.scene)!);
      final el = state.scene.getElementById(const ElementId('r1'))!;
      expect(el.x, 10);
      expect(el.y, 20);
      // Element still exists
      expect(state.scene.activeElements, hasLength(1));
    });

    test('create then move then undo then new action clears redo', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      final moved = _rect('r1', x: 50);
      state = applyWithHistory(state, history, UpdateElementResult(moved));

      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(history.canRedo, isTrue);

      // New action branches off
      state = applyWithHistory(state, history, AddElementResult(_rect('r2')));
      expect(history.canRedo, isFalse);
    });

    test('drag coalescing: single undo step for entire drag', () {
      final rect = _rect('r1', x: 10, y: 20);
      state = applyWithHistory(state, history, AddElementResult(rect));

      // Simulate drag: capture scene before drag, apply many moves, push once
      final sceneBeforeDrag = state.scene;

      // Many small moves (no history push during drag)
      for (var i = 1; i <= 10; i++) {
        final moved = rect.copyWith(x: 10.0 + i, y: 20.0 + i);
        state = state.applyResult(UpdateElementResult(moved));
      }

      // Push once at end of drag
      if (!identical(state.scene, sceneBeforeDrag)) {
        history.push(sceneBeforeDrag);
      }

      // Single undo should revert entire drag
      state = state.copyWith(scene: history.undo(state.scene)!);
      final el = state.scene.getElementById(const ElementId('r1'))!;
      expect(el.x, 10);
      expect(el.y, 20);
    });

    test('undo with empty history does nothing', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      // Clear history
      history.clear();
      final result = history.undo(state.scene);
      expect(result, isNull);
      // State unchanged
      expect(state.scene.activeElements, hasLength(1));
    });

    test('redo with empty history does nothing', () {
      final result = history.redo(state.scene);
      expect(result, isNull);
    });

    test('undo preserves selection', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));
      state = state.applyResult(
          SetSelectionResult({const ElementId('r1')}));

      state = state.copyWith(scene: history.undo(state.scene)!);
      // Selection preserved even though element was removed from scene
      expect(state.selectedIds, contains(const ElementId('r1')));
    });

    test('undo preserves viewport', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      state = state.applyResult(
          UpdateViewportResult(const ViewportState(
              offset: Offset(100, 200), zoom: 2.0)));

      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.viewport.offset, const Offset(100, 200));
      expect(state.viewport.zoom, 2.0);
    });

    test('undo preserves clipboard', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));
      state = state.applyResult(SetClipboardResult([rect]));

      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.clipboard, hasLength(1));
    });

    test('cut then undo restores elements but clipboard retained', () {
      final rect = _rect('r1');
      state = applyWithHistory(state, history, AddElementResult(rect));

      // Simulate cut: copy + remove (as a compound result, but for history
      // we push once before the compound)
      final cutResult = CompoundResult([
        SetClipboardResult([rect]),
        RemoveElementResult(const ElementId('r1')),
      ]);
      state = applyWithHistory(state, history, cutResult);
      expect(state.scene.activeElements, isEmpty);
      expect(state.clipboard, hasLength(1));

      // Undo restores element but clipboard is preserved
      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.scene.activeElements, hasLength(1));
      expect(state.clipboard, hasLength(1));
    });

    test('compound result (multi-element move) is a single undo step', () {
      state = applyWithHistory(state, history, AddElementResult(_rect('r1')));
      state = applyWithHistory(state, history, AddElementResult(_rect('r2')));

      // Move both elements in a single compound result
      final compound = CompoundResult([
        UpdateElementResult(
            _rect('r1', x: 50, y: 50)),
        UpdateElementResult(
            _rect('r2', x: 150, y: 150)),
      ]);
      state = applyWithHistory(state, history, compound);

      // Single undo reverts both moves
      state = state.copyWith(scene: history.undo(state.scene)!);
      expect(state.scene.getElementById(const ElementId('r1'))!.x, 0);
      expect(state.scene.getElementById(const ElementId('r2'))!.x, 0);
    });
  });
}
