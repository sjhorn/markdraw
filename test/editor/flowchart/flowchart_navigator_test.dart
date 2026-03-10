import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FlowchartNavigator', () {
    late FlowchartNavigator navigator;

    setUp(() {
      navigator = FlowchartNavigator();
    });

    test('initial state is not exploring', () {
      expect(navigator.isExploring, isFalse);
    });

    test('navigates to connected node in direction', () {
      final start = RectangleElement(
        id: const ElementId('start'),
        x: 0, y: 0, width: 100, height: 50,
      );
      final end = RectangleElement(
        id: const ElementId('end'),
        x: 200, y: 0, width: 100, height: 50,
      );
      final arrow = FlowchartUtils.createBindingArrow(
        start, end, LinkDirection.right,
      );

      final scene = Scene()
          .addElement(start)
          .addElement(end)
          .addElement(arrow);

      final targetId = navigator.exploreByDirection(
        start, scene, LinkDirection.right,
      );

      expect(navigator.isExploring, isTrue);
      expect(targetId, equals(end.id));
    });

    test('returns null for dead end', () {
      final isolated = RectangleElement(
        id: const ElementId('isolated'),
        x: 0, y: 0, width: 100, height: 50,
      );
      final scene = Scene().addElement(isolated);

      final targetId = navigator.exploreByDirection(
        isolated, scene, LinkDirection.right,
      );

      expect(targetId, isNull);
    });

    test('cycles through multiple same-level nodes', () {
      final start = RectangleElement(
        id: const ElementId('start'),
        x: 0, y: 0, width: 100, height: 50,
      );
      final end1 = RectangleElement(
        id: const ElementId('end1'),
        x: 200, y: -50, width: 100, height: 50,
      );
      final end2 = RectangleElement(
        id: const ElementId('end2'),
        x: 200, y: 50, width: 100, height: 50,
      );
      final arrow1 = FlowchartUtils.createBindingArrow(
        start, end1, LinkDirection.right,
      );
      final arrow2 = FlowchartUtils.createBindingArrow(
        start, end2, LinkDirection.right,
      );

      final scene = Scene()
          .addElement(start)
          .addElement(end1)
          .addElement(end2)
          .addElement(arrow1)
          .addElement(arrow2);

      // First press: goes to first node
      final first = navigator.exploreByDirection(
        start, scene, LinkDirection.right,
      );
      expect(first, equals(end1.id));

      // Second press (same direction from same element): cycles
      final second = navigator.exploreByDirection(
        start, scene, LinkDirection.right,
      );
      expect(second, equals(end2.id));

      // Third press: wraps around
      final third = navigator.exploreByDirection(
        start, scene, LinkDirection.right,
      );
      expect(third, equals(end1.id));
    });

    test('direction change resets state', () {
      final start = RectangleElement(
        id: const ElementId('start'),
        x: 0, y: 0, width: 100, height: 50,
      );
      final rightNode = RectangleElement(
        id: const ElementId('right'),
        x: 200, y: 0, width: 100, height: 50,
      );
      final downNode = RectangleElement(
        id: const ElementId('down'),
        x: 0, y: 150, width: 100, height: 50,
      );
      final arrow1 = FlowchartUtils.createBindingArrow(
        start, rightNode, LinkDirection.right,
      );
      final arrow2 = FlowchartUtils.createBindingArrow(
        start, downNode, LinkDirection.down,
      );

      final scene = Scene()
          .addElement(start)
          .addElement(rightNode)
          .addElement(downNode)
          .addElement(arrow1)
          .addElement(arrow2);

      navigator.exploreByDirection(start, scene, LinkDirection.right);

      // Change direction
      final result = navigator.exploreByDirection(
        start, scene, LinkDirection.down,
      );
      expect(result, equals(downNode.id));
    });

    test('clear resets all state', () {
      navigator.clear();
      expect(navigator.isExploring, isFalse);
    });

    test('fallback direction finds unvisited nodes', () {
      final start = RectangleElement(
        id: const ElementId('start'),
        x: 100, y: 100, width: 100, height: 50,
      );
      // Only connected downward
      final downNode = RectangleElement(
        id: const ElementId('down'),
        x: 100, y: 250, width: 100, height: 50,
      );
      final arrow = FlowchartUtils.createBindingArrow(
        start, downNode, LinkDirection.down,
      );

      final scene = Scene()
          .addElement(start)
          .addElement(downNode)
          .addElement(arrow);

      // Try right first — no connection right, but should fallback to down
      final result = navigator.exploreByDirection(
        start, scene, LinkDirection.right,
      );
      expect(result, equals(downNode.id));
    });
  });
}
