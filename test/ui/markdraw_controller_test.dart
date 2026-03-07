import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

Scene _sceneWithRect() {
  return Scene().addElement(
    RectangleElement(
      id: const ElementId('r1'),
      x: 0,
      y: 0,
      width: 100,
      height: 50,
    ),
  );
}

void main() {
  group('applyScene', () {
    test('pushes previous scene to undo stack', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final newScene = _sceneWithRect();
      controller.applyScene(newScene);

      expect(controller.historyManager.canUndo, isTrue);
      expect(controller.editorState.scene.activeElements.length, 1);
      expect(identical(controller.editorState.scene, newScene), isTrue);
    });

    test('followed by undo restores previous scene', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final original = controller.editorState.scene;
      controller.applyScene(_sceneWithRect());
      controller.undo();

      expect(controller.editorState.scene.activeElements.length, 0);
      expect(identical(controller.editorState.scene, original), isTrue);
    });

    test('clears selection', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );
      controller.applyResult(AddElementResult(rect));
      controller.applyResult(SetSelectionResult({rect.id}));
      expect(controller.editorState.selectedIds, isNotEmpty);

      controller.applyScene(Scene());
      expect(controller.editorState.selectedIds, isEmpty);
    });

    test('sets background color when provided', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.applyScene(Scene(), background: '#ff0000');
      expect(controller.canvasBackgroundColor, '#ff0000');
    });
  });

  group('undo triggers onSceneChanged', () {
    test('calls onSceneChanged callback', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      Scene? changedScene;
      controller.onSceneChanged = (scene) {
        changedScene = scene;
      };

      controller.applyScene(_sceneWithRect());
      changedScene = null;

      controller.undo();

      expect(changedScene, isNotNull);
      expect(changedScene!.activeElements.length, 0);
    });

    test('does not call onSceneChanged when nothing to undo', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      var called = false;
      controller.onSceneChanged = (_) {
        called = true;
      };

      controller.undo();
      expect(called, isFalse);
    });
  });

  group('redo triggers onSceneChanged', () {
    test('calls onSceneChanged callback', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      Scene? changedScene;
      controller.onSceneChanged = (scene) {
        changedScene = scene;
      };

      controller.applyScene(_sceneWithRect());
      controller.undo();
      changedScene = null;

      controller.redo();

      expect(changedScene, isNotNull);
      expect(changedScene!.activeElements.length, 1);
    });

    test('does not call onSceneChanged when nothing to redo', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      var called = false;
      controller.onSceneChanged = (_) {
        called = true;
      };

      controller.redo();
      expect(called, isFalse);
    });
  });
}
