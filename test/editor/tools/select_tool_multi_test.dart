import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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

  final rect1 = RectangleElement(
    id: const ElementId('r1'),
    x: 10,
    y: 10,
    width: 100,
    height: 50,
  );

  final rect2 = RectangleElement(
    id: const ElementId('r2'),
    x: 200,
    y: 200,
    width: 80,
    height: 40,
  );

  final rect3 = RectangleElement(
    id: const ElementId('r3'),
    x: 400,
    y: 400,
    width: 60,
    height: 30,
  );

  final line1 = LineElement(
    id: const ElementId('l1'),
    x: 300,
    y: 300,
    width: 100,
    height: 100,
    points: [const Point(0, 0), const Point(100, 100)],
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

  group('Multi-element move', () {
    test('move 2 rectangles offsets both by same delta', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Click on rect1 center (60, 35)
      tool.onPointerDown(const Point(60, 35), ctx);
      final result = tool.onPointerMove(const Point(80, 55), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));
      for (final r in compound.results) {
        expect(r, isA<UpdateElementResult>());
        final updated = (r as UpdateElementResult).element;
        if (updated.id == rect1.id) {
          expect(updated.x, rect1.x + 20);
          expect(updated.y, rect1.y + 20);
        } else {
          expect(updated.x, rect2.x + 20);
          expect(updated.y, rect2.y + 20);
        }
      }
    });

    test('move rectangle + line offsets both positions', () {
      final ctx = contextWith(
        elements: [rect1, line1],
        selectedIds: {rect1.id, line1.id},
      );
      tool.onPointerDown(const Point(60, 35), ctx);
      final result = tool.onPointerMove(const Point(70, 45), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        if (updated.id == line1.id) {
          expect(updated.x, line1.x + 10);
          expect(updated.y, line1.y + 10);
        }
      }
    });

    test('move 3 elements produces CompoundResult with 3 updates', () {
      final ctx = contextWith(
        elements: [rect1, rect2, rect3],
        selectedIds: {rect1.id, rect2.id, rect3.id},
      );
      tool.onPointerDown(const Point(60, 35), ctx);
      final result = tool.onPointerMove(const Point(80, 55), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(3));
      for (final r in compound.results) {
        expect(r, isA<UpdateElementResult>());
      }
    });

    test('drag unselected with existing multi-select re-selects single', () {
      // Test: click on an element NOT in selectedIds
      final rect3Local = RectangleElement(
        id: const ElementId('r3'),
        x: 500,
        y: 500,
        width: 100,
        height: 50,
      );
      final ctx2 = contextWith(
        elements: [rect1, rect2, rect3Local],
        selectedIds: {rect1.id, rect2.id},
      );
      // Click on rect3 which is not selected
      tool.onPointerDown(const Point(550, 525), ctx2);
      final result = tool.onPointerMove(const Point(570, 545), ctx2);
      // Should be a single-element move with select
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      // First result: SetSelection, Second: UpdateElement
      expect(compound.results[0], isA<SetSelectionResult>());
      expect((compound.results[0] as SetSelectionResult).selectedIds,
          {rect3Local.id});
      expect(compound.results[1], isA<UpdateElementResult>());
    });

    test('multi-move on pointerUp returns final positions', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      tool.onPointerDown(const Point(60, 35), ctx);
      tool.onPointerMove(const Point(70, 45), ctx);
      final result = tool.onPointerUp(const Point(80, 55), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        if (updated.id == rect1.id) {
          expect(updated.x, rect1.x + 20);
          expect(updated.y, rect1.y + 20);
        }
      }
    });
  });

  group('Multi-element resize', () {
    test('multi-resize from bottomRight scales all proportionally', () {
      // rect1: (10, 10, 100, 50), rect2: (200, 200, 80, 40)
      // Union: left=10, top=10, right=280, bottom=240
      // Union size: 270 x 230
      // bottomRight handle at (280, 240)
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      tool.onPointerDown(const Point(280, 240), ctx);
      // Drag bottomRight by +27, +23 → new union 297 x 253
      final result = tool.onPointerMove(const Point(307, 263), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));

      // Both elements should be scaled proportionally
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        expect(updated.width, greaterThan(0));
        expect(updated.height, greaterThan(0));
      }
    });

    test('multi-resize preserves relative positions', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Union: 10,10 → 280,240 (270x230)
      tool.onPointerDown(const Point(280, 240), ctx);
      // Double the size: drag to (550, 470) → new union 540x460
      final result = tool.onPointerMove(const Point(550, 470), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;

      Element? updatedR1;
      Element? updatedR2;
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        if (updated.id == rect1.id) updatedR1 = updated;
        if (updated.id == rect2.id) updatedR2 = updated;
      }

      expect(updatedR1, isNotNull);
      expect(updatedR2, isNotNull);
      // r1 should be scaled by 2x
      expect(updatedR1!.width, closeTo(200, 1));
      expect(updatedR1.height, closeTo(100, 1));
      // r2 should also be scaled by 2x
      expect(updatedR2!.width, closeTo(160, 1));
      expect(updatedR2.height, closeTo(80, 1));
    });

    test('multi-resize enforces minimum union size', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Try to shrink to nearly zero
      tool.onPointerDown(const Point(280, 240), ctx);
      final result = tool.onPointerMove(const Point(15, 15), ctx);
      expect(result, isA<CompoundResult>());
      // All elements should still have positive dimensions
      final compound = result! as CompoundResult;
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        expect(updated.width, greaterThan(0));
        expect(updated.height, greaterThan(0));
      }
    });
  });

  group('Multi-element rotation', () {
    test('multi-rotate rotates all elements around union center', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      // Union center: ((10+280)/2, (10+240)/2) = (145, 125)
      // Rotation handle at (145, 10 - 20) = (145, -10)
      tool.onPointerDown(const Point(145, -10), ctx);
      // Drag to produce rotation
      final result = tool.onPointerMove(const Point(200, 0), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results, hasLength(2));

      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        expect(updated.angle, isNot(0.0));
      }
    });

    test('multi-rotate preserves each element own angle increase', () {
      // Start with rect1 at angle=0 and a rotated rect
      final rotRect = RectangleElement(
        id: const ElementId('rr1'),
        x: 200,
        y: 200,
        width: 80,
        height: 40,
        angle: math.pi / 6, // 30 degrees
      );
      final ctx = contextWith(
        elements: [rect1, rotRect],
        selectedIds: {rect1.id, rotRect.id},
      );
      // Rotation handle
      tool.onPointerDown(const Point(145, -10), ctx);
      final result = tool.onPointerMove(const Point(200, 0), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;

      double? r1Angle;
      double? rrAngle;
      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        if (updated.id == rect1.id) r1Angle = updated.angle;
        if (updated.id == rotRect.id) rrAngle = updated.angle;
      }

      // Both should have the same delta applied
      // rotRect started at pi/6, so it should be pi/6 + delta
      // rect1 started at 0, so it should be 0 + delta
      expect(r1Angle, isNotNull);
      expect(rrAngle, isNotNull);
      expect(rrAngle! - r1Angle!, closeTo(math.pi / 6, 0.01));
    });

    test('shift+multi-rotate snaps to 15 degrees', () {
      final ctx = contextWith(
        elements: [rect1, rect2],
        selectedIds: {rect1.id, rect2.id},
      );
      tool.onPointerDown(const Point(145, -10), ctx, shift: true);
      final result = tool.onPointerMove(const Point(250, 50), ctx);
      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;

      for (final r in compound.results) {
        final updated = (r as UpdateElementResult).element;
        const snapUnit = math.pi / 12;
        final remainder = (updated.angle % snapUnit).abs();
        expect(remainder < 0.01 || (snapUnit - remainder) < 0.01, isTrue);
      }
    });
  });
}
