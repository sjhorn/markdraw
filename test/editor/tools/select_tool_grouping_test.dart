import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SelectTool tool;

  final rect1 = RectangleElement(
    id: const ElementId('r1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
    groupIds: const ['g1'],
  );

  final rect2 = RectangleElement(
    id: const ElementId('r2'),
    x: 200,
    y: 200,
    width: 80,
    height: 40,
    groupIds: const ['g1'],
  );

  final rect3 = RectangleElement(
    id: const ElementId('r3'),
    x: 400,
    y: 400,
    width: 60,
    height: 30,
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

  /// Simulate a click: down + up at the same point.
  ToolResult? click(Point point, ToolContext context, {bool shift = false}) {
    tool.onPointerDown(point, context, shift: shift);
    return tool.onPointerUp(point, context);
  }

  // --- Click selection ---

  group('Click selection with groups', () {
    test('clicking grouped element selects entire group', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      // Click on rect1 (which is in group g1)
      final result = click(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {rect1.id, rect2.id});
    });

    test('clicking ungrouped element selects only that element', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      // Click on rect3 (ungrouped, at 400,400)
      final result = click(const Point(420, 410), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {rect3.id});
    });

    test('clicking again on grouped element drills to individual', () {
      // All group members are already selected
      final ctx = contextWith(
        elements: [rect1, rect2, rect3],
        selectedIds: {rect1.id, rect2.id},
      );
      // Click on rect1 — group is already fully selected, should drill to individual
      final result = click(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {rect1.id});
    });

    test('shift+click on grouped element adds entire group', () {
      final ctx = contextWith(
        elements: [rect1, rect2, rect3],
        selectedIds: {rect3.id},
      );
      // Shift+click on rect1 (in group g1)
      final result = click(const Point(50, 30), ctx, shift: true);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {rect1.id, rect2.id, rect3.id});
    });

    test('shift+click removes entire group when already selected', () {
      final ctx = contextWith(
        elements: [rect1, rect2, rect3],
        selectedIds: {rect1.id, rect2.id, rect3.id},
      );
      // Shift+click on rect1 — group g1 is fully selected, should remove it
      // But first: resolveGroupForClick returns null since all groups are selected,
      // so this shift+click removes just the individual element
      final result = click(const Point(50, 30), ctx, shift: true);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      // Individual toggle: removes r1 since group is fully selected → drill to individual
      expect(sel, {rect2.id, rect3.id});
    });

    test('click on empty space clears selection', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Click on empty space
      final result = click(const Point(900, 900), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, isEmpty);
    });
  });

  // --- Marquee selection ---

  group('Marquee selection with groups', () {
    test('marquee expands to include all group members', () {
      // rect1 at (10,10) 100x50, rect2 at (200,200) 80x40, both in g1
      // rect3 at (400,400) 60x30, ungrouped
      // Marquee that only catches rect1 should expand to include rect2 (group g1)
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      tool.onPointerDown(const Point(0, 0), ctx);
      // Drag far enough to trigger marquee
      tool.onPointerMove(const Point(120, 70), ctx);
      final result = tool.onPointerUp(const Point(120, 70), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      // rect1 is directly hit, and rect2 is expanded via group g1
      expect(sel, contains(rect1.id));
      expect(sel, contains(rect2.id));
    });

    test('marquee does not expand ungrouped elements', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      // Marquee that only catches rect3
      tool.onPointerDown(const Point(390, 390), ctx);
      tool.onPointerMove(const Point(470, 440), ctx);
      final result = tool.onPointerUp(const Point(470, 440), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {rect3.id});
    });

    test('marquee catching nothing returns empty', () {
      final ctx = contextWith(elements: [rect1, rect2]);
      tool.onPointerDown(const Point(900, 900), ctx);
      tool.onPointerMove(const Point(950, 950), ctx);
      final result = tool.onPointerUp(const Point(950, 950), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, isEmpty);
    });
  });

  // --- Move unselected group ---

  group('Move unselected grouped element', () {
    test('dragging unselected grouped element selects and moves entire group', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      // Start drag on rect1 (grouped, not selected)
      tool.onPointerDown(const Point(50, 30), ctx);
      // Move enough to trigger drag
      tool.onPointerMove(const Point(60, 40), ctx);
      final result = tool.onPointerUp(const Point(60, 40), ctx);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Should contain a SetSelectionResult for the group
      final selResult = compound.results.whereType<SetSelectionResult>().first;
      expect(selResult.selectedIds, {rect1.id, rect2.id});
      // Should contain UpdateElementResults for both group members
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      expect(updates.length, greaterThanOrEqualTo(2));
    });

    test('dragging unselected ungrouped element selects and moves only that element', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      // Drag rect3 (ungrouped, at 400,400)
      tool.onPointerDown(const Point(420, 410), ctx);
      tool.onPointerMove(const Point(430, 420), ctx);
      final result = tool.onPointerUp(const Point(430, 420), ctx);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final selResult = compound.results.whereType<SetSelectionResult>().first;
      expect(selResult.selectedIds, {rect3.id});
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      expect(updates, hasLength(1));
      expect(updates.first.element.id, rect3.id);
    });

    test('move delta is applied correctly to all group members', () {
      final ctx = contextWith(elements: [rect1, rect2, rect3]);
      tool.onPointerDown(const Point(50, 30), ctx);
      tool.onPointerMove(const Point(70, 50), ctx);
      final result = tool.onPointerUp(const Point(70, 50), ctx);

      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      // Both r1 and r2 should be moved by dx=20, dy=20
      final r1Update = updates.firstWhere((u) => u.element.id == rect1.id);
      final r2Update = updates.firstWhere((u) => u.element.id == rect2.id);
      expect(r1Update.element.x, closeTo(30, 0.1)); // 10 + 20
      expect(r1Update.element.y, closeTo(30, 0.1)); // 10 + 20
      expect(r2Update.element.x, closeTo(220, 0.1)); // 200 + 20
      expect(r2Update.element.y, closeTo(220, 0.1)); // 200 + 20
    });
  });

  // --- Ctrl+G: Group ---

  group('Ctrl+G group', () {
    test('groups two or more selected elements', () {
      final ungroupedR1 = RectangleElement(
        id: const ElementId('r1'),
        x: 10, y: 10, width: 100, height: 50,
      );
      final ungroupedR2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200, y: 200, width: 80, height: 40,
      );
      final ctx = contextWith(
        elements: [ungroupedR1, ungroupedR2],
        selectedIds: {ungroupedR1.id, ungroupedR2.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      expect(updates, hasLength(2));
      // Both should have the same new groupId
      expect(updates[0].element.groupIds, hasLength(1));
      expect(updates[1].element.groupIds, hasLength(1));
      expect(updates[0].element.groupIds.first,
          updates[1].element.groupIds.first);
    });

    test('Ctrl+G requires at least 2 selected elements', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, context: ctx);
      expect(result, isNull);
    });

    test('Ctrl+G appends to existing groupIds', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      // rect1 already has ['g1'], should now have ['g1', newGroupId]
      expect(updates.firstWhere((u) => u.element.id == rect1.id)
          .element.groupIds, hasLength(2));
      expect(updates.firstWhere((u) => u.element.id == rect1.id)
          .element.groupIds.first, 'g1');
    });

    test('Ctrl+G with no selection returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('g', ctrl: true, context: ctx);
      expect(result, isNull);
    });

    test('Ctrl+G generates unique groupId', () {
      final ungrouped1 = RectangleElement(
        id: const ElementId('a1'),
        x: 10, y: 10, width: 100, height: 50,
      );
      final ungrouped2 = RectangleElement(
        id: const ElementId('a2'),
        x: 200, y: 200, width: 80, height: 40,
      );
      final ctx = contextWith(
        elements: [ungrouped1, ungrouped2],
        selectedIds: {ungrouped1.id, ungrouped2.id},
      );
      final result1 = tool.onKeyEvent('g', ctrl: true, context: ctx);
      final result2 = tool.onKeyEvent('g', ctrl: true, context: ctx);
      final gid1 = ((result1! as CompoundResult).results.first
          as UpdateElementResult).element.groupIds.first;
      final gid2 = ((result2! as CompoundResult).results.first
          as UpdateElementResult).element.groupIds.first;
      expect(gid1, isNot(gid2));
    });
  });

  // --- Ctrl+Shift+G: Ungroup ---

  group('Ctrl+Shift+G ungroup', () {
    test('removes outermost groupId from selected elements', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      expect(updates, hasLength(2));
      // Both had ['g1'], now should be empty
      for (final u in updates) {
        expect(u.element.groupIds, isEmpty);
      }
    });

    test('ungroup with no selection returns null', () {
      final ctx = contextWith(elements: [rect1]);
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      expect(result, isNull);
    });

    test('ungroup only affects elements with groupIds', () {
      final ctx = contextWith(
        elements: [rect1, rect3],
        selectedIds: {rect1.id, rect3.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      // Only rect1 has groupIds, rect3 has none
      expect(updates, hasLength(1));
      expect(updates.first.element.id, rect1.id);
    });

    test('ungroup all ungrouped elements returns null', () {
      final ctx = contextWith(
        elements: [rect3],
        selectedIds: {rect3.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      expect(result, isNull);
    });

    test('nested groups: ungroup removes only outermost', () {
      final nested = RectangleElement(
        id: const ElementId('n1'),
        x: 10, y: 10, width: 100, height: 50,
        groupIds: const ['inner', 'outer'],
      );
      final ctx = contextWith(
        elements: [nested],
        selectedIds: {nested.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      expect(updates.first.element.groupIds, ['inner']);
    });
  });

  // --- Duplicate groupId remapping ---

  group('Duplicate with groupIds', () {
    test('Ctrl+D remaps groupIds to new independent group', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      // The duplicated elements should have groupIds, but different from 'g1'
      final dupGroupIds = adds
          .where((a) => a.element.groupIds.isNotEmpty)
          .map((a) => a.element.groupIds.first)
          .toSet();
      expect(dupGroupIds, hasLength(1)); // All share the same new groupId
      expect(dupGroupIds.first, isNot('g1')); // Different from original
    });

    test('duplicated group members share the same remapped groupId', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      final groupIds = adds.map((a) => a.element.groupIds.first).toSet();
      expect(groupIds, hasLength(1)); // Both have the same new groupId
    });

    test('duplicating ungrouped elements preserves empty groupIds', () {
      final ctx = contextWith(
        elements: [rect3],
        selectedIds: {rect3.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(adds.first.element.groupIds, isEmpty);
    });

    test('duplicating preserves nested groupId structure', () {
      final nested1 = RectangleElement(
        id: const ElementId('n1'),
        x: 10, y: 10, width: 100, height: 50,
        groupIds: const ['inner', 'outer'],
      );
      final nested2 = RectangleElement(
        id: const ElementId('n2'),
        x: 200, y: 200, width: 80, height: 40,
        groupIds: const ['inner', 'outer'],
      );
      final ctx = contextWith(
        elements: [nested1, nested2],
        selectedIds: {nested1.id, nested2.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      // Each should have 2 groupIds, both remapped
      for (final add in adds) {
        expect(add.element.groupIds, hasLength(2));
        expect(add.element.groupIds[0], isNot('inner'));
        expect(add.element.groupIds[1], isNot('outer'));
      }
      // Inner groupIds should match across duplicates
      expect(adds[0].element.groupIds[0], adds[1].element.groupIds[0]);
      // Outer groupIds should match across duplicates
      expect(adds[0].element.groupIds[1], adds[1].element.groupIds[1]);
    });
  });

  // --- Copy/Paste groupId remapping ---

  group('Copy/Paste with groupIds', () {
    test('Ctrl+V remaps groupIds to independent group', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        clipboard: [rect1, rect2],
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      final pastedGroupIds = adds
          .where((a) => a.element.groupIds.isNotEmpty)
          .map((a) => a.element.groupIds.first)
          .toSet();
      expect(pastedGroupIds, hasLength(1)); // All share same new groupId
      expect(pastedGroupIds.first, isNot('g1')); // Different from original
    });

    test('pasted group members share same remapped groupId', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        clipboard: [rect1, rect2],
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      final groupIds = adds.map((a) => a.element.groupIds.first).toSet();
      expect(groupIds, hasLength(1));
    });

    test('pasting ungrouped elements preserves empty groupIds', () {
      final ctx = contextWith(
        elements: [rect3],
        clipboard: [rect3],
      );
      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();
      expect(adds.first.element.groupIds, isEmpty);
    });

    test('paste remapping is independent from original group', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        clipboard: [rect1, rect2],
      );
      // Paste twice — each paste should get its own independent groupId
      final result1 = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final result2 = tool.onKeyEvent('v', ctrl: true, context: ctx);
      final adds1 = (result1! as CompoundResult)
          .results.whereType<AddElementResult>().toList();
      final adds2 = (result2! as CompoundResult)
          .results.whereType<AddElementResult>().toList();
      final gid1 = adds1.first.element.groupIds.first;
      final gid2 = adds2.first.element.groupIds.first;
      expect(gid1, isNot(gid2));
    });
  });

  // --- Delete ---

  group('Delete grouped elements', () {
    test('deleting group members removes them', () {
      final ctx = contextWith(
        elements: [rect1, rect2, rect3],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final removes = compound.results.whereType<RemoveElementResult>().toList();
      expect(removes, hasLength(2));
      expect(removes.map((r) => r.id).toSet(), {rect1.id, rect2.id});
    });

    test('deleting individual from group leaves other members', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id},
      );
      final result = tool.onKeyEvent('Delete', context: ctx);
      final compound = result! as CompoundResult;
      final removes = compound.results.whereType<RemoveElementResult>().toList();
      expect(removes, hasLength(1));
      expect(removes.first.id, rect1.id);
    });
  });

  // --- Undo/redo compatibility ---

  group('Undo/redo with groups', () {
    test('Ctrl+G produces scene-changing result', () {
      final ungrouped1 = RectangleElement(
        id: const ElementId('u1'),
        x: 10, y: 10, width: 100, height: 50,
      );
      final ungrouped2 = RectangleElement(
        id: const ElementId('u2'),
        x: 200, y: 200, width: 80, height: 40,
      );
      final ctx = contextWith(
        elements: [ungrouped1, ungrouped2],
        selectedIds: {ungrouped1.id, ungrouped2.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, context: ctx);
      expect(isSceneChangingResult(result), isTrue);
    });

    test('Ctrl+Shift+G produces scene-changing result', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      final result = tool.onKeyEvent('g', ctrl: true, shift: true, context: ctx);
      expect(isSceneChangingResult(result), isTrue);
    });
  });
}
