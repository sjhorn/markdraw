import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/ellipse_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late EllipseTool tool;
  late ToolContext context;

  setUp(() {
    tool = EllipseTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('EllipseTool', () {
    test('type is ellipse', () {
      expect(tool.type, ToolType.ellipse);
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

    test('onPointerUp creates EllipseElement', () {
      tool.onPointerDown(const Point(10, 20), context);
      final result = tool.onPointerUp(const Point(110, 70), context);
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<EllipseElement>());
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

    test('result includes switch to select', () {
      tool.onPointerDown(const Point(0, 0), context);
      final result = tool.onPointerUp(const Point(100, 100), context);
      final compound = result! as CompoundResult;
      expect((compound.results[2] as SwitchToolResult).toolType,
          ToolType.select);
    });
  });
}
