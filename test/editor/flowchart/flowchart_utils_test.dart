import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FlowchartUtils', () {
    group('isFlowchartNode', () {
      test('returns true for rectangle', () {
        final rect = RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(FlowchartUtils.isFlowchartNode(rect), isTrue);
      });

      test('returns true for ellipse', () {
        final ellipse = EllipseElement(
          id: const ElementId('e1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(FlowchartUtils.isFlowchartNode(ellipse), isTrue);
      });

      test('returns true for diamond', () {
        final diamond = DiamondElement(
          id: const ElementId('d1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(FlowchartUtils.isFlowchartNode(diamond), isTrue);
      });

      test('returns false for line', () {
        final line = LineElement(
          id: const ElementId('l1'),
          x: 0, y: 0, width: 100, height: 0,
          points: [const Point(0, 0), const Point(100, 0)],
        );
        expect(FlowchartUtils.isFlowchartNode(line), isFalse);
      });

      test('returns false for arrow', () {
        final arrow = ArrowElement(
          id: const ElementId('a1'),
          x: 0, y: 0, width: 100, height: 0,
          points: [const Point(0, 0), const Point(100, 0)],
        );
        expect(FlowchartUtils.isFlowchartNode(arrow), isFalse);
      });

      test('returns false for text', () {
        final text = TextElement(
          id: const ElementId('t1'),
          x: 0, y: 0, width: 100, height: 50,
          text: 'hello',
        );
        expect(FlowchartUtils.isFlowchartNode(text), isFalse);
      });

      test('returns false for freedraw', () {
        final fd = FreedrawElement(
          id: const ElementId('fd1'),
          x: 0, y: 0, width: 100, height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
        );
        expect(FlowchartUtils.isFlowchartNode(fd), isFalse);
      });
    });

    group('createNodeAndArrow', () {
      late RectangleElement startNode;
      late Scene scene;

      setUp(() {
        startNode = RectangleElement(
          id: const ElementId('start'),
          x: 100, y: 100, width: 200, height: 100,
          strokeColor: '#ff0000',
          backgroundColor: '#00ff00',
        );
        scene = Scene().addElement(startNode);
      });

      test('creates node to the right', () {
        final elements = FlowchartUtils.createNodeAndArrow(
          startNode, LinkDirection.right, scene,
        );
        expect(elements, hasLength(2));
        final node = elements[0];
        final arrow = elements[1] as ArrowElement;

        // Node should be positioned to the right
        expect(node.x, equals(startNode.x + startNode.width + 100));
        expect(node.y, equals(startNode.y));
        expect(node.width, equals(startNode.width));
        expect(node.height, equals(startNode.height));

        // Style should be cloned
        expect(node.strokeColor, equals('#ff0000'));
        expect(node.backgroundColor, equals('#00ff00'));

        // Arrow should be elbow type
        expect(arrow.arrowType, equals(ArrowType.sharpElbow));
        expect(arrow.endArrowhead, equals(Arrowhead.arrow));
        expect(arrow.startBinding, isNotNull);
        expect(arrow.endBinding, isNotNull);
        expect(arrow.startBinding!.elementId, equals('start'));
        expect(arrow.endBinding!.elementId, equals(node.id.value));
      });

      test('creates node to the left', () {
        final elements = FlowchartUtils.createNodeAndArrow(
          startNode, LinkDirection.left, scene,
        );
        final node = elements[0];
        expect(node.x, equals(startNode.x - startNode.width - 100));
        expect(node.y, equals(startNode.y));
      });

      test('creates node downward', () {
        final elements = FlowchartUtils.createNodeAndArrow(
          startNode, LinkDirection.down, scene,
        );
        final node = elements[0];
        expect(node.x, equals(startNode.x));
        expect(node.y, equals(startNode.y + startNode.height + 100));
      });

      test('creates node upward', () {
        final elements = FlowchartUtils.createNodeAndArrow(
          startNode, LinkDirection.up, scene,
        );
        final node = elements[0];
        expect(node.x, equals(startNode.x));
        expect(node.y, equals(startNode.y - startNode.height - 100));
      });

      test('creates node with fresh ID', () {
        final elements = FlowchartUtils.createNodeAndArrow(
          startNode, LinkDirection.right, scene,
        );
        expect(elements[0].id, isNot(equals(startNode.id)));
        expect(elements[1].id, isNot(equals(startNode.id)));
        expect(elements[0].id, isNot(equals(elements[1].id)));
      });
    });

    group('createBindingArrow', () {
      test('creates arrow with correct bindings for right direction', () {
        final start = RectangleElement(
          id: const ElementId('s'),
          x: 0, y: 0, width: 100, height: 50,
        );
        final end = RectangleElement(
          id: const ElementId('e'),
          x: 200, y: 0, width: 100, height: 50,
        );
        final arrow = FlowchartUtils.createBindingArrow(
          start, end, LinkDirection.right,
        );

        expect(arrow.startBinding!.fixedPoint, equals(const Point(1.0, 0.5)));
        expect(arrow.endBinding!.fixedPoint, equals(const Point(0.0, 0.5)));
        expect(arrow.arrowType, equals(ArrowType.sharpElbow));
        expect(arrow.points.length, greaterThanOrEqualTo(2));
      });

      test('creates arrow with correct bindings for down direction', () {
        final start = RectangleElement(
          id: const ElementId('s'),
          x: 0, y: 0, width: 100, height: 50,
        );
        final end = RectangleElement(
          id: const ElementId('e'),
          x: 0, y: 150, width: 100, height: 50,
        );
        final arrow = FlowchartUtils.createBindingArrow(
          start, end, LinkDirection.down,
        );

        expect(arrow.startBinding!.fixedPoint, equals(const Point(0.5, 1.0)));
        expect(arrow.endBinding!.fixedPoint, equals(const Point(0.5, 0.0)));
      });
    });

    group('createFannedNodes', () {
      late RectangleElement startNode;
      late Scene scene;

      setUp(() {
        startNode = RectangleElement(
          id: const ElementId('start'),
          x: 100, y: 100, width: 200, height: 100,
        );
        scene = Scene().addElement(startNode);
      });

      test('creates 2 fanned nodes to the right', () {
        final elements = FlowchartUtils.createFannedNodes(
          startNode, LinkDirection.right, scene, 2,
        );
        // 2 nodes + 2 arrows
        expect(elements, hasLength(4));

        final node1 = elements[0];
        final node2 = elements[2];

        // Both should be to the right
        expect(node1.x, equals(startNode.x + startNode.width + 100));
        expect(node2.x, equals(startNode.x + startNode.width + 100));

        // They should be vertically offset from each other
        expect(node1.y, isNot(equals(node2.y)));
      });

      test('creates 3 fanned nodes downward', () {
        final elements = FlowchartUtils.createFannedNodes(
          startNode, LinkDirection.down, scene, 3,
        );
        expect(elements, hasLength(6));

        final node1 = elements[0];
        final node2 = elements[2];
        final node3 = elements[4];

        // All should be below
        expect(node1.y, equals(startNode.y + startNode.height + 100));
        expect(node2.y, equals(startNode.y + startNode.height + 100));
        expect(node3.y, equals(startNode.y + startNode.height + 100));

        // Middle node should be centered (same x as parent)
        expect(node2.x, equals(startNode.x));
      });

      test('single fanned node is centered', () {
        final elements = FlowchartUtils.createFannedNodes(
          startNode, LinkDirection.right, scene, 1,
        );
        expect(elements, hasLength(2));
        final node = elements[0];
        expect(node.y, equals(startNode.y));
      });
    });

    group('getLinkedNodesInDirection', () {
      test('finds successor via elbow arrow to the right', () {
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

        final linked = FlowchartUtils.getLinkedNodesInDirection(
          scene, start, LinkDirection.right,
        );
        expect(linked, hasLength(1));
        expect(linked.first.id, equals(end.id));
      });

      test('finds predecessor via arrow coming from the left', () {
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

        // From end, looking left should find start
        final linked = FlowchartUtils.getLinkedNodesInDirection(
          scene, end, LinkDirection.left,
        );
        expect(linked, hasLength(1));
        expect(linked.first.id, equals(start.id));
      });

      test('returns empty for unconnected direction', () {
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

        final linked = FlowchartUtils.getLinkedNodesInDirection(
          scene, start, LinkDirection.up,
        );
        expect(linked, isEmpty);
      });
    });

    group('collision avoidance', () {
      test('staggers when direct position is occupied', () {
        final startNode = RectangleElement(
          id: const ElementId('start'),
          x: 100, y: 100, width: 200, height: 100,
        );
        // Place an existing node at the direct position
        final blocking = RectangleElement(
          id: const ElementId('blocking'),
          x: 400, y: 100, width: 200, height: 100,
        );
        final offset = FlowchartUtils.getOffset(
          startNode,
          [blocking],
          LinkDirection.right,
        );
        // Should not overlap with the blocking node
        expect(offset.dy, isNot(equals(100.0)));
      });
    });
  });
}
