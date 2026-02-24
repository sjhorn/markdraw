import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late SelectTool tool;

  /// Elbowed arrow with three points forming an L-shape.
  /// Absolute points: (50,50) → (50,150) → (150,150)
  /// Segment 0: vertical from (50,50) to (50,150)
  /// Segment 1: horizontal from (50,150) to (150,150)
  final elbowArrow = ArrowElement(
    id: const ElementId('ea1'),
    x: 50,
    y: 50,
    width: 100,
    height: 100,
    points: const [Point(0, 0), Point(0, 100), Point(100, 100)],
    endArrowhead: Arrowhead.arrow,
    elbowed: true,
  );

  /// Regular (non-elbowed) arrow for regression tests.
  final regularArrow = ArrowElement(
    id: const ElementId('ra1'),
    x: 50,
    y: 50,
    width: 100,
    height: 100,
    points: const [Point(0, 0), Point(100, 100)],
    endArrowhead: Arrowhead.arrow,
  );

  /// Rectangle for binding tests.
  final rect1 = RectangleElement(
    id: const ElementId('r1'),
    x: 0,
    y: 0,
    width: 40,
    height: 40,
    boundElements: [const BoundElement(id: 'ea1', type: 'arrow')],
  );

  /// Elbowed arrow bound to rect1 at start.
  final boundElbow = ArrowElement(
    id: const ElementId('ea1'),
    x: 50,
    y: 50,
    width: 100,
    height: 100,
    points: const [Point(0, 0), Point(0, 100), Point(100, 100)],
    endArrowhead: Arrowhead.arrow,
    elbowed: true,
    startBinding: const PointBinding(
      elementId: 'r1',
      fixedPoint: Point(1, 0.5),
    ),
  );

  setUp(() {
    tool = SelectTool();
  });

  ToolContext contextWith({
    List<Element> elements = const [],
    Set<ElementId> selectedIds = const {},
  }) {
    var scene = Scene();
    for (final e in elements) {
      scene = scene.addElement(e);
    }
    return ToolContext(
      scene: scene,
      viewport: const ViewportState(),
      selectedIds: selectedIds,
    );
  }

  group('Segment hit-test', () {
    test('detects vertical segment on elbowed arrow', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      // Click near the vertical segment (50, 80) — close to x=50, between y=50..150
      tool.onPointerDown(const Point(52, 80), ctx);
      // Drag horizontally to verify segment drag mode is active
      final result = tool.onPointerMove(const Point(72, 80), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // Vertical segment dragged horizontally → X of both endpoints changed
      expect(updated.points[0].x, closeTo(20, 1));
      expect(updated.points[1].x, closeTo(20, 1));
      // Y values unchanged
      expect(updated.points[0].y, closeTo(0, 1));
      expect(updated.points[1].y, closeTo(100, 1));
    });

    test('detects horizontal segment on elbowed arrow', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      // Click near horizontal segment (100, 150) — close to y=150, between x=50..150
      tool.onPointerDown(const Point(100, 148), ctx);
      // Drag vertically
      final result = tool.onPointerMove(const Point(100, 128), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // Horizontal segment dragged vertically → Y of both endpoints changed
      expect(updated.points[1].y, closeTo(80, 1));
      expect(updated.points[2].y, closeTo(80, 1));
      // X values unchanged
      expect(updated.points[1].x, closeTo(0, 1));
      expect(updated.points[2].x, closeTo(100, 1));
    });
  });

  group('Segment drag', () {
    test('drag horizontal segment changes Y of endpoints', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      // Click on horizontal segment at y=150
      tool.onPointerDown(const Point(100, 150), ctx);
      final result = tool.onPointerMove(const Point(100, 170), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // dy = +20 applied to segment 1 (horizontal)
      expect(updated.points[1].y, closeTo(120, 1));
      expect(updated.points[2].y, closeTo(120, 1));
    });

    test('drag vertical segment changes X of endpoints', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      // Click on vertical segment at x=50
      tool.onPointerDown(const Point(50, 100), ctx);
      final result = tool.onPointerMove(const Point(30, 100), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // dx = -20 applied to segment 0 (vertical)
      expect(updated.points[0].x, closeTo(-20, 1));
      expect(updated.points[1].x, closeTo(-20, 1));
    });

    test('segment drag recalculates bounding box', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      // Drag horizontal segment (segment 1) down by 30
      tool.onPointerDown(const Point(100, 150), ctx);
      final result = tool.onPointerMove(const Point(100, 180), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // Height should increase since segment moved beyond original bounds
      expect(updated.height, greaterThanOrEqualTo(elbowArrow.height));
    });

    test('segment drag finalizes on pointer up', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      tool.onPointerDown(const Point(100, 150), ctx);
      tool.onPointerMove(const Point(100, 130), ctx);
      final result = tool.onPointerUp(const Point(100, 130), ctx);
      expect(result, isA<UpdateElementResult>());
    });
  });

  group('Delete bound shape preserves elbowed flag', () {
    test('deleting bound shape clears binding but keeps elbowed', () {
      final ctx = contextWith(
        elements: [rect1, boundElbow],
        selectedIds: {rect1.id},
      );
      // Delete the rectangle
      final result = tool.onKeyEvent('Delete', context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // Should include removal of rect1 and update of arrow (clearing binding)
      final updates = compound.results.whereType<UpdateElementResult>();
      final arrowUpdate = updates.firstWhere(
        (u) => u.element.id == boundElbow.id,
      );
      final updatedArrow = arrowUpdate.element as ArrowElement;
      expect(updatedArrow.elbowed, isTrue);
      expect(updatedArrow.startBinding, isNull);
    });
  });

  group('Duplicate preserves elbowed', () {
    test('duplicate elbowed arrow preserves elbowed flag and points', () {
      final ctx = contextWith(
        elements: [elbowArrow],
        selectedIds: {elbowArrow.id},
      );
      final result = tool.onKeyEvent('d', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final added = compound.results.whereType<AddElementResult>().first;
      final dup = added.element as ArrowElement;
      expect(dup.elbowed, isTrue);
      expect(dup.points.length, elbowArrow.points.length);
      expect(dup.id, isNot(elbowArrow.id));
    });
  });

  group('Non-elbowed regression', () {
    test('point drag on regular arrow uses dragPoint mode (not segment)', () {
      final ctx = contextWith(
        elements: [regularArrow],
        selectedIds: {regularArrow.id},
      );
      // Click near end point (150, 150)
      tool.onPointerDown(const Point(150, 150), ctx);
      final result = tool.onPointerMove(const Point(170, 170), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      // Should be a point drag — last point moved
      expect(updated.points.last.x, closeTo(120, 1));
      expect(updated.points.last.y, closeTo(120, 1));
      // First point unchanged
      expect(updated.points.first, const Point(0, 0));
    });
  });
}
