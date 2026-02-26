import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SelectTool tool;

  final lockedRect = RectangleElement(
    id: const ElementId('lr1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
    locked: true,
  );

  final unlockedRect = RectangleElement(
    id: const ElementId('ur1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
  );

  final unlockedRect2 = RectangleElement(
    id: const ElementId('ur2'),
    x: 200,
    y: 200,
    width: 80,
    height: 40,
  );

  setUp(() {
    tool = SelectTool();
  });

  ToolContext contextWith({
    List<Element> elements = const [],
    Set<ElementId> selectedIds = const {},
    List<Element> clipboard = const [],
  }) {
    var scene = Scene();
    for (final e in elements) {
      scene = scene.addElement(e);
    }
    return ToolContext(
      scene: scene,
      viewport: const ViewportState(),
      selectedIds: selectedIds,
      clipboard: clipboard,
    );
  }

  group('SelectTool — locked element selection', () {
    test('click on locked element selects it', () {
      final ctx = contextWith(elements: [lockedRect]);
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, {lockedRect.id});
    });

    test('marquee includes locked elements', () {
      final ctx = contextWith(elements: [lockedRect, unlockedRect2]);
      // Marquee that covers both elements
      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerMove(const Point(300, 300), ctx);
      final result = tool.onPointerUp(const Point(300, 300), ctx);
      expect(result, isA<SetSelectionResult>());
      final ids = (result! as SetSelectionResult).selectedIds;
      expect(ids, contains(unlockedRect2.id));
      expect(ids, contains(lockedRect.id));
    });

    test('Ctrl+A includes locked elements', () {
      final ctx = contextWith(elements: [lockedRect, unlockedRect2]);
      final result = tool.onKeyEvent('a', ctrl: true, context: ctx);
      expect(result, isA<SetSelectionResult>());
      final ids = (result! as SetSelectionResult).selectedIds;
      expect(ids, contains(unlockedRect2.id));
      expect(ids, contains(lockedRect.id));
    });

    test('shift+click on locked element toggles selection', () {
      final ctx = contextWith(
        elements: [lockedRect, unlockedRect2],
        selectedIds: {unlockedRect2.id},
      );
      // Shift+click on locked element — should add it to selection
      tool.onPointerDown(const Point(50, 30), ctx, shift: true);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      final ids = (result! as SetSelectionResult).selectedIds;
      expect(ids, contains(lockedRect.id));
      expect(ids, contains(unlockedRect2.id));
    });

    test('dragging locked element does not move it', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      tool.onPointerDown(const Point(50, 30), ctx);
      // Drag far enough to trigger drag mode
      final moveResult = tool.onPointerMove(const Point(200, 200), ctx);
      // Should return null (no move applied)
      expect(moveResult, isNull);
      // Should NOT have a marquee overlay either
      final overlay = tool.overlay;
      expect(overlay?.marqueeRect, isNull);
    });
  });

  group('SelectTool — locked element transform blocking', () {
    test('delete with locked elements in selection only deletes unlocked', () {
      final ctx = contextWith(
        elements: [lockedRect, unlockedRect2],
        selectedIds: {lockedRect.id, unlockedRect2.id},
      );
      final result =
          tool.onKeyEvent('Delete', ctrl: false, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Should have RemoveElementResult for unlocked only
      final removeResults = compound.results
          .whereType<RemoveElementResult>()
          .toList();
      expect(removeResults.length, 1);
      expect(removeResults.first.id, unlockedRect2.id);
      // Locked element should NOT be removed
      expect(
        removeResults.any((r) => r.id == lockedRect.id),
        isFalse,
      );
    });

    test('delete with only locked elements returns null', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      final result =
          tool.onKeyEvent('Delete', ctrl: false, context: ctx);
      expect(result, isNull);
    });

    test('cut with locked elements only cuts unlocked', () {
      final ctx = contextWith(
        elements: [lockedRect, unlockedRect2],
        selectedIds: {lockedRect.id, unlockedRect2.id},
      );
      final result =
          tool.onKeyEvent('x', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final removeResults = compound.results
          .whereType<RemoveElementResult>()
          .toList();
      // Only unlocked should be removed
      expect(removeResults.length, 1);
      expect(removeResults.first.id, unlockedRect2.id);
      // Clipboard should contain only unlocked
      final clipResults = compound.results
          .whereType<SetClipboardResult>()
          .toList();
      expect(clipResults.length, 1);
    });

    test('nudge with locked element in selection returns null', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      final result =
          tool.onKeyEvent('ArrowRight', ctrl: false, context: ctx);
      expect(result, isNull);
    });

    test('nudge with mixed selection returns null', () {
      final ctx = contextWith(
        elements: [lockedRect, unlockedRect2],
        selectedIds: {lockedRect.id, unlockedRect2.id},
      );
      final result =
          tool.onKeyEvent('ArrowRight', ctrl: false, context: ctx);
      expect(result, isNull);
    });

    test('resize handles not hit-testable on locked elements', () {
      // Select a locked element, then click where a handle would be
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      // Top-left corner handle position
      tool.onPointerDown(const Point(10, 10), ctx);
      // Drag to resize
      tool.onPointerMove(const Point(5, 5), ctx);
      final result = tool.onPointerUp(const Point(5, 5), ctx);
      // Should select the element (click), NOT resize
      expect(result, isA<SetSelectionResult>());
    });
  });

  group('SelectTool — Ctrl+Shift+L lock toggle', () {
    test('Ctrl+Shift+L locks selected elements and clears selection', () {
      final ctx = contextWith(
        elements: [unlockedRect, unlockedRect2],
        selectedIds: {unlockedRect.id, unlockedRect2.id},
      );
      final result =
          tool.onKeyEvent('l', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results
          .whereType<UpdateElementResult>()
          .toList();
      expect(updates.length, 2);
      for (final u in updates) {
        expect(u.element.locked, isTrue);
      }
      // Should clear selection
      final selectionResults = compound.results
          .whereType<SetSelectionResult>()
          .toList();
      expect(selectionResults.length, 1);
      expect(selectionResults.first.selectedIds, isEmpty);
    });

    test('Ctrl+Shift+L unlocks locked elements and keeps selection', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      final result =
          tool.onKeyEvent('l', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results
          .whereType<UpdateElementResult>()
          .toList();
      expect(updates.length, 1);
      expect(updates.first.element.locked, isFalse);
      // Should NOT clear selection (unlocking keeps selection)
      final selectionResults = compound.results
          .whereType<SetSelectionResult>()
          .toList();
      expect(selectionResults, isEmpty);
    });

    test('Ctrl+Shift+L with no selection returns null', () {
      final ctx = contextWith(elements: [unlockedRect]);
      final result =
          tool.onKeyEvent('l', ctrl: true, shift: true, context: ctx);
      expect(result, isNull);
    });

    test('Ctrl+Shift+L with mixed locks all and clears selection', () {
      final ctx = contextWith(
        elements: [lockedRect, unlockedRect2],
        selectedIds: {lockedRect.id, unlockedRect2.id},
      );
      final result =
          tool.onKeyEvent('l', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Mixed: not allLocked → lock all, clear selection
      final updates = compound.results
          .whereType<UpdateElementResult>()
          .toList();
      expect(updates.length, 2);
      for (final u in updates) {
        expect(u.element.locked, isTrue);
      }
      final selectionResults = compound.results
          .whereType<SetSelectionResult>()
          .toList();
      expect(selectionResults.length, 1);
      expect(selectionResults.first.selectedIds, isEmpty);
    });
  });

  group('SelectTool — locked copy/duplicate allowed', () {
    test('copy locked elements is allowed', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      final result = tool.onKeyEvent('c', ctrl: true, context: ctx);
      expect(result, isA<SetClipboardResult>());
    });

    test('duplicate locked elements is allowed', () {
      final ctx = contextWith(
        elements: [lockedRect],
        selectedIds: {lockedRect.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final addResults = compound.results
          .whereType<AddElementResult>()
          .toList();
      expect(addResults.length, 1);
      // Duplicate retains lock status
      expect(addResults.first.element.locked, isTrue);
    });
  });

  group('Scene.getElementAtPoint — locked elements', () {
    test('returns locked element (selectable)', () {
      var scene = Scene();
      scene = scene.addElement(lockedRect);
      final hit = scene.getElementAtPoint(const Point(50, 30));
      expect(hit, isNotNull);
      expect(hit!.id, lockedRect.id);
    });
  });
}
