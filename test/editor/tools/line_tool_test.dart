import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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

    group('closed polygon', () {
      test('move near start with >= 3 points snaps preview and sets creationClosed', () {
        // Click 3 points to form a triangle
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);
        tool.onPointerDown(const Point(50, 100), context);
        tool.onPointerUp(const Point(50, 100), context);

        // Move near start point (within 10px threshold)
        tool.onPointerMove(const Point(3, 3), context);

        expect(tool.overlay!.creationClosed, isTrue);
        // Preview should snap to start point
        expect(tool.overlay!.creationPoints!.last, const Point(0, 0));
      });

      test('move outside threshold does not snap', () {
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);
        tool.onPointerDown(const Point(50, 100), context);
        tool.onPointerUp(const Point(50, 100), context);

        // Move far from start
        tool.onPointerMove(const Point(80, 50), context);

        expect(tool.overlay!.creationClosed, isFalse);
        expect(tool.overlay!.creationPoints!.last, const Point(80, 50));
      });

      test('need >= 3 points for close detection', () {
        // Only 2 points
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);

        // Move near start
        tool.onPointerMove(const Point(1, 1), context);

        expect(tool.overlay!.creationClosed, isFalse);
      });

      test('click near start finalizes as closed with last==first', () {
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);
        tool.onPointerDown(const Point(50, 100), context);
        tool.onPointerUp(const Point(50, 100), context);

        // Move near start to trigger snap
        tool.onPointerMove(const Point(3, 3), context);

        // Click near start to finalize
        tool.onPointerDown(const Point(3, 3), context);
        final result = tool.onPointerUp(const Point(3, 3), context);

        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final addResult = compound.results[0] as AddElementResult;
        final line = addResult.element as LineElement;
        expect(line.closed, isTrue);
        // Last point should equal first point (relative)
        expect(line.points.last, line.points.first);
      });

      test('Enter does not auto-close', () {
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);
        tool.onPointerDown(const Point(50, 100), context);
        tool.onPointerUp(const Point(50, 100), context);

        final result = tool.onKeyEvent('Enter');
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final addResult = compound.results[0] as AddElementResult;
        final line = addResult.element as LineElement;
        expect(line.closed, isFalse);
      });

      test('Escape does not auto-close', () {
        tool.onPointerDown(const Point(0, 0), context);
        tool.onPointerUp(const Point(0, 0), context);
        tool.onPointerDown(const Point(100, 0), context);
        tool.onPointerUp(const Point(100, 0), context);
        tool.onPointerDown(const Point(50, 100), context);
        tool.onPointerUp(const Point(50, 100), context);

        // Move near start to trigger snap
        tool.onPointerMove(const Point(3, 3), context);

        // Escape should finalize as open (since >= 2 points)
        final result = tool.onKeyEvent('Escape');
        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        final addResult = compound.results[0] as AddElementResult;
        final line = addResult.element as LineElement;
        expect(line.closed, isFalse);
      });
    });

    group('drag-to-draw', () {
      test('drag creates 2-point line in one gesture', () {
        tool.onPointerDown(const Point(10, 20), context);
        tool.onPointerMove(const Point(110, 120), context);
        final result = tool.onPointerUp(const Point(110, 120), context);

        expect(result, isA<CompoundResult>());
        final compound = result! as CompoundResult;
        expect(compound.results[0], isA<AddElementResult>());
        final line =
            (compound.results[0] as AddElementResult).element as LineElement;
        expect(line.points, hasLength(2));
        expect(line.points[0], const Point(0, 0));
        expect(line.points[1], const Point(100, 100));
        expect(line.x, 10);
        expect(line.y, 20);
        // Should also select and switch to select tool
        expect(compound.results[1], isA<SetSelectionResult>());
        expect((compound.results[2] as SwitchToolResult).toolType,
            ToolType.select);
      });

      test('short drag (same point) stays in multi-click mode', () {
        tool.onPointerDown(const Point(10, 20), context);
        final result = tool.onPointerUp(const Point(10, 20), context);

        expect(result, isNull);
        // Should have one point and be in multi-click mode
        expect(tool.overlay, isNotNull);
        expect(tool.overlay!.creationPoints, hasLength(1));

        // Can continue adding points via click
        tool.onPointerDown(const Point(100, 100), context);
        tool.onPointerUp(const Point(100, 100), context);
        expect(tool.overlay!.creationPoints, hasLength(2));
      });

      test('drag shows preview during drag', () {
        tool.onPointerDown(const Point(10, 20), context);
        tool.onPointerMove(const Point(50, 60), context);

        expect(tool.overlay, isNotNull);
        expect(tool.overlay!.creationPoints, hasLength(2));
        expect(tool.overlay!.creationPoints![0], const Point(10, 20));
        expect(tool.overlay!.creationPoints![1], const Point(50, 60));
      });

      test('short drag with small movement stays in multi-click mode', () {
        tool.onPointerDown(const Point(10, 20), context);
        final result = tool.onPointerUp(const Point(11, 21), context);

        // Distance ~1.41, below threshold of 2.0
        expect(result, isNull);
        expect(tool.overlay!.creationPoints, hasLength(1));
      });

      test('reset clears drag state', () {
        tool.onPointerDown(const Point(10, 20), context);
        tool.reset();
        expect(tool.overlay, isNull);
      });
    });
  });
}
