import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/freedraw_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late FreedrawTool tool;
  late ToolContext context;

  setUp(() {
    tool = FreedrawTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('FreedrawTool', () {
    test('type is freedraw', () {
      expect(tool.type, ToolType.freedraw);
    });

    test('down starts path', () {
      tool.onPointerDown(const Point(10, 20), context);
      expect(tool.overlay, isNotNull);
      expect(tool.overlay!.creationPoints, hasLength(1));
    });

    test('move appends points', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(30, 40), context);
      tool.onPointerMove(const Point(50, 60), context);
      expect(tool.overlay!.creationPoints, hasLength(3));
    });

    test('up finalizes FreedrawElement', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(30, 40), context);
      tool.onPointerMove(const Point(50, 60), context);
      final result = tool.onPointerUp(const Point(50, 60), context);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<FreedrawElement>());
    });

    test('element has correct bounding box from points', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(50, 80), context);
      tool.onPointerMove(const Point(30, 40), context);
      final result = tool.onPointerUp(const Point(30, 40), context);

      final compound = result! as CompoundResult;
      final element = (compound.results[0] as AddElementResult).element;
      expect(element.x, 10);
      expect(element.y, 20);
      expect(element.width, 40); // 50 - 10
      expect(element.height, 60); // 80 - 20
    });

    test('simulatePressure defaults to true', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(50, 80), context);
      final result = tool.onPointerUp(const Point(50, 80), context);

      final compound = result! as CompoundResult;
      final freedraw = (compound.results[0] as AddElementResult).element
          as FreedrawElement;
      expect(freedraw.simulatePressure, isTrue);
    });

    test('points are stored relative to origin', () {
      tool.onPointerDown(const Point(50, 100), context);
      tool.onPointerMove(const Point(150, 200), context);
      final result = tool.onPointerUp(const Point(150, 200), context);

      final compound = result! as CompoundResult;
      final freedraw = (compound.results[0] as AddElementResult).element
          as FreedrawElement;
      expect(freedraw.points[0], const Point(0, 0));
      expect(freedraw.points[1], const Point(100, 100));
    });

    test('reset clears state', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerMove(const Point(50, 80), context);
      tool.reset();
      expect(tool.overlay, isNull);
    });

    test('overlay is null before interaction', () {
      expect(tool.overlay, isNull);
    });
  });
}
