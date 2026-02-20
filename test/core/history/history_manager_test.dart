import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/history/history_manager.dart';
import 'package:markdraw/src/core/scene/scene.dart';

void main() {
  group('HistoryManager', () {
    late HistoryManager history;
    late Scene emptyScene;
    late Scene sceneWithRect;
    late Scene sceneWithTwo;

    setUp(() {
      history = HistoryManager();
      emptyScene = Scene();
      sceneWithRect = emptyScene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      ));
      sceneWithTwo = sceneWithRect.addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 200,
        width: 80,
        height: 60,
      ));
    });

    test('canUndo and canRedo are false initially', () {
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('push makes canUndo true', () {
      history.push(emptyScene);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('undo returns previous scene', () {
      history.push(emptyScene);
      final result = history.undo(sceneWithRect);
      expect(identical(result, emptyScene), isTrue);
    });

    test('undo moves current to redo stack', () {
      history.push(emptyScene);
      history.undo(sceneWithRect);
      expect(history.canRedo, isTrue);
      expect(history.canUndo, isFalse);
    });

    test('redo returns the undone scene', () {
      history.push(emptyScene);
      history.undo(sceneWithRect);
      final result = history.redo(emptyScene);
      expect(identical(result, sceneWithRect), isTrue);
    });

    test('redo moves current to undo stack', () {
      history.push(emptyScene);
      history.undo(sceneWithRect);
      history.redo(emptyScene);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('push clears redo stack', () {
      history.push(emptyScene);
      history.undo(sceneWithRect);
      expect(history.canRedo, isTrue);
      history.push(sceneWithRect);
      expect(history.canRedo, isFalse);
    });

    test('multiple push/undo restores in reverse order', () {
      history.push(emptyScene);
      history.push(sceneWithRect);
      history.push(sceneWithTwo);

      final current3 = Scene(); // current scene after all pushes
      final result1 = history.undo(current3);
      expect(identical(result1, sceneWithTwo), isTrue);

      final result2 = history.undo(result1!);
      expect(identical(result2, sceneWithRect), isTrue);

      final result3 = history.undo(result2!);
      expect(identical(result3, emptyScene), isTrue);
    });

    test('undo when empty returns null', () {
      expect(history.undo(emptyScene), isNull);
    });

    test('redo when empty returns null', () {
      expect(history.redo(emptyScene), isNull);
    });

    test('undo then redo round-trip preserves identity', () {
      history.push(emptyScene);
      final afterUndo = history.undo(sceneWithRect);
      expect(identical(afterUndo, emptyScene), isTrue);
      final afterRedo = history.redo(afterUndo!);
      expect(identical(afterRedo, sceneWithRect), isTrue);
    });

    test('maxDepth limits undo stack and drops oldest', () {
      final manager = HistoryManager(maxDepth: 3);
      final s1 = Scene();
      final s2 = Scene();
      final s3 = Scene();
      final s4 = Scene();

      manager.push(s1);
      manager.push(s2);
      manager.push(s3);
      expect(manager.undoCount, 3);

      manager.push(s4);
      expect(manager.undoCount, 3); // oldest (s1) dropped

      // Undo three times: should get s4, s3, s2 (not s1)
      final r1 = manager.undo(Scene());
      expect(identical(r1, s4), isTrue);
      final r2 = manager.undo(r1!);
      expect(identical(r2, s3), isTrue);
      final r3 = manager.undo(r2!);
      expect(identical(r3, s2), isTrue);
      expect(manager.undo(r3!), isNull); // s1 was dropped
    });

    test('clear empties both stacks', () {
      history.push(emptyScene);
      history.push(sceneWithRect);
      history.undo(sceneWithTwo);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isTrue);

      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);
    });

    test('undoCount and redoCount are correct', () {
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);

      history.push(emptyScene);
      expect(history.undoCount, 1);
      expect(history.redoCount, 0);

      history.push(sceneWithRect);
      expect(history.undoCount, 2);
      expect(history.redoCount, 0);

      history.undo(sceneWithTwo);
      expect(history.undoCount, 1);
      expect(history.redoCount, 1);

      history.undo(sceneWithRect);
      expect(history.undoCount, 0);
      expect(history.redoCount, 2);
    });

    test('multiple undo then multiple redo restores forward', () {
      history.push(emptyScene);
      history.push(sceneWithRect);

      final current = sceneWithTwo;
      final u1 = history.undo(current);
      final u2 = history.undo(u1!);
      expect(identical(u2, emptyScene), isTrue);

      final r1 = history.redo(u2!);
      expect(identical(r1, u1), isTrue);
      final r2 = history.redo(r1!);
      expect(identical(r2, current), isTrue);
    });

    test('push after partial undo clears redo (branch divergence)', () {
      history.push(emptyScene);
      history.push(sceneWithRect);
      history.push(sceneWithTwo);

      // Undo twice
      history.undo(Scene());
      history.undo(sceneWithTwo);
      expect(history.redoCount, 2);

      // New action branches off
      final newScene = Scene();
      history.push(newScene);
      expect(history.redoCount, 0); // redo stack cleared
      expect(history.undoCount, 2); // emptyScene + newScene
    });

    test('default maxDepth is 100', () {
      final manager = HistoryManager();
      for (var i = 0; i < 100; i++) {
        manager.push(Scene());
      }
      expect(manager.undoCount, 100);
      manager.push(Scene());
      expect(manager.undoCount, 100); // capped at 100
    });

    test('maxDepth of 1 keeps only the last push', () {
      final manager = HistoryManager(maxDepth: 1);
      final s1 = Scene();
      final s2 = Scene();
      manager.push(s1);
      manager.push(s2);
      expect(manager.undoCount, 1);
      final result = manager.undo(Scene());
      expect(identical(result, s2), isTrue);
      expect(manager.undo(result!), isNull);
    });
  });
}
