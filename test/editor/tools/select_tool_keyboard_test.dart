import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late SelectTool tool;

  final rect1 = RectangleElement(
    id: const ElementId('r1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
  );

  final rect2 = RectangleElement(
    id: const ElementId('r2'),
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

  group('Delete', () {
    test('delete removes single selected element', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results[0], isA<RemoveElementResult>());
      expect((compound.results[0] as RemoveElementResult).id, rect1.id);
      // Should also clear selection
      expect(compound.results.last, isA<SetSelectionResult>());
      expect(
          (compound.results.last as SetSelectionResult).selectedIds, isEmpty);
    });

    test('delete removes all selected elements (multi)', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Should have 2 RemoveElementResults + 1 SetSelectionResult
      final removes =
          compound.results.whereType<RemoveElementResult>().toList();
      expect(removes, hasLength(2));
      expect(removes.map((r) => r.id).toSet(), {rect1.id, rect2.id});
    });

    test('delete with nothing selected returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isNull);
    });

    test('backspace also deletes', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('Backspace', context: ctx);
      expect(result, isA<CompoundResult>());
    });
  });

  group('Duplicate', () {
    test('ctrl+d creates new elements at offset', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(adds, hasLength(1));
      expect(adds.first.element.x, rect1.x + 10);
      expect(adds.first.element.y, rect1.y + 10);
      // New ID
      expect(adds.first.element.id, isNot(rect1.id));
    });

    test('duplicate preserves element properties', () {
      final coloredRect = RectangleElement(
        id: const ElementId('cr1'),
        x: 10,
        y: 10,
        width: 100,
        height: 50,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        opacity: 0.5,
      );
      final ctx = contextWith(
        elements: [coloredRect],
        selectedIds: {coloredRect.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final added = compound.results.whereType<AddElementResult>().first;
      expect(added.element.strokeColor, '#ff0000');
      expect(added.element.backgroundColor, '#00ff00');
      expect(added.element.opacity, 0.5);
      expect(added.element.width, 100);
      expect(added.element.height, 50);
    });

    test('duplicate selects newly created elements', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final selection =
          compound.results.whereType<SetSelectionResult>().first;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(selection.selectedIds, hasLength(2));
      for (final add in adds) {
        expect(selection.selectedIds, contains(add.element.id));
      }
    });
  });

  group('Select All', () {
    test('ctrl+a selects all non-deleted elements', () {
      final ctx = contextWith(elements: [rect1, rect2]);
      final result = tool.onKeyEvent('a', ctrl: true, context: ctx);
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds,
          {rect1.id, rect2.id});
    });
  });

  group('Arrow key nudge', () {
    test('arrow right nudges x+1', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('ArrowRight', context: ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, rect1.x + 1);
      expect(updated.y, rect1.y);
    });

    test('arrow left nudges x-1', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('ArrowLeft', context: ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, rect1.x - 1);
    });

    test('arrow up nudges y-1', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('ArrowUp', context: ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.y, rect1.y - 1);
    });

    test('arrow down nudges y+1', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('ArrowDown', context: ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.y, rect1.y + 1);
    });

    test('shift+arrow right nudges x+10', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result =
          tool.onKeyEvent('ArrowRight', shift: true, context: ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, rect1.x + 10);
    });

    test('nudge all selected elements', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('ArrowRight', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        if (updated.id == rect1.id) {
          expect(updated.x, rect1.x + 1);
        } else {
          expect(updated.x, rect2.x + 1);
        }
      }
    });

    test('nudge with nothing selected returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('ArrowRight', context: ctx);
      expect(result, isNull);
    });
  });

  group('Copy/Paste/Cut', () {
    test('ctrl+c copies elements to clipboard', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('c', ctrl: true, context: ctx);
      expect(result, isA<SetClipboardResult>());
      final clipboard = (result! as SetClipboardResult).elements;
      expect(clipboard, hasLength(1));
      expect(clipboard.first.id, rect1.id);
    });

    test('ctrl+v pastes from clipboard with new IDs', () {
      final ctx = contextWith(
        elements: [rect1],
        clipboard: [rect1],
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(adds, hasLength(1));
      expect(adds.first.element.id, isNot(rect1.id));
      expect(adds.first.element.x, rect1.x + 10);
      expect(adds.first.element.y, rect1.y + 10);
    });

    test('paste preserves element properties', () {
      final ctx = contextWith(
        elements: [rect1],
        clipboard: [rect1],
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final added = compound.results.whereType<AddElementResult>().first;
      expect(added.element.width, rect1.width);
      expect(added.element.height, rect1.height);
      expect(added.element.strokeColor, rect1.strokeColor);
    });

    test('ctrl+x cuts: removes originals and stores in clipboard', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('x', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Should have: SetClipboard, RemoveElement, SetSelection
      expect(compound.results.whereType<SetClipboardResult>().length, 1);
      expect(compound.results.whereType<RemoveElementResult>().length, 1);
      expect(compound.results.whereType<SetSelectionResult>().length, 1);
    });

    test('paste after cut restores at offset', () {
      // Simulate: cut rect1, then paste
      final ctx = contextWith(
        clipboard: [rect1], // as if cut had stored it
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(adds, hasLength(1));
      expect(adds.first.element.x, rect1.x + 10);
      expect(adds.first.element.y, rect1.y + 10);
    });

    test('empty clipboard paste returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      expect(result, isNull);
    });

    test('multiple pastes create distinct copies', () {
      final ctx = contextWith(clipboard: [rect1]);
      final result1 = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final result2 = tool.onKeyEvent('v', ctrl: true, context: ctx);

      final adds1 = (result1! as CompoundResult)
          .results
          .whereType<AddElementResult>()
          .toList();
      final adds2 = (result2! as CompoundResult)
          .results
          .whereType<AddElementResult>()
          .toList();

      // Different IDs each paste
      expect(adds1.first.element.id, isNot(adds2.first.element.id));
    });

    test('copy with nothing selected returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('c', ctrl: true, context: ctx);
      expect(result, isNull);
    });
  });

  group('Escape', () {
    test('escape clears selection without context', () {
      final result = tool.onKeyEvent('Escape');
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, isEmpty);
    });
  });
}
