import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ToolContext _ctx([Scene? scene]) => ToolContext(
      scene: scene ?? Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );

void main() {
  group('FrameTool', () {
    test('type is frame', () {
      expect(FrameTool().type, ToolType.frame);
    });

    test('creates frame by drag', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(210, 220), _ctx());
      final result = tool.onPointerUp(const Point(210, 220), _ctx());

      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;
      final add = compound.results
          .whereType<AddElementResult>()
          .first;
      expect(add.element, isA<FrameElement>());
      final frame = add.element as FrameElement;
      expect(frame.x, 10);
      expect(frame.y, 20);
      expect(frame.width, 200);
      expect(frame.height, 200);
    });

    test('default label is Frame N', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(0, 0), _ctx());
      final result = tool.onPointerUp(const Point(100, 100), _ctx());
      final compound = result as CompoundResult;
      final add = compound.results
          .whereType<AddElementResult>()
          .first;
      final frame = add.element as FrameElement;
      expect(frame.label, 'Frame 1');
    });

    test('minimum size — ignores small drag', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      final result = tool.onPointerUp(const Point(12, 22), _ctx());
      expect(result, isNull);
    });

    test('preview during drag shows creation bounds', () {
      final tool = FrameTool();
      expect(tool.overlay, isNull);

      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(110, 120), _ctx());

      final overlay = tool.overlay;
      expect(overlay, isNotNull);
      expect(overlay!.creationBounds, isNotNull);
      expect(overlay.creationBounds!.left, 10);
      expect(overlay.creationBounds!.top, 20);
      expect(overlay.creationBounds!.size.width, 100);
      expect(overlay.creationBounds!.size.height, 100);
    });

    test('preview is null after reset', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(110, 120), _ctx());
      tool.reset();
      expect(tool.overlay, isNull);
    });

    test('switches to select after creation', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(0, 0), _ctx());
      final result = tool.onPointerUp(const Point(100, 100), _ctx());
      final compound = result as CompoundResult;
      final switchResult = compound.results
          .whereType<SwitchToolResult>()
          .first;
      expect(switchResult.toolType, ToolType.select);
    });

    test('sets selection to new frame', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(0, 0), _ctx());
      final result = tool.onPointerUp(const Point(100, 100), _ctx());
      final compound = result as CompoundResult;
      final selResult = compound.results
          .whereType<SetSelectionResult>()
          .first;
      expect(selResult.selectedIds, hasLength(1));
    });

    test('Escape cancels drag', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(0, 0), _ctx());
      tool.onPointerMove(const Point(100, 100), _ctx());
      tool.onKeyEvent('Escape');
      expect(tool.overlay, isNull);
      final result = tool.onPointerUp(const Point(100, 100), _ctx());
      expect(result, isNull);
    });

    test('frame properties — type is frame', () {
      final tool = FrameTool();
      tool.onPointerDown(const Point(0, 0), _ctx());
      final result = tool.onPointerUp(const Point(100, 100), _ctx());
      final compound = result as CompoundResult;
      final add = compound.results
          .whereType<AddElementResult>()
          .first;
      expect(add.element.type, 'frame');
    });
  });

  group('ToolType.frame', () {
    test('exists in enum', () {
      expect(ToolType.values, contains(ToolType.frame));
    });
  });

  group('F shortcut', () {
    test('maps to ToolType.frame', () {
      expect(toolTypeForKey('f'), ToolType.frame);
    });
  });

  group('createTool(ToolType.frame)', () {
    test('returns FrameTool', () {
      final tool = createTool(ToolType.frame);
      expect(tool, isA<FrameTool>());
    });
  });
}
