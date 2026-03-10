import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FlowchartCreator', () {
    late FlowchartCreator creator;
    late RectangleElement startNode;
    late Scene scene;

    setUp(() {
      creator = FlowchartCreator();
      startNode = RectangleElement(
        id: const ElementId('start'),
        x: 100, y: 100, width: 200, height: 100,
      );
      scene = Scene().addElement(startNode);
    });

    test('initial state is not creating', () {
      expect(creator.isCreating, isFalse);
      expect(creator.pendingElements, isEmpty);
    });

    test('first Ctrl+Arrow creates 1 node + 1 arrow', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );

      expect(creator.isCreating, isTrue);
      expect(creator.pendingElements, hasLength(2));

      final node = creator.pendingElements[0];
      final arrow = creator.pendingElements[1];
      expect(node, isA<RectangleElement>());
      expect(arrow, isA<ArrowElement>());
    });

    test('same direction again creates 2 fanned nodes', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );

      expect(creator.pendingElements, hasLength(4)); // 2 nodes + 2 arrows
    });

    test('three presses creates 3 fanned nodes', () {
      for (var i = 0; i < 3; i++) {
        creator.createNodes(
          startNode: startNode,
          direction: LinkDirection.right,
          scene: scene,
        );
      }

      expect(creator.pendingElements, hasLength(6)); // 3 nodes + 3 arrows
    });

    test('different direction resets to 1 node', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );
      // Now switch direction
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.down,
        scene: scene,
      );

      expect(creator.pendingElements, hasLength(2)); // 1 node + 1 arrow
      final node = creator.pendingElements[0];
      // Node should be below, not to the right
      expect(node.y, greaterThan(startNode.y));
    });

    test('commit returns CompoundResult with all elements', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );

      final result = creator.commit();
      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;

      // Should have AddElementResult for node + arrow + SetSelectionResult
      final addResults = compound.results
          .whereType<AddElementResult>()
          .toList();
      expect(addResults, hasLength(2));

      final selectionResults = compound.results
          .whereType<SetSelectionResult>()
          .toList();
      expect(selectionResults, hasLength(1));
      // Selection should be the non-arrow element
      final selectedId = selectionResults.first.selectedIds.first;
      expect(selectedId, isNot(equals(addResults[1].element.id)));
    });

    test('commit clears state', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );
      creator.commit();

      expect(creator.isCreating, isFalse);
      expect(creator.pendingElements, isEmpty);
    });

    test('clear discards pending elements', () {
      creator.createNodes(
        startNode: startNode,
        direction: LinkDirection.right,
        scene: scene,
      );
      expect(creator.isCreating, isTrue);

      creator.clear();
      expect(creator.isCreating, isFalse);
      expect(creator.pendingElements, isEmpty);
    });
  });
}
