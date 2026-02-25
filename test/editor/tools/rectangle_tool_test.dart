import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late RectangleTool tool;
  late ToolContext context;

  setUp(() {
    tool = RectangleTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('RectangleTool', () {
    test('type is rectangle', () {
      expect(tool.type, ToolType.rectangle);
    });

    test('onPointerDown returns null and records start', () {
      final result = tool.onPointerDown(const Point(10, 20), context);
      expect(result, isNull);
    });

    test('onPointerMove updates overlay.creationBounds', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(110, 70), context);
      final overlay = tool.overlay;
      expect(overlay, isNotNull);
      expect(overlay!.creationBounds, isNotNull);
      expect(overlay.creationBounds!.left, 10);
      expect(overlay.creationBounds!.top, 20);
      expect(overlay.creationBounds!.right, 110);
      expect(overlay.creationBounds!.bottom, 70);
    });

    test('onPointerUp creates rectangle with correct bounds', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(110, 70), context);
      final result = tool.onPointerUp(const Point(110, 70), context);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results.length, 3);
      expect(compound.results[0], isA<AddElementResult>());
      expect(compound.results[1], isA<SetSelectionResult>());
      expect(compound.results[2], isA<SwitchToolResult>());

      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<RectangleElement>());
      expect(addResult.element.x, 10);
      expect(addResult.element.y, 20);
      expect(addResult.element.width, 100);
      expect(addResult.element.height, 50);

      final switchResult = compound.results[2] as SwitchToolResult;
      expect(switchResult.toolType, ToolType.select);
    });

    test('negative drag normalizes bounds', () {
      tool.onPointerDown(const Point(110, 70), context);
      final result = tool.onPointerUp(const Point(10, 20), context);

      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element.x, 10);
      expect(addResult.element.y, 20);
      expect(addResult.element.width, 100);
      expect(addResult.element.height, 50);
    });

    test('small drag (< 5px) cancels creation', () {
      tool.onPointerDown(const Point(10, 20), context);
      final result = tool.onPointerUp(const Point(12, 23), context);
      expect(result, isNull);
    });

    test('reset clears state', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(110, 70), context);
      tool.reset();
      expect(tool.overlay, isNull);
    });

    test('overlay is null before interaction', () {
      expect(tool.overlay, isNull);
    });

    test('selection includes created element ID', () {
      tool.onPointerDown(const Point(10, 20), context);
      final result = tool.onPointerUp(const Point(110, 70), context);
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      final selectResult = compound.results[1] as SetSelectionResult;
      expect(selectResult.selectedIds, {addResult.element.id});
    });
  });
}
