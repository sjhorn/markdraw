import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  ToolContext contextWithGrid({int? gridSize, Scene? scene}) {
    return ToolContext(
      scene: scene ?? Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
      gridSize: gridSize,
    );
  }

  group('RectangleTool grid snap', () {
    test('corners snap to grid', () {
      final tool = RectangleTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      // 13→20, 17→20 (snap start); 93→100, 67→60 (snap end)
      expect(elem.x, 20);
      expect(elem.y, 20);
      expect(elem.width, 80);
      expect(elem.height, 40);
    });

    test('no snap when gridSize is null', () {
      final tool = RectangleTool();
      final ctx = contextWithGrid();

      tool.onPointerDown(const Point(13, 17), ctx);
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      expect(elem.x, 13);
      expect(elem.y, 17);
    });
  });

  group('EllipseTool grid snap', () {
    test('corners snap to grid', () {
      final tool = EllipseTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      expect(elem.x, 20);
      expect(elem.y, 20);
      expect(elem.width, 80);
      expect(elem.height, 40);
    });
  });

  group('DiamondTool grid snap', () {
    test('corners snap to grid', () {
      final tool = DiamondTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      expect(elem.x, 20);
      expect(elem.y, 20);
      expect(elem.width, 80);
      expect(elem.height, 40);
    });
  });

  group('FrameTool grid snap', () {
    test('corners snap to grid', () {
      final tool = FrameTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      final result = tool.onPointerUp(const Point(213, 167), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      expect(elem.x, 20);
      expect(elem.y, 20);
      expect(elem.width, 200);
      expect(elem.height, 140);
    });
  });

  group('LineTool grid snap', () {
    test('points snap to grid', () {
      final tool = LineTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      // Drag far enough to create line
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element as LineElement;
      // Start: 13→20, 17→20; End: 93→100, 67→60
      // x = min(20, 100) = 20, y = min(20, 60) = 20
      expect(elem.x, 20);
      expect(elem.y, 20);
    });
  });

  group('ArrowTool grid snap', () {
    test('points snap to grid when no binding', () {
      final tool = ArrowTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      // Drag far enough to create arrow
      final result = tool.onPointerUp(const Point(93, 67), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element as ArrowElement;
      // Start: 13→20, 17→20; End: 93→100, 67→60
      expect(elem.x, 20);
      expect(elem.y, 20);
    });

    test('binding takes priority over grid snap', () {
      // Create a rectangle to bind to
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 80,
        y: 10,
        width: 100,
        height: 80,
      );
      final scene = Scene().addElement(rect);
      final ctx = contextWithGrid(gridSize: 20, scene: scene);

      final tool = ArrowTool();

      // Start from empty space (snapped to grid)
      tool.onPointerDown(const Point(13, 50), ctx);
      // End on the rectangle (binding should take priority)
      final result = tool.onPointerUp(const Point(82, 50), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final arrow = add.element as ArrowElement;
      // Start should be grid-snapped (20, 40 or 60)
      expect(arrow.startBinding, isNull);
      // End should be bound, not grid-snapped
      expect(arrow.endBinding, isNotNull);
    });
  });

  group('TextTool grid snap', () {
    test('click position snaps to grid', () {
      final tool = TextTool();
      final ctx = contextWithGrid(gridSize: 20);

      tool.onPointerDown(const Point(13, 17), ctx);
      // Click (within drag threshold)
      final result = tool.onPointerUp(const Point(14, 18), ctx);

      expect(result, isA<CompoundResult>());
      final add = (result as CompoundResult).results
          .whereType<AddElementResult>()
          .first;
      final elem = add.element;
      expect(elem.x, 20);
      expect(elem.y, 20);
    });
  });

  group('SelectTool grid snap', () {
    test('move snaps element position to grid', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 20,
        y: 20,
        width: 100,
        height: 80,
      );
      final scene = Scene().addElement(rect);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('r1')},
        gridSize: 20,
      );

      final tool = SelectTool();
      tool.onPointerDown(const Point(50, 50), ctx);
      // Move by 13px — should snap to nearest grid
      tool.onPointerMove(const Point(63, 63), ctx);
      final result = tool.onPointerUp(const Point(63, 63), ctx);

      // May be UpdateElementResult or CompoundResult depending on bound elements
      UpdateElementResult update;
      if (result is CompoundResult) {
        update = result.results.whereType<UpdateElementResult>().first;
      } else {
        update = result! as UpdateElementResult;
      }
      // 20 + 13 = 33, snapped to 40; so dx should be 20
      expect(update.element.x, 40);
      expect(update.element.y, 40);
    });
  });

  group('ToolContext gridSize', () {
    test('defaults to null', () {
      final ctx = ToolContext(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
      );
      expect(ctx.gridSize, isNull);
    });

    test('can be set', () {
      final ctx = ToolContext(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        gridSize: 20,
      );
      expect(ctx.gridSize, 20);
    });
  });
}
