import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/line_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late LineTool tool;
  late ToolContext context;

  setUp(() {
    tool = LineTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('LineTool', () {
    test('type is line', () {
      expect(tool.type, ToolType.line);
    });

    test('first click adds first point', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      expect(tool.overlay, isNotNull);
      expect(tool.overlay!.creationPoints, hasLength(1));
    });

    test('move shows preview line to cursor', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onPointerMove(const Point(100, 100), context);
      expect(tool.overlay!.creationPoints, hasLength(2));
      expect(tool.overlay!.creationPoints![1], const Point(100, 100));
    });

    test('second click adds second point', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onPointerDown(const Point(100, 100), context);
      tool.onPointerUp(const Point(100, 100), context);
      expect(tool.overlay!.creationPoints, hasLength(2));
    });

    test('double-click finalizes with >= 2 points', () {
      // First click
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      // Second click (double-click)
      tool.onPointerDown(const Point(100, 100), context);
      final result =
          tool.onPointerUp(const Point(100, 100), context, isDoubleClick: true);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results[0], isA<AddElementResult>());
      final addResult = compound.results[0] as AddElementResult;
      final line = addResult.element as LineElement;
      expect(line.points, hasLength(2));
      expect(line.type, 'line');
    });

    test('Enter key finalizes with >= 2 points', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onPointerDown(const Point(100, 100), context);
      tool.onPointerUp(const Point(100, 100), context);

      final result = tool.onKeyEvent('Enter');
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<LineElement>());
    });

    test('Enter with < 2 points does nothing', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      final result = tool.onKeyEvent('Enter');
      expect(result, isNull);
    });

    test('Escape cancels creation', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onKeyEvent('Escape');
      expect(tool.overlay, isNull);
    });

    test('finalized line has correct bounding box', () {
      tool.onPointerDown(const Point(10, 20), context);
      tool.onPointerUp(const Point(10, 20), context);
      tool.onPointerDown(const Point(110, 70), context);
      final result =
          tool.onPointerUp(const Point(110, 70), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      final line = (compound.results[0] as AddElementResult).element;
      expect(line.x, 10);
      expect(line.y, 20);
      expect(line.width, 100);
      expect(line.height, 50);
    });

    test('result includes selection and switch to select', () {
      tool.onPointerDown(const Point(0, 0), context);
      tool.onPointerUp(const Point(0, 0), context);
      tool.onPointerDown(const Point(100, 100), context);
      final result =
          tool.onPointerUp(const Point(100, 100), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      expect(compound.results[1], isA<SetSelectionResult>());
      expect((compound.results[2] as SwitchToolResult).toolType,
          ToolType.select);
    });

    test('points are stored relative to origin', () {
      tool.onPointerDown(const Point(50, 100), context);
      tool.onPointerUp(const Point(50, 100), context);
      tool.onPointerDown(const Point(150, 200), context);
      final result =
          tool.onPointerUp(const Point(150, 200), context, isDoubleClick: true);
      final compound = result! as CompoundResult;
      final line =
          (compound.results[0] as AddElementResult).element as LineElement;
      // Points should be relative to the element's origin (50, 100)
      expect(line.points[0], const Point(0, 0));
      expect(line.points[1], const Point(100, 100));
    });

    test('overlay is null before any click', () {
      expect(tool.overlay, isNull);
    });
  });
}
