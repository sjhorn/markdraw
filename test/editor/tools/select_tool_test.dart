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
  );

  final rect2 = RectangleElement(
    id: const ElementId('r2'),
    x: 200,
    y: 200,
    width: 80,
    height: 40,
  );

  final line1 = LineElement(
    id: const ElementId('l1'),
    x: 300,
    y: 300,
    width: 100,
    height: 100,
    points: [const Point(0, 0), const Point(100, 100)],
  );

  setUp(() {
    tool = SelectTool();
  });

  ToolContext contextWith({
    List<Element> elements = const [],
    Set<ElementId> selectedIds = const {},
  }) {
    var scene = Scene();
    for (final e in elements) {
      scene = scene.addElement(e);
    }
    return ToolContext(
      scene: scene,
      viewport: const ViewportState(),
      selectedIds: selectedIds,
    );
  }

  group('SelectTool', () {
    test('type is select', () {
      expect(tool.type, ToolType.select);
    });

    test('click on element selects it', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, {rect1.id});
    });

    test('click on empty clears selection', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(500, 500), ctx);
      final result = tool.onPointerUp(const Point(500, 500), ctx);
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, isEmpty);
    });

    test('shift+click toggles element into selection', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id},
      );
      // Shift+click on rect2 — should add rect2 to selection
      tool.onPointerDown(const Point(220, 220), ctx, shift: true);
      final result = tool.onPointerUp(const Point(220, 220), ctx);
      expect(result, isA<SetSelectionResult>());
      expect(
          (result! as SetSelectionResult).selectedIds, {rect1.id, rect2.id});
    });

    test('shift+click toggles element out of selection', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Shift+click on rect1 — should remove rect1 from selection
      tool.onPointerDown(const Point(50, 30), ctx, shift: true);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, {rect2.id});
    });

    test('drag selected element moves it', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(50, 30), ctx);
      tool.onPointerMove(const Point(70, 50), ctx);
      final result = tool.onPointerUp(const Point(70, 50), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, rect1.x + 20); // dx = 70 - 50
      expect(updated.y, rect1.y + 20); // dy = 50 - 30
    });

    test('drag line element moves all points', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // Click near (but not at) the midpoint to avoid triggering midpoint insertion
      tool.onPointerDown(const Point(330, 330), ctx);
      tool.onPointerMove(const Point(350, 350), ctx);
      final result = tool.onPointerUp(const Point(350, 350), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, line1.x + 20);
      expect(updated.y, line1.y + 20);
    });

    test('drag on empty starts marquee', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(500, 500), ctx);
      tool.onPointerMove(const Point(600, 600), ctx);
      expect(tool.overlay, isNotNull);
      expect(tool.overlay!.marqueeRect, isNotNull);
      expect(tool.overlay!.marqueeRect!.left, 500);
      expect(tool.overlay!.marqueeRect!.top, 500);
    });

    test('up after marquee selects contained elements', () {
      // rect1 is at (10,10) 100x50 → right=110, bottom=60
      final ctx = contextWith(elements: [rect1, rect2]);
      // Marquee from (0,0) to (150,100) should contain rect1 but not rect2
      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerMove(const Point(150, 100), ctx);
      final result = tool.onPointerUp(const Point(150, 100), ctx);
      expect(result, isA<SetSelectionResult>());
      final selected = (result! as SetSelectionResult).selectedIds;
      expect(selected, contains(rect1.id));
      expect(selected, isNot(contains(rect2.id)));
    });

    test('escape clears selection', () {
      final result = tool.onKeyEvent('Escape');
      expect(result, isA<SetSelectionResult>());
      expect((result! as SetSelectionResult).selectedIds, isEmpty);
    });

    test('overlay is null before interaction', () {
      expect(tool.overlay, isNull);
    });

    test('reset clears state', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(500, 500), ctx);
      tool.onPointerMove(const Point(600, 600), ctx);
      tool.reset();
      expect(tool.overlay, isNull);
    });

    test('click same point without drag on selected does not move', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      // Should re-select, not produce an update
      expect(result, isA<SetSelectionResult>());
    });

    test('drag unselected element selects and moves it', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(50, 30), ctx);
      tool.onPointerMove(const Point(80, 60), ctx);
      final result = tool.onPointerUp(const Point(80, 60), ctx);
      // Should be a compound: select + move
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results[0], isA<SetSelectionResult>());
      expect(compound.results[1], isA<UpdateElementResult>());
    });

    test('small drag on element treated as click', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(52, 31), ctx);
      expect(result, isA<SetSelectionResult>());
    });

    test('marquee with negative direction normalizes', () {
      final ctx = contextWith(elements: [rect1]);
      // Drag from bottom-right to top-left
      tool.onPointerDown(const Point(150, 100), ctx);
      tool.onPointerMove(const Point(0, 0), ctx);
      final result = tool.onPointerUp(const Point(0, 0), ctx);
      expect(result, isA<SetSelectionResult>());
      final selected = (result! as SetSelectionResult).selectedIds;
      expect(selected, contains(rect1.id));
    });
  });

  group('SelectTool snap-to-close polygon', () {
    late SelectTool tool;

    setUp(() {
      tool = SelectTool();
    });

    ToolContext contextWith({
      required List<Element> elements,
      Set<ElementId> selectedIds = const {},
    }) {
      var scene = Scene();
      for (final e in elements) {
        scene = scene.addElement(e);
      }
      return ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: selectedIds,
      );
    }

    test('dragging last point near first point closes polygon', () {
      // Open triangle: points at (0,0), (100,0), (50,100)
      // Element at x=0, y=0
      final openLine = LineElement(
        id: const ElementId('ol1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
      );
      final ctx = contextWith(
        elements: [openLine],
        selectedIds: {openLine.id},
      );

      // Click on the last point (absolute: 50, 100)
      tool.onPointerDown(const Point(50, 100), ctx);
      // Drag it to (5, 5) — within 10px of first point (0, 0)
      tool.onPointerMove(const Point(5, 5), ctx);
      final result = tool.onPointerUp(const Point(5, 5), ctx);

      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.closed, isTrue);
      expect(updated.backgroundColor, '#a5d8ff');
      // The last point should be snapped to match the first point
      expect(updated.points.last, updated.points.first);
    });

    test('dragging first point near last point closes polygon', () {
      // Open triangle: points at (0,0), (100,0), (50,100)
      final openLine = LineElement(
        id: const ElementId('ol2'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
      );
      final ctx = contextWith(
        elements: [openLine],
        selectedIds: {openLine.id},
      );

      // Click on the first point (absolute: 0, 0)
      tool.onPointerDown(const Point(0, 0), ctx);
      // Drag it to (45, 95) — within 10px of last point (50, 100)
      tool.onPointerMove(const Point(45, 95), ctx);
      final result = tool.onPointerUp(const Point(45, 95), ctx);

      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.closed, isTrue);
      expect(updated.backgroundColor, '#a5d8ff');
      // The first point should be snapped to match the last point
      expect(updated.points.first, updated.points.last);
    });

    test('dragging endpoint not close enough stays open', () {
      final openLine = LineElement(
        id: const ElementId('ol3'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
      );
      final ctx = contextWith(
        elements: [openLine],
        selectedIds: {openLine.id},
      );

      // Click on last point (absolute: 50, 100)
      tool.onPointerDown(const Point(50, 100), ctx);
      // Drag to (20, 20) — more than 10px from first point (0, 0)
      tool.onPointerMove(const Point(20, 20), ctx);
      final result = tool.onPointerUp(const Point(20, 20), ctx);

      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.closed, isFalse);
    });

    test('arrow elements are not affected by snap-to-close', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
        endArrowhead: Arrowhead.arrow,
      );
      final ctx = contextWith(
        elements: [arrow],
        selectedIds: {arrow.id},
      );

      // Click on last point (absolute: 50, 100)
      tool.onPointerDown(const Point(50, 100), ctx);
      // Drag it to (3, 3) — very close to first point
      tool.onPointerMove(const Point(3, 3), ctx);
      final result = tool.onPointerUp(const Point(3, 3), ctx);

      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // Arrow should not get closed
      expect(updated, isA<ArrowElement>());
      expect((updated as LineElement).closed, isFalse);
    });

    test('line with fewer than 3 points does not snap-to-close', () {
      final shortLine = LineElement(
        id: const ElementId('sl1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: const [
          Point(0, 0),
          Point(100, 0),
        ],
      );
      final ctx = contextWith(
        elements: [shortLine],
        selectedIds: {shortLine.id},
      );

      // Click on last point (absolute: 100, 0)
      tool.onPointerDown(const Point(100, 0), ctx);
      // Drag to (5, 0) — close to first point
      tool.onPointerMove(const Point(5, 0), ctx);
      final result = tool.onPointerUp(const Point(5, 0), ctx);

      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.closed, isFalse);
    });
  });
}
