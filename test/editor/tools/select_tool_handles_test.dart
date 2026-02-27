import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SelectTool tool;

  // Rectangle at (100, 100) size 200x100
  // Padded handles (6px): TL(94,94), TC(200,94), TR(306,94)
  //                        ML(94,150), MR(306,150)
  //                        BL(94,206), BC(200,206), BR(306,206)
  //                        Rot(200, 74) — 20 above padded topCenter
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
      // bottomRight handle is at (306, 206) — padded 6px from element edge
      tool.onPointerDown(const Point(306, 206), ctx);
      // Drag enough to start
      final result = tool.onPointerMove(const Point(326, 226), ctx);
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
      // First point moved to absolute (60, 60)
      final absFirst = Point(updated.x + updated.points[0].x,
          updated.y + updated.points[0].y);
      expect(absFirst.x, closeTo(60, 0.1));
      expect(absFirst.y, closeTo(60, 0.1));
      // Second point stays at absolute (150, 150)
      final absSecond = Point(updated.x + updated.points[1].x,
          updated.y + updated.points[1].y);
      expect(absSecond.x, closeTo(150, 0.1));
      expect(absSecond.y, closeTo(150, 0.1));
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
      // bottomRight handle at (306, 206) relative to center (200, 150)
      // = offset (106, 56) — padded 6px from element edge
      // Rotated: (106*cos45 - 56*sin45, 106*sin45 + 56*cos45) + center
      final rotX = 200 + 106 * cos45 - 56 * sin45;
      final rotY = 150 + 106 * sin45 + 56 * cos45;
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
      // Should be a point drag, not a resize — check absolute positions
      final absFirst = Point(updated.x + updated.points[0].x,
          updated.y + updated.points[0].y);
      expect(absFirst.x, closeTo(110, 0.1));
      expect(absFirst.y, closeTo(110, 0.1));
      final absSecond = Point(updated.x + updated.points[1].x,
          updated.y + updated.points[1].y);
      expect(absSecond.x, closeTo(200, 0.1));
      expect(absSecond.y, closeTo(200, 0.1));
    });
  });

  group('Rotated element resize', () {
    /// Computes the world-space position of a corner relative to element bounds.
    /// [fx, fy] are fractions: (-1,-1) = topLeft, (1,1) = bottomRight, etc.
    Point worldCorner(Element elem, double fx, double fy) {
      final cx = elem.x + elem.width / 2;
      final cy = elem.y + elem.height / 2;
      final localX = fx * elem.width / 2;
      final localY = fy * elem.height / 2;
      final cosA = math.cos(elem.angle);
      final sinA = math.sin(elem.angle);
      return Point(
        cx + localX * cosA - localY * sinA,
        cy + localX * sinA + localY * cosA,
      );
    }

    test('resize rotated element via bottomRight preserves topLeft anchor', () {
      final ctx = contextWith(
        elements: [rotatedRect],
        selectedIds: {rotatedRect.id},
      );
      // Record the world-space position of the topLeft corner before resize
      final anchorBefore = worldCorner(rotatedRect, -1, -1);

      // Click at the visual position of the bottomRight handle (rotated)
      // Handle padded 6px from element edge: offset (106, 56) from center
      final cos45 = math.cos(math.pi / 4);
      final sin45 = math.sin(math.pi / 4);
      final handleX = 200 + 106 * cos45 - 56 * sin45;
      final handleY = 150 + 106 * sin45 + 56 * cos45;
      tool.onPointerDown(Point(handleX, handleY), ctx);

      // Drag outward along the element's local-right direction (rotated 45°)
      final dragX = handleX + 20 * cos45;
      final dragY = handleY + 20 * sin45;
      final result = tool.onPointerMove(Point(dragX, dragY), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;

      // Width should increase
      expect(updated.width, greaterThan(rotatedRect.width));

      // The topLeft anchor should remain at the same world position
      final anchorAfter = worldCorner(updated, -1, -1);
      expect(anchorAfter.x, closeTo(anchorBefore.x, 1.0));
      expect(anchorAfter.y, closeTo(anchorBefore.y, 1.0));
    });

    test('resize rotated element via topCenter preserves bottomCenter anchor', () {
      final ctx = contextWith(
        elements: [rotatedRect],
        selectedIds: {rotatedRect.id},
      );
      // Record the world-space position of the bottomCenter before resize
      final anchorBefore = worldCorner(rotatedRect, 0, 1);

      // topCenter handle at (200, 100) in unrotated space
      final cos45 = math.cos(math.pi / 4);
      final sin45 = math.sin(math.pi / 4);
      final handleX = 200 + 50 * sin45;
      final handleY = 150 - 50 * cos45;
      tool.onPointerDown(Point(handleX, handleY), ctx);

      // Drag outward from center (extending the top edge)
      final dirX = handleX - 200;
      final dirY = handleY - 150;
      final dirLen = math.sqrt(dirX * dirX + dirY * dirY);
      final dragX = handleX + (dirX / dirLen) * 20;
      final dragY = handleY + (dirY / dirLen) * 20;
      final result = tool.onPointerMove(Point(dragX, dragY), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;

      // Height should increase
      expect(updated.height, greaterThan(rotatedRect.height));

      // The bottomCenter anchor should remain at the same world position
      final anchorAfter = worldCorner(updated, 0, 1);
      expect(anchorAfter.x, closeTo(anchorBefore.x, 1.0));
      expect(anchorAfter.y, closeTo(anchorBefore.y, 1.0));
    });

    test('resize non-rotated element via bottomRight preserves topLeft position', () {
      // Sanity check: non-rotated case should also preserve anchor
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // bottomRight handle padded 6px from element edge
      tool.onPointerDown(const Point(306, 206), ctx);
      final result = tool.onPointerMove(const Point(356, 256), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element;
      // For non-rotated, x/y should stay unchanged (topLeft is the anchor)
      expect(updated.x, 100);
      expect(updated.y, 100);
      expect(updated.width, 250);
      expect(updated.height, 150);
    });
  });

  group('Single-element resize', () {
    test('drag bottomRight handle increases width and height', () {
      final ctx = contextWith(
        elements: [rect1],
        selectedIds: {rect1.id},
      );
      // bottomRight handle padded 6px from element edge
      tool.onPointerDown(const Point(306, 206), ctx);
      final result = tool.onPointerMove(const Point(356, 256), ctx);
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
      // topLeft handle padded 6px from element edge
      tool.onPointerDown(const Point(94, 94), ctx);
      // Drag by (-20, -30)
      final result = tool.onPointerMove(const Point(74, 64), ctx);
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
      // bottomRight handle padded 6px from element edge
      tool.onPointerDown(const Point(306, 206), ctx);
      tool.onPointerMove(const Point(326, 226), ctx);
      final result = tool.onPointerUp(const Point(356, 256), ctx);
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
      // topRight handle padded 6px from element edge
      tool.onPointerDown(const Point(306, 94), ctx);
      final result = tool.onPointerMove(const Point(326, 74), ctx);
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
      // bottomLeft handle padded 6px from element edge
      tool.onPointerDown(const Point(94, 206), ctx);
      final result = tool.onPointerMove(const Point(74, 226), ctx);
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
      const snapUnit = math.pi / 12;
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

  group('Line/Arrow resize scales points', () {
    test('resize line via middleRight scales points proportionally', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // line1 at (50,50) size 100x100, points [(0,0), (100,100)]
      // middleRight handle at (166, 100) — padded 16px from element edge
      tool.onPointerDown(const Point(166, 100), ctx);
      // Drag to (216, 100) → new width=150, height=100 (middleRight only changes width)
      final result = tool.onPointerMove(const Point(216, 100), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      // scaleX=1.5, scaleY=1.0
      expect(updated.width, 150);
      expect(updated.height, 100);
      expect(updated.points[0], const Point(0, 0));
      expect(updated.points[1].x, closeTo(150, 0.1));
      expect(updated.points[1].y, closeTo(100, 0.1));
    });

    test('resize arrow via middleRight scales points proportionally', () {
      // Arrow with non-zero dimensions, endpoints not at handles
      final arrow = ArrowElement(
        id: const ElementId('a2'),
        x: 100,
        y: 100,
        width: 100,
        height: 50,
        points: [const Point(0, 0), const Point(100, 50)],
        endArrowhead: Arrowhead.arrow,
      );
      final ctx = contextWith(
        elements: [arrow],
        selectedIds: {arrow.id},
      );
      // middleRight handle at (216, 125) — padded 16px from element edge
      tool.onPointerDown(const Point(216, 125), ctx);
      // Drag to (266, 125) → new width=150, height=50
      final result = tool.onPointerMove(const Point(266, 125), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as ArrowElement;
      expect(updated.width, 150);
      expect(updated.height, 50);
      // Points should scale x by 1.5, y unchanged
      expect(updated.points[0], const Point(0, 0));
      expect(updated.points[1].x, closeTo(150, 0.1));
      expect(updated.points[1].y, closeTo(50, 0.1));
      // Arrow-specific fields preserved
      expect(updated.endArrowhead, Arrowhead.arrow);
    });

    test('resize line via bottomCenter scales only y of points', () {
      final ctx = contextWith(
        elements: [line1],
        selectedIds: {line1.id},
      );
      // line1 at (50,50) size 100x100
      // bottomCenter handle at (100, 166) — padded 16px from element edge
      tool.onPointerDown(const Point(100, 166), ctx);
      // Drag to (100, 216) → height 100→150
      final result = tool.onPointerMove(const Point(100, 216), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;
      expect(updated.width, 100);
      expect(updated.height, 150);
      // scaleX=1.0, scaleY=1.5
      expect(updated.points[0], const Point(0, 0));
      expect(updated.points[1].x, closeTo(100, 0.1));
      expect(updated.points[1].y, closeTo(150, 0.1));
    });

    test('resize freedraw via middleRight scales points proportionally', () {
      final freedraw = FreedrawElement(
        id: const ElementId('fd1'),
        x: 50,
        y: 50,
        width: 100,
        height: 80,
        points: [
          const Point(0, 0),
          const Point(50, 40),
          const Point(100, 80),
        ],
      );
      final ctx = contextWith(
        elements: [freedraw],
        selectedIds: {freedraw.id},
      );
      // middleRight handle at (150, 90) — not near any point
      tool.onPointerDown(const Point(150, 90), ctx);
      // Drag to (200, 90) → width 100→150
      final result = tool.onPointerMove(const Point(200, 90), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated =
          (result! as UpdateElementResult).element as FreedrawElement;
      expect(updated.width, 150);
      expect(updated.height, 80);
      // scaleX=1.5, scaleY=1.0
      expect(updated.points[0], const Point(0, 0));
      expect(updated.points[1].x, closeTo(75, 0.1));
      expect(updated.points[1].y, closeTo(40, 0.1));
      expect(updated.points[2].x, closeTo(150, 0.1));
      expect(updated.points[2].y, closeTo(80, 0.1));
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
      // Check absolute positions: first moved to (40, 30), second stays at (150, 150)
      final absFirst = Point(updated.x + updated.points[0].x,
          updated.y + updated.points[0].y);
      expect(absFirst.x, closeTo(40, 0.1));
      expect(absFirst.y, closeTo(30, 0.1));
      final absSecond = Point(updated.x + updated.points[1].x,
          updated.y + updated.points[1].y);
      expect(absSecond.x, closeTo(150, 0.1));
      expect(absSecond.y, closeTo(150, 0.1));
    });

    test('hit-test on rotated line point handle accounts for angle', () {
      // Horizontal line rotated 90° CW — points visually appear vertical
      final rotatedLine = LineElement(
        id: const ElementId('rl1'),
        x: 100,
        y: 100,
        width: 200,
        height: 0,
        angle: math.pi / 2,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      final ctx = contextWith(
        elements: [rotatedLine],
        selectedIds: {rotatedLine.id},
      );
      // Center of element is at (200, 100).
      // Unrotated first point is at (100, 100).
      // After 90° rotation around center (200, 100):
      // offset from center = (-100, 0), rotated 90° = (0, -100)
      // Visual position = (200, 0) — but that's outside our test range.
      // Actually: rotate (100,100) around (200,100) by pi/2:
      // dx=-100, dy=0 → rotated: (0*cos - (-100)*sin, 0*sin + (-100)*cos)
      // cos(pi/2)=0, sin(pi/2)=1 → (0, -100) + (200,100) = (200, 0)
      // Second point at (300,100) → dx=100,dy=0 → (0,100)+(200,100) = (200,200)
      // Click at the visual position of the second point
      tool.onPointerDown(const Point(200, 200), ctx);
      final result = tool.onPointerMove(const Point(210, 210), ctx);
      // Should detect as point drag and produce an update
      expect(result, isA<UpdateElementResult>());
    });

    test('point drag on rotated line preserves visual position of other points', () {
      // Horizontal line rotated 90° CW
      final rotatedLine = LineElement(
        id: const ElementId('rl2'),
        x: 100,
        y: 100,
        width: 200,
        height: 0,
        angle: math.pi / 2,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      final ctx = contextWith(
        elements: [rotatedLine],
        selectedIds: {rotatedLine.id},
      );
      // Visual positions before drag:
      // center = (200, 100), first at (200, 0), second at (200, 200)
      tool.onPointerDown(const Point(200, 200), ctx);
      // Drag right in screen space (+10x, 0y)
      final result = tool.onPointerMove(const Point(210, 200), ctx);
      expect(result, isA<UpdateElementResult>());
      final updated = (result! as UpdateElementResult).element as LineElement;

      // Compute visual positions (rotate absLocal around center by angle)
      final cx = updated.x + updated.width / 2;
      final cy = updated.y + updated.height / 2;
      final cos = math.cos(updated.angle);
      final sin = math.sin(updated.angle);

      Point visualPos(Point relPt) {
        final ax = updated.x + relPt.x;
        final ay = updated.y + relPt.y;
        final dx = ax - cx;
        final dy = ay - cy;
        return Point(dx * cos - dy * sin + cx, dx * sin + dy * cos + cy);
      }

      // First point (unchanged) should stay visually at (200, 0)
      final vis0 = visualPos(updated.points[0]);
      expect(vis0.x, closeTo(200, 1.0));
      expect(vis0.y, closeTo(0, 1.0));
      // Second point should have moved right by 10: visually at (210, 200)
      final vis1 = visualPos(updated.points[1]);
      expect(vis1.x, closeTo(210, 1.0));
      expect(vis1.y, closeTo(200, 1.0));
    });
  });
}
