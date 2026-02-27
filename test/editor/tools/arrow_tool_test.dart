import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late ArrowTool tool;
  late ToolContext context;

  setUp(() {
    tool = ArrowTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('ArrowTool', () {
    test('type is arrow', () {
      expect(tool.type, ToolType.arrow);
    });

    test('creates ArrowElement on finalize', () {
      tool.onPointerDown(const Point(0, 0), context);
      tool.onPointerUp(const Point(0, 0), context);
      tool.onPointerDown(const Point(100, 100), context);
      final result =
          tool.onPointerUp(const Point(100, 100), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      final element = (compound.results[0] as AddElementResult).element;
      expect(element, isA<ArrowElement>());
    });

    test('arrow has endArrowhead set to arrow', () {
      tool.onPointerDown(const Point(0, 0), context);
      tool.onPointerUp(const Point(0, 0), context);
      tool.onPointerDown(const Point(100, 100), context);
      final result =
          tool.onPointerUp(const Point(100, 100), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      final arrow = (compound.results[0] as AddElementResult).element
          as ArrowElement;
      expect(arrow.endArrowhead, Arrowhead.arrow);
    });

    test('move shows preview', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onPointerMove(const Point(100, 100), context);
      expect(tool.overlay!.creationPoints, hasLength(2));
    });

    test('Enter finalizes with >= 2 points', () {
      tool.onPointerDown(const Point(0, 0), context);
      tool.onPointerUp(const Point(0, 0), context);
      tool.onPointerDown(const Point(50, 50), context);
      tool.onPointerUp(const Point(50, 50), context);
      final result = tool.onKeyEvent('Enter');
      expect(result, isA<CompoundResult>());
      final element = ((result! as CompoundResult).results[0]
          as AddElementResult).element;
      expect(element, isA<ArrowElement>());
    });

    test('Escape cancels', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onKeyEvent('Escape');
      expect(tool.overlay, isNull);
    });

    test('arrow points are relative to origin', () {
      tool.onPointerDown(const Point(50, 100), context);
      tool.onPointerUp(const Point(50, 100), context);
      tool.onPointerDown(const Point(150, 200), context);
      final result =
          tool.onPointerUp(const Point(150, 200), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      final arrow = (compound.results[0] as AddElementResult).element
          as ArrowElement;
      expect(arrow.points[0], const Point(0, 0));
      expect(arrow.points[1], const Point(100, 100));
      expect(arrow.x, 50);
      expect(arrow.y, 100);
    });

    test('result includes switch to select', () {
      tool.onPointerDown(const Point(0, 0), context);
      tool.onPointerUp(const Point(0, 0), context);
      tool.onPointerDown(const Point(100, 100), context);
      final result =
          tool.onPointerUp(const Point(100, 100), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      expect((compound.results[2] as SwitchToolResult).toolType,
          ToolType.select);
    });

    group('drag-to-draw', () {
      test('drag creates 2-point arrow in one gesture', () {
        tool.onPointerDown(const Point(10, 20), context);
        tool.onPointerMove(const Point(110, 120), context);
        final result = tool.onPointerUp(const Point(110, 120), context);

        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        expect(compound.results[0], isA<AddElementResult>());
        final arrow =
            (compound.results[0] as AddElementResult).element as ArrowElement;
        expect(arrow.points, hasLength(2));
        expect(arrow.points[0], const Point(0, 0));
        expect(arrow.points[1], const Point(100, 100));
        expect(arrow.x, 10);
        expect(arrow.y, 20);
        expect(arrow.endArrowhead, Arrowhead.arrow);
        expect(compound.results[1], isA<SetSelectionResult>());
        expect((compound.results[2] as SwitchToolResult).toolType,
            ToolType.select);
      });

      test('short drag stays in multi-click mode', () {
        tool.onPointerDown(const Point(10, 20), context);
        final result = tool.onPointerUp(const Point(10, 20), context);

        expect(result, isNull);
        expect(tool.overlay, isNotNull);
        expect(tool.overlay!.creationPoints, hasLength(1));

        // Can continue adding points via click
        tool.onPointerDown(const Point(100, 100), context);
        tool.onPointerUp(const Point(100, 100), context);
        expect(tool.overlay!.creationPoints, hasLength(2));
      });

      test('drag with binding at start and end', () {
        final rect1 = Element(
          id: const ElementId('r1'),
          type: 'rectangle',
          x: 0,
          y: 0,
          width: 100,
          height: 100,
        );
        final rect2 = Element(
          id: const ElementId('r2'),
          type: 'rectangle',
          x: 300,
          y: 0,
          width: 100,
          height: 100,
        );
        final scene = Scene().addElement(rect1).addElement(rect2);
        final ctx = ToolContext(
          scene: scene,
          viewport: const ViewportState(),
          selectedIds: {},
        );

        // Drag from right edge of rect1 to left edge of rect2
        tool.onPointerDown(const Point(95, 50), ctx);
        tool.onPointerMove(const Point(305, 50), ctx);
        final result = tool.onPointerUp(const Point(305, 50), ctx);

        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final arrow =
            (compound.results[0] as AddElementResult).element as ArrowElement;
        expect(arrow.startBinding, isNotNull);
        expect(arrow.startBinding!.elementId, 'r1');
        expect(arrow.endBinding, isNotNull);
        expect(arrow.endBinding!.elementId, 'r2');
      });

      test('drag shows preview during drag', () {
        tool.onPointerDown(const Point(10, 20), context);
        tool.onPointerMove(const Point(50, 60), context);

        expect(tool.overlay, isNotNull);
        expect(tool.overlay!.creationPoints, hasLength(2));
        expect(tool.overlay!.creationPoints![0], const Point(10, 20));
        expect(tool.overlay!.creationPoints![1], const Point(50, 60));
      });
    });
  });
}
