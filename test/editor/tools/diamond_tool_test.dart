import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late DiamondTool tool;
  late ToolContext context;

  setUp(() {
    tool = DiamondTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('DiamondTool', () {
    test('type is diamond', () {
      expect(tool.type, ToolType.diamond);
    });

    test('onPointerDown returns null', () {
      expect(tool.onPointerDown(const Point(10, 20), context), isNull);
    });

    test('onPointerMove updates overlay.creationBounds', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(110, 70), context);
      expect(tool.overlay!.creationBounds!.left, 10);
      expect(tool.overlay!.creationBounds!.right, 110);
    });

    test('onPointerUp creates DiamondElement', () {
      tool.onPointerDown(const Point(10, 20), context);
      final result = tool.onPointerUp(const Point(110, 70), context);
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<DiamondElement>());
      expect(addResult.element.x, 10);
      expect(addResult.element.y, 20);
      expect(addResult.element.width, 100);
      expect(addResult.element.height, 50);
    });

    test('negative drag normalizes bounds', () {
      tool.onPointerDown(const Point(110, 70), context);
      final result = tool.onPointerUp(const Point(10, 20), context);
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element.x, 10);
      expect(addResult.element.y, 20);
    });

    test('small drag cancels', () {
      tool.onPointerDown(const Point(10, 20), context);
      expect(tool.onPointerUp(const Point(12, 23), context), isNull);
    });

    test('reset clears state', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.reset();
      expect(tool.overlay, isNull);
    });

    test('result includes selection and tool switch', () {
      tool.onPointerDown(const Point(0, 0), context);
      final result = tool.onPointerUp(const Point(100, 100), context);
      final compound = result! as CompoundResult;
      expect(compound.results[1], isA<SetSelectionResult>());
      expect((compound.results[2] as SwitchToolResult).toolType,
          ToolType.select);
    });
  });
}
