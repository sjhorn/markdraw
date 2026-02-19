import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/arrow_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

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
  });
}
