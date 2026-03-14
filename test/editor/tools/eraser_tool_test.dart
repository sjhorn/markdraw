import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late EraserTool tool;

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
    width: 100,
    height: 50,
  );

  final lockedRect = RectangleElement(
    id: const ElementId('lr1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
    locked: true,
  );

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

  setUp(() {
    tool = EraserTool();
  });

  group('EraserTool', () {
    test('type is eraser', () {
      expect(tool.type, ToolType.eraser);
    });

    test('click on empty space returns null', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(500, 500), ctx);
      final result = tool.onPointerUp(const Point(500, 500), ctx);
      expect(result, isNull);
    });

    test('click on element returns CompoundResult that removes it', () {
      final ctx = contextWith(elements: [rect1]);
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final removeResults = compound.results
          .whereType<RemoveElementResult>()
          .toList();
      expect(removeResults.any((r) => r.id == rect1.id), isTrue);
      // Should also clear selection
      final selResults = compound.results
          .whereType<SetSelectionResult>()
          .toList();
      expect(selResults, isNotEmpty);
      expect(selResults.last.selectedIds, isEmpty);
    });

    test('click on locked element does not erase it', () {
      final ctx = contextWith(elements: [lockedRect]);
      tool.onPointerDown(const Point(50, 30), ctx);
      final result = tool.onPointerUp(const Point(50, 30), ctx);
      expect(result, isNull);
    });

    test('drag across multiple elements erases all on pointer-up', () {
      final ctx = contextWith(elements: [rect1, rect2]);
      // Start on rect1
      tool.onPointerDown(const Point(50, 30), ctx);
      // Move to rect2
      tool.onPointerMove(const Point(250, 220), ctx);
      final result = tool.onPointerUp(const Point(250, 220), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final removeResults = compound.results
          .whereType<RemoveElementResult>()
          .toList();
      expect(removeResults.any((r) => r.id == rect1.id), isTrue);
      expect(removeResults.any((r) => r.id == rect2.id), isTrue);
    });

    test('drag skips locked elements', () {
      final unlocked = RectangleElement(
        id: const ElementId('u1'),
        x: 200,
        y: 200,
        width: 100,
        height: 50,
      );
      final ctx = contextWith(elements: [lockedRect, unlocked]);
      // Start on locked
      tool.onPointerDown(const Point(50, 30), ctx);
      // Move to unlocked
      tool.onPointerMove(const Point(250, 220), ctx);
      final result = tool.onPointerUp(const Point(250, 220), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final removeResults = compound.results
          .whereType<RemoveElementResult>()
          .toList();
      // Only unlocked element removed
      expect(removeResults.any((r) => r.id == unlocked.id), isTrue);
      expect(removeResults.any((r) => r.id == lockedRect.id), isFalse);
    });

    group('group expansion', () {
      test('erasing group member erases entire outermost group', () {
        final g1 = RectangleElement(
          id: const ElementId('g1'),
          x: 10,
          y: 10,
          width: 50,
          height: 50,
          groupIds: ['grp1'],
        );
        final g2 = RectangleElement(
          id: const ElementId('g2'),
          x: 100,
          y: 100,
          width: 50,
          height: 50,
          groupIds: ['grp1'],
        );
        final ctx = contextWith(elements: [g1, g2]);
        // Click on g1 only
        tool.onPointerDown(const Point(30, 30), ctx);
        final result = tool.onPointerUp(const Point(30, 30), ctx);
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final removeResults = compound.results
            .whereType<RemoveElementResult>()
            .toList();
        // Both group members should be removed
        expect(removeResults.any((r) => r.id == g1.id), isTrue);
        expect(removeResults.any((r) => r.id == g2.id), isTrue);
      });
    });

    group('cascading delete', () {
      test('deleting container deletes bound text', () {
        final container = RectangleElement(
          id: const ElementId('c1'),
          x: 10,
          y: 10,
          width: 100,
          height: 50,
          boundElements: [const BoundElement(id: 'bt1', type: 'text')],
        );
        final boundText = TextElement(
          id: const ElementId('bt1'),
          x: 20,
          y: 20,
          width: 80,
          height: 20,
          text: 'Hello',
          containerId: 'c1',
        );
        final ctx = contextWith(elements: [container, boundText]);
        tool.onPointerDown(const Point(50, 30), ctx);
        final result = tool.onPointerUp(const Point(50, 30), ctx);
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final removeResults = compound.results
            .whereType<RemoveElementResult>()
            .toList();
        expect(removeResults.any((r) => r.id == container.id), isTrue);
        expect(removeResults.any((r) => r.id == boundText.id), isTrue);
      });

      test('deleting frame releases children', () {
        final frame = FrameElement(
          id: const ElementId('f1'),
          x: 0,
          y: 0,
          width: 200,
          height: 200,
          label: 'Frame 1',
        );
        final child = RectangleElement(
          id: const ElementId('ch1'),
          x: 10,
          y: 10,
          width: 50,
          height: 50,
          frameId: 'f1',
        );
        final ctx = contextWith(elements: [frame, child]);
        tool.onPointerDown(const Point(5, 5), ctx);
        final result = tool.onPointerUp(const Point(5, 5), ctx);
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        // Frame removed
        final removeResults = compound.results
            .whereType<RemoveElementResult>()
            .toList();
        expect(removeResults.any((r) => r.id == frame.id), isTrue);
        // Child released (frameId cleared)
        final updateResults = compound.results
            .whereType<UpdateElementResult>()
            .toList();
        final releasedChild = updateResults
            .where((r) => r.element.id == child.id)
            .toList();
        expect(releasedChild, isNotEmpty);
        expect(releasedChild.first.element.frameId, isNull);
      });

      test('clears arrow bindings on deleted elements', () {
        final target = RectangleElement(
          id: const ElementId('t1'),
          x: 10,
          y: 10,
          width: 100,
          height: 50,
          boundElements: [const BoundElement(id: 'a1', type: 'arrow')],
        );
        // Arrow positioned far from target so click on target doesn't hit arrow
        final arrow = ArrowElement(
          id: const ElementId('a1'),
          x: 300,
          y: 300,
          width: 100,
          height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
          startBinding: const PointBinding(
            elementId: 't1',
            fixedPoint: Point(0.5, 0.5),
          ),
        );
        final ctx = contextWith(elements: [target, arrow]);
        // Click on target rect only
        tool.onPointerDown(const Point(50, 30), ctx);
        final result = tool.onPointerUp(const Point(50, 30), ctx);
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        // Target removed
        final removeResults = compound.results
            .whereType<RemoveElementResult>()
            .toList();
        expect(removeResults.any((r) => r.id == target.id), isTrue);
        // Arrow binding cleared
        final updateResults = compound.results
            .whereType<UpdateElementResult>()
            .toList();
        final updatedArrow = updateResults
            .where((r) => r.element.id == arrow.id)
            .toList();
        expect(updatedArrow, isNotEmpty);
        expect(
          (updatedArrow.first.element as ArrowElement).startBinding,
          isNull,
        );
      });
    });

    group('overlay', () {
      test('overlay is null when not dragging', () {
        expect(tool.overlay, isNull);
      });

      test('overlay has eraserElementIds during drag with hits', () {
        final ctx = contextWith(elements: [rect1]);
        tool.onPointerDown(const Point(50, 30), ctx);
        expect(tool.overlay, isNotNull);
        expect(tool.overlay!.eraserElementIds, contains(rect1.id));
      });

      test('overlay is null during drag with no hits', () {
        final ctx = contextWith(elements: [rect1]);
        tool.onPointerDown(const Point(500, 500), ctx);
        expect(tool.overlay, isNull);
      });
    });

    group('cancel', () {
      test('Escape cancels drag and returns null', () {
        final ctx = contextWith(elements: [rect1]);
        tool.onPointerDown(const Point(50, 30), ctx);
        expect(tool.overlay, isNotNull);
        final result = tool.onKeyEvent('Escape');
        expect(result, isNull);
        expect(tool.overlay, isNull);
      });

      test('reset clears state', () {
        final ctx = contextWith(elements: [rect1]);
        tool.onPointerDown(const Point(50, 30), ctx);
        tool.reset();
        expect(tool.overlay, isNull);
      });
    });
  });
}
