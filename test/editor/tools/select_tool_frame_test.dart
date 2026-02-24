import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/frame_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late SelectTool tool;

  final frame1 = FrameElement(
    id: const ElementId('f1'),
    x: 0,
    y: 0,
    width: 400,
    height: 300,
    label: 'Frame 1',
  );

  // A rectangle outside frame1
  final outsideRect = RectangleElement(
    id: const ElementId('r2'),
    x: 500,
    y: 500,
    width: 80,
    height: 40,
  );

  // A rectangle already assigned to frame1
  final childRect = RectangleElement(
    id: const ElementId('r3'),
    x: 100,
    y: 100,
    width: 60,
    height: 30,
    frameId: 'f1',
  );

  setUp(() {
    tool = SelectTool();
  });

  ToolContext contextWith({
    List<Element> elements = const [],
    Set<ElementId> selectedIds = const {},
    List<Element> clipboard = const [],
  }) {
    var scene = Scene();
    for (final e in elements) {
      scene = scene.addElement(e);
    }
    return ToolContext(
      scene: scene,
      viewport: const ViewportState(),
      selectedIds: selectedIds,
      clipboard: clipboard,
    );
  }

  /// Simulate a drag: down at [from], move to [to], up at [to].
  ToolResult? drag(Point from, Point to, ToolContext context,
      {bool shift = false}) {
    tool.onPointerDown(from, context, shift: shift);
    tool.onPointerMove(to, context);
    return tool.onPointerUp(to, context);
  }

  /// Simulate a click: down + up at the same point.
  ToolResult? click(Point point, ToolContext context, {bool shift = false}) {
    tool.onPointerDown(point, context, shift: shift);
    return tool.onPointerUp(point, context);
  }

  // --- A. Auto-assign frameId on move ---

  group('Auto-assign frameId on move', () {
    test('moving element into frame assigns frameId', () {
      // outsideRect starts at (500, 500), drag it to (50, 50) — inside frame1
      final movedRect = outsideRect.copyWith(x: 50, y: 50);
      final ctx = contextWith(
        elements: [frame1, movedRect],
        selectedIds: {movedRect.id},
      );

      // Simulate drag to move by (10, 10) — still inside frame
      final result = drag(
        const Point(90, 70), // center of movedRect at (50,50) size 80x40
        const Point(100, 80),
        ctx,
      );

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      // Should have the move update + a frame assignment update
      final frameAssigned = updates.where(
        (u) => u.element.id == movedRect.id && u.element.frameId == 'f1',
      );
      expect(frameAssigned, isNotEmpty,
          reason: 'Element moved inside frame should get frameId assigned');
    });

    test('moving element out of frame clears frameId', () {
      // childRect is at (100,100) with frameId='f1', move it far outside
      final ctx = contextWith(
        elements: [frame1, childRect],
        selectedIds: {childRect.id},
      );

      // Drag from center of childRect to far outside frame
      final result = drag(
        const Point(130, 115), // center of childRect
        const Point(630, 615), // well outside frame1 (0,0,400,300)
        ctx,
      );

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();
      // The element should have frameId cleared
      final cleared = updates.where(
        (u) => u.element.id == childRect.id && u.element.frameId == null,
      );
      expect(cleared, isNotEmpty,
          reason: 'Element moved outside frame should have frameId cleared');
    });

    test('moving element that stays inside frame keeps frameId', () {
      final ctx = contextWith(
        elements: [frame1, childRect],
        selectedIds: {childRect.id},
      );

      // Small drag that keeps childRect inside frame1
      final result = drag(
        const Point(130, 115),
        const Point(140, 125), // still inside frame (0,0,400,300)
        ctx,
      );

      expect(result, isNotNull);
      // The element should still have frameId = 'f1'
      if (result is CompoundResult) {
        final updates =
            result.results.whereType<UpdateElementResult>().toList();
        final elem = updates.firstWhere((u) => u.element.id == childRect.id);
        expect(elem.element.frameId, 'f1');
      } else if (result is UpdateElementResult) {
        expect(result.element.frameId, 'f1');
      }
    });
  });

  // --- B. Frame delete releases children ---

  group('Frame delete releases children', () {
    test('deleting frame clears frameId on all children', () {
      final child2 = RectangleElement(
        id: const ElementId('r4'),
        x: 200,
        y: 200,
        width: 50,
        height: 25,
        frameId: 'f1',
      );
      final ctx = contextWith(
        elements: [frame1, childRect, child2],
        selectedIds: {frame1.id},
      );

      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;

      // Should have RemoveElementResult for the frame
      final removes = compound.results.whereType<RemoveElementResult>();
      expect(removes.any((r) => r.id == frame1.id), isTrue);

      // Should have UpdateElementResults clearing frameId on children
      final updates = compound.results.whereType<UpdateElementResult>();
      final childUpdates = updates.where(
        (u) => u.element.frameId == null &&
            (u.element.id == childRect.id || u.element.id == child2.id),
      );
      expect(childUpdates.length, 2,
          reason: 'Both children should have frameId cleared');
    });

    test('deleting non-frame element does not release frame children', () {
      final ctx = contextWith(
        elements: [frame1, childRect, outsideRect],
        selectedIds: {outsideRect.id},
      );

      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;

      // Should NOT have any updates for childRect
      final updates = compound.results.whereType<UpdateElementResult>();
      expect(updates.where((u) => u.element.id == childRect.id), isEmpty);
    });
  });

  // --- D. Double-click frame selects children ---

  group('Double-click frame', () {
    test('clicking on frame selects only the frame', () {
      final ctx = contextWith(
        elements: [frame1, childRect],
      );

      // Click on frame body (not on any child)
      final result = click(const Point(350, 250), ctx);
      expect(result, isA<SetSelectionResult>());
      final sel = (result! as SetSelectionResult).selectedIds;
      expect(sel, {frame1.id});
    });
  });

  // --- F. Duplicate/paste with frameId remapping ---

  group('Duplicate frame with children', () {
    test('duplicating frame remaps frameId on children', () {
      final ctx = contextWith(
        elements: [frame1, childRect],
        selectedIds: {frame1.id, childRect.id},
      );

      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();

      // Should have 2 new elements (frame + child)
      expect(adds, hasLength(2));

      // The duplicated frame should be a FrameElement
      final dupFrame = adds.firstWhere((a) => a.element is FrameElement);
      // The duplicated child should have frameId matching the new frame's id
      final dupChild = adds.firstWhere((a) => a.element is! FrameElement);
      expect(dupChild.element.frameId, dupFrame.element.id.value);
    });

    test('pasting frame remaps frameId on children', () {
      final clipFrame = FrameElement(
        id: const ElementId('cf1'),
        x: 0,
        y: 0,
        width: 200,
        height: 200,
        label: 'Clip Frame',
      );
      final clipChild = RectangleElement(
        id: const ElementId('cr1'),
        x: 10,
        y: 10,
        width: 50,
        height: 30,
        frameId: 'cf1',
      );

      final ctx = contextWith(
        elements: [],
        clipboard: [clipFrame, clipChild],
      );

      final result = tool.onKeyEvent('v', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final adds = compound.results.whereType<AddElementResult>().toList();

      expect(adds, hasLength(2));
      final pastedFrame = adds.firstWhere((a) => a.element is FrameElement);
      final pastedChild = adds.firstWhere((a) => a.element is! FrameElement);
      expect(pastedChild.element.frameId, pastedFrame.element.id.value);
    });
  });

  // --- Move frame moves children ---

  group('Moving frame moves children', () {
    test('moving a selected frame also moves its children', () {
      final ctx = contextWith(
        elements: [frame1, childRect],
        selectedIds: {frame1.id},
      );

      // Drag frame by (20, 20)
      final result = drag(
        const Point(200, 150), // center of frame
        const Point(220, 170),
        ctx,
      );

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();

      // Should update both frame and child
      final frameUpdate = updates.where((u) => u.element.id == frame1.id);
      final childUpdate = updates.where((u) => u.element.id == childRect.id);
      expect(frameUpdate, hasLength(1));
      expect(childUpdate, hasLength(1));

      // Child should have moved by same delta
      final movedChild = childUpdate.first.element;
      expect(movedChild.x, closeTo(childRect.x + 20, 0.1));
      expect(movedChild.y, closeTo(childRect.y + 20, 0.1));
    });

    test('nudging frame also nudges children', () {
      final ctx = contextWith(
        elements: [frame1, childRect],
        selectedIds: {frame1.id},
      );

      final result = tool.onKeyEvent('ArrowRight', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final updates = compound.results.whereType<UpdateElementResult>().toList();

      final childUpdate =
          updates.where((u) => u.element.id == childRect.id).toList();
      expect(childUpdate, hasLength(1));
      expect(childUpdate.first.element.x, childRect.x + 1);
    });
  });
}
