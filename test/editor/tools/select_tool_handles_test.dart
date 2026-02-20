import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late SelectTool tool;

  // Rectangle at (100, 100) size 200x100
  // Handles: TL(100,100), TC(200,100), TR(300,100)
  //          ML(100,150), MR(300,150)
  //          BL(100,200), BC(200,200), BR(300,200)
  //          Rot(200, 80) — 20 above topCenter
  final rect1 = RectangleElement(
    id: const ElementId('r1'),
    x: 100,
    y: 100,
    width: 200,
    height: 100,
  );

  // Rotated rectangle for rotation hit-test tests
  final rotatedRect = RectangleElement(
    id: const ElementId('rr1'),
    x: 100,
    y: 100,
    width: 200,
    height: 100,
    angle: math.pi / 4, // 45 degrees
  );

  final line1 = LineElement(
    id: const ElementId('l1'),
    x: 50,
    y: 50,
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

  group('Handle hit-testing', () {
    test('hit-test on bottomRight resize handle detects resize', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // bottomRight handle is at (300, 200)
      tool.onPointerDown(const Point(300, 200), ctx);
      // Drag enough to start
      final result = tool.onPointerMove(const Point(320, 220), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.width, greaterThan(rect1.width));
      expect(updated.height, greaterThan(rect1.height));
    });

    test('hit-test on topLeft resize handle detects resize', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // topLeft handle is at (100, 100)
      tool.onPointerDown(const Point(100, 100), ctx);
      final result = tool.onPointerMove(const Point(80, 80), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 80); // Moved left
      expect(updated.y, 80); // Moved up
    });

    test('hit-test on rotation handle returns rotation', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // Rotation handle is at (200, 80) — 20 above topCenter
      tool.onPointerDown(const Point(200, 80), ctx);
      final result = tool.onPointerMove(const Point(220, 80), ctx);
      expect(result, isA<UpdateElementResult>());
      // After rotation, the angle should change
      final updated = (result! as UpdateElementResult).element;
      expect(updated.angle, isNot(0.0));
    });

    test('hit-test on point handle returns correct index for line', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // First point is at absolute (50+0, 50+0) = (50, 50)
      tool.onPointerDown(const Point(50, 50), ctx);
      final result = tool.onPointerMove(const Point(60, 60), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      // First point should have moved
      expect(updated.points[0].x, closeTo(10, 0.1)); // 0 + 10
      expect(updated.points[0].y, closeTo(10, 0.1)); // 0 + 10
      // Second point stays
      expect(updated.points[1], const Point(100, 100));
    });

    test('hit-test on element body does not trigger handle mode', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // Center of element is at (200, 150) — far from any handle
      tool.onPointerDown(const Point(200, 150), ctx);
      final result = tool.onPointerMove(const Point(220, 170), ctx);
      // Should be a move, not a resize
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // Position shifted by (20, 20), size unchanged
      expect(updated.x, rect1.x + 20);
      expect(updated.y, rect1.y + 20);
      expect(updated.width, rect1.width);
      expect(updated.height, rect1.height);
    });

    test('hit-test with rotation accounts for element angle', () {
      final ctx = contextWith(
        elements: [rotatedRect],
        selectedIds: {rotatedRect.id},
      );
      // For a 45° rotated element, the unrotated bottomRight is at (300, 200).
      // We need to rotate (300, 200) around center (200, 150) by 45° to get
      // the rotated screen position.
      // But hit-testing unrotates the point, so clicking AT the handle's
      // unrotated position should still work.
      // The handle positions in SelectionOverlay are in unrotated space.
      // After unrotation, clicking (300, 200) should map to itself for angle=0,
      // but for a rotated element we need the rotated screen position.
      // Actually - handles are computed in unrotated space, and the hit-test
      // unrotates the click point. So if we click exactly where the handle
      // VISUALLY appears (rotated), the unrotation should map it to the handle.
      final cos45 = math.cos(math.pi / 4);
      final sin45 = math.sin(math.pi / 4);
      // bottomRight handle at (300, 200) relative to center (200, 150)
      // = offset (100, 50)
      // Rotated: (100*cos45 - 50*sin45, 100*sin45 + 50*cos45) + center
      final rotX = 200 + 100 * cos45 - 50 * sin45;
      final rotY = 150 + 100 * sin45 + 50 * cos45;
      tool.onPointerDown(Point(rotX, rotY), ctx);
      final result = tool.onPointerMove(Point(rotX + 10, rotY + 10), ctx);
      // Should detect as resize
      expect(result, isA<UpdateElementResult>());
    });

    test('no hit when point is far from handles', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // Point at (500, 500) is far from element and all handles
      tool.onPointerDown(const Point(500, 500), ctx);
      tool.onPointerMove(const Point(520, 520), ctx);
      // Should be marquee (no element hit)
      expect(tool.overlay, isNotNull);
      expect(tool.overlay!.marqueeRect, isNotNull);
    });

    test('priority: point handle over resize handle for line endpoint at corner', () {
      // Create a line whose first point is at the element's origin (like topLeft)
      final lineAtCorner = LineElement(
        id: const ElementId('lc1'),
        x: 100,
        y: 100,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
      );
      final ctx = contextWith(
        elements: [lineAtCorner],
        selectedIds: {lineAtCorner.id},
      );
      // Click at the first point (100, 100) which is also where a "topLeft" handle would be
      tool.onPointerDown(const Point(100, 100), ctx);
      final result = tool.onPointerMove(const Point(110, 110), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      // Should be a point drag, not a resize — first point moved, second stayed
      expect(updated.points[0].x, closeTo(10, 0.1));
      expect(updated.points[0].y, closeTo(10, 0.1));
      expect(updated.points[1], const Point(100, 100));
    });
  });

  group('Single-element resize', () {
    test('drag bottomRight handle increases width and height', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(300, 200), ctx);
      final result = tool.onPointerMove(const Point(350, 250), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.width, 250); // 200 + 50
      expect(updated.height, 150); // 100 + 50
      expect(updated.x, 100); // unchanged
      expect(updated.y, 100); // unchanged
    });

    test('drag topLeft handle adjusts x, y, width, height', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(100, 100), ctx);
      // Drag by (-20, -30)
      final result = tool.onPointerMove(const Point(80, 70), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 80); // 100 - 20
      expect(updated.y, 70); // 100 - 30
      expect(updated.width, 220); // 200 + 20
      expect(updated.height, 130); // 100 + 30
    });

    test('drag topCenter only changes y and height', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(200, 100), ctx);
      final result = tool.onPointerMove(const Point(220, 80), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 100); // unchanged
      expect(updated.y, 80); // 100 - 20
      expect(updated.width, 200); // unchanged
      expect(updated.height, 120); // 100 + 20
    });

    test('drag middleRight only changes width', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(300, 150), ctx);
      final result = tool.onPointerMove(const Point(350, 170), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 100); // unchanged
      expect(updated.y, 100); // unchanged
      expect(updated.width, 250); // 200 + 50
      expect(updated.height, 100); // unchanged
    });

    test('minimum size enforced when shrinking below 10', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // Drag bottomRight way past topLeft
      tool.onPointerDown(const Point(300, 200), ctx);
      final result = tool.onPointerMove(const Point(100, 100), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.width, greaterThanOrEqualTo(10));
      expect(updated.height, greaterThanOrEqualTo(10));
    });

    test('shift+resize maintains aspect ratio', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // rect1 is 200x100, aspect = 2:1
      tool.onPointerDown(const Point(300, 200), ctx, shift: true);
      // Drag only width significantly more than height
      final result = tool.onPointerMove(const Point(400, 220), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // Aspect ratio should be maintained (2:1)
      final aspect = updated.width / updated.height;
      expect(aspect, closeTo(2.0, 0.01));
    });

    test('resize on pointerUp returns final result', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(300, 200), ctx);
      tool.onPointerMove(const Point(320, 220), ctx);
      final result = tool.onPointerUp(const Point(350, 250), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.width, 250);
      expect(updated.height, 150);
    });

    test('drag middleLeft only changes x and width', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(100, 150), ctx);
      final result = tool.onPointerMove(const Point(80, 170), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 80);
      expect(updated.y, 100); // unchanged
      expect(updated.width, 220);
      expect(updated.height, 100); // unchanged
    });

    test('drag topRight adjusts right edge and top', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(300, 100), ctx);
      final result = tool.onPointerMove(const Point(320, 80), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 100); // unchanged
      expect(updated.y, 80);
      expect(updated.width, 220);
      expect(updated.height, 120);
    });

    test('drag bottomLeft adjusts left edge and bottom', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(100, 200), ctx);
      final result = tool.onPointerMove(const Point(80, 220), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 80);
      expect(updated.y, 100); // unchanged
      expect(updated.width, 220);
      expect(updated.height, 120);
    });

    test('drag bottomCenter only changes height', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(200, 200), ctx);
      final result = tool.onPointerMove(const Point(220, 230), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, 100); // unchanged
      expect(updated.y, 100); // unchanged
      expect(updated.width, 200); // unchanged
      expect(updated.height, 130);
    });
  });

  group('Single-element rotation', () {
    test('drag rotation handle clockwise produces positive angle delta', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // Rotation handle at (200, 80)
      tool.onPointerDown(const Point(200, 80), ctx);
      // Drag clockwise (to the right and down)
      final result = tool.onPointerMove(const Point(250, 100), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.angle, isNot(0.0));
    });

    test('shift+rotate snaps to 15 degree increments', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(200, 80), ctx, shift: true);
      // Make a large drag to produce a rotation
      final result = tool.onPointerMove(const Point(300, 150), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // Angle should be a multiple of π/12 (15°)
      final snapUnit = math.pi / 12;
      final remainder = (updated.angle % snapUnit).abs();
      expect(remainder < 0.001 || (snapUnit - remainder) < 0.001, isTrue);
    });

    test('rotation preserves element position and size', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      tool.onPointerDown(const Point(200, 80), ctx);
      final result = tool.onPointerMove(const Point(250, 100), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      expect(updated.x, rect1.x);
      expect(updated.y, rect1.y);
      expect(updated.width, rect1.width);
      expect(updated.height, rect1.height);
    });
  });

  group('Point dragging', () {
    test('drag line point moves only that point', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // Second point absolute position: (50+100, 50+100) = (150, 150)
      tool.onPointerDown(const Point(150, 150), ctx);
      final result = tool.onPointerMove(const Point(170, 160), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      // First point unchanged
      expect(updated.points[0], const Point(0, 0));
      // Second point moved by (20, 10)
      expect(updated.points[1].x, closeTo(120, 0.1));
      expect(updated.points[1].y, closeTo(110, 0.1));
    });

    test('point drag updates bounding box when point moves outside', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // Drag second point far away
      tool.onPointerDown(const Point(150, 150), ctx);
      final result = tool.onPointerMove(const Point(250, 250), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // Width/height should have increased
      expect(updated.width, greaterThan(line1.width));
      expect(updated.height, greaterThan(line1.height));
    });

    test('point drag on first point of line', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // First point at absolute (50, 50)
      tool.onPointerDown(const Point(50, 50), ctx);
      final result = tool.onPointerMove(const Point(40, 30), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.points[0].x, closeTo(-10, 0.1));
      expect(updated.points[0].y, closeTo(-20, 0.1));
      expect(updated.points[1], const Point(100, 100));
    });
  });
}
