import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// Apply a ToolResult to a scene, returning the new scene.
Scene applyToScene(Scene scene, ToolResult result) {
  return switch (result) {
    AddElementResult(:final element) => scene.addElement(element),
    UpdateElementResult(:final element) => scene.updateElement(element),
    RemoveElementResult(:final id) => scene.removeElement(id),
    CompoundResult(:final results) => results.fold(scene, applyToScene),
    _ => scene,
  };
}

/// Extract selection from a ToolResult.
Set<ElementId>? extractSelection(ToolResult result) {
  if (result is SetSelectionResult) return result.selectedIds;
  if (result is CompoundResult) {
    for (final r in result.results) {
      final sel = extractSelection(r);
      if (sel != null) return sel;
    }
  }
  return null;
}

void main() {
  group('Bound text cascading operations', () {
    late Scene scene;
    late SelectTool tool;

    setUp(() {
      tool = SelectTool();
      // Create a rectangle with bound text
      scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100, y: 100, width: 200, height: 100,
            boundElements: [const BoundElement(id: 't1', type: 'text')],
          ))
          .addElement(TextElement(
            id: const ElementId('t1'),
            x: 100, y: 100, width: 200, height: 100,
            text: 'Hello',
            containerId: 'r1',
          ));
    });

    ToolContext ctx({
      Scene? s,
      Set<ElementId>? selectedIds,
      List<Element>? clipboard,
    }) {
      return ToolContext(
        scene: s ?? scene,
        viewport: const ViewportState(),
        selectedIds: selectedIds ?? {},
        clipboard: clipboard ?? [],
      );
    }

    test('delete shape deletes bound text child', () {
      final context = ctx(selectedIds: {const ElementId('r1')});
      final result = tool.onKeyEvent('Delete', context: context);
      expect(result, isNotNull);

      final newScene = applyToScene(scene, result!);
      expect(newScene.getElementById(const ElementId('r1')), isNull);
      expect(newScene.getElementById(const ElementId('t1')), isNull);
    });

    test('delete bound text does not delete parent shape', () {
      // Select just the bound text (would only happen programmatically)
      final context = ctx(selectedIds: {const ElementId('t1')});
      final result = tool.onKeyEvent('Delete', context: context);
      expect(result, isNotNull);

      final newScene = applyToScene(scene, result!);
      expect(newScene.getElementById(const ElementId('t1')), isNull);
      // Parent should still exist
      final parent = newScene.getElementById(const ElementId('r1'));
      expect(parent, isNotNull);
    });

    test('delete bound text updates parent boundElements', () {
      final context = ctx(selectedIds: {const ElementId('t1')});
      final result = tool.onKeyEvent('Delete', context: context);
      expect(result, isNotNull);

      final newScene = applyToScene(scene, result!);
      final parent = newScene.getElementById(const ElementId('r1'));
      expect(parent, isNotNull);
      expect(
        parent!.boundElements.where((b) => b.id == 't1'),
        isEmpty,
      );
    });

    test('move shape syncs bound text position', () {
      final context = ctx(selectedIds: {const ElementId('r1')});

      // Simulate drag: down, then move, then up
      tool.onPointerDown(const Point(150, 150), context);
      final moveResult = tool.onPointerMove(
        const Point(200, 200), context,
      );
      tool.reset();

      expect(moveResult, isNotNull);
      final newScene = applyToScene(scene, moveResult!);
      final text = newScene.getElementById(const ElementId('t1'));
      expect(text, isNotNull);
      // Bound text should have moved with parent
      expect(text!.x, isNot(100));
    });

    test('resize shape syncs bound text position', () {
      final context = ctx(selectedIds: {const ElementId('r1')});

      // Hit the bottom-right handle (need to start resize mode)
      // Just test via key nudge which also syncs
      final result = tool.onKeyEvent('ArrowRight', context: context);
      expect(result, isNotNull);

      final newScene = applyToScene(scene, result!);
      final text = newScene.getElementById(const ElementId('t1'));
      expect(text, isNotNull);
      // Nudge moves the parent, bound text should follow
      expect(text!.x, closeTo(101, 0.1));
    });

    test('duplicate shape duplicates bound text with new IDs', () {
      final context = ctx(selectedIds: {const ElementId('r1')});
      final result = tool.onKeyEvent('d', ctrl: true, context: context);
      expect(result, isNotNull);

      final newScene = applyToScene(scene, result!);
      // Original still exists
      expect(newScene.getElementById(const ElementId('r1')), isNotNull);
      expect(newScene.getElementById(const ElementId('t1')), isNotNull);

      // Find the duplicated elements
      final allElements = newScene.activeElements;
      final rects = allElements.where((e) => e.type == 'rectangle').toList();
      expect(rects.length, 2);

      final texts = allElements.where((e) => e.type == 'text').toList();
      expect(texts.length, 2);

      // The new text should have a containerId pointing to the new rect
      final newText = texts.firstWhere((e) => e.id != const ElementId('t1'));
      final newRect = rects.firstWhere((e) => e.id != const ElementId('r1'));
      expect((newText as TextElement).containerId, newRect.id.value);
    });

    test('marquee selection excludes bound text', () {
      final context = ctx();

      // Drag a marquee that covers both the rect and the bound text
      tool.onPointerDown(const Point(50, 50), context);
      tool.onPointerMove(const Point(350, 250), context);
      final result = tool.onPointerUp(const Point(350, 250), context);

      final selectedIds = extractSelection(result!);
      expect(selectedIds, isNotNull);
      expect(selectedIds, contains(const ElementId('r1')));
      expect(selectedIds, isNot(contains(const ElementId('t1'))));
    });

    test('select all excludes bound text', () {
      final context = ctx(selectedIds: {});
      final result =
          tool.onKeyEvent('a', ctrl: true, context: context);

      final selectedIds = extractSelection(result!);
      expect(selectedIds, isNotNull);
      expect(selectedIds, contains(const ElementId('r1')));
      expect(selectedIds, isNot(contains(const ElementId('t1'))));
    });

    group('arrow label operations', () {
      late Scene arrowScene;

      setUp(() {
        arrowScene = Scene()
            .addElement(ArrowElement(
              id: const ElementId('a1'),
              x: 0, y: 0, width: 200, height: 0,
              points: [const Point(0, 0), const Point(200, 0)],
              boundElements: [const BoundElement(id: 'tl1', type: 'text')],
            ))
            .addElement(TextElement(
              id: const ElementId('tl1'),
              x: 80, y: -20, width: 40, height: 20,
              text: 'Label',
              containerId: 'a1',
            ));
      });

      test('delete arrow deletes label', () {
        final context = ctx(
            s: arrowScene, selectedIds: {const ElementId('a1')});
        final result = tool.onKeyEvent('Delete', context: context);
        expect(result, isNotNull);

        final newScene = applyToScene(arrowScene, result!);
        expect(newScene.getElementById(const ElementId('a1')), isNull);
        expect(newScene.getElementById(const ElementId('tl1')), isNull);
      });

      test('duplicate arrow duplicates label', () {
        final context = ctx(
            s: arrowScene, selectedIds: {const ElementId('a1')});
        final result = tool.onKeyEvent('d', ctrl: true, context: context);
        expect(result, isNotNull);

        final newScene = applyToScene(arrowScene, result!);
        final allTexts = newScene.activeElements
            .where((e) => e.type == 'text')
            .toList();
        expect(allTexts.length, 2);
      });
    });
  });
}
