import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SelectTool tool;

  /// 5-point elbowed arrow for testing 2D segment drag with cascade.
  /// Absolute points: (100,100)→(100,150)→(150,150)→(150,200)→(200,200)
  /// Segments:
  ///   0: vertical   (100,100)→(100,150)
  ///   1: horizontal  (100,150)→(150,150)
  ///   2: vertical   (150,150)→(150,200)
  ///   3: horizontal  (150,200)→(200,200)
  final fivePointArrow = ArrowElement(
    id: const ElementId('ea5'),
    x: 100,
    y: 100,
    width: 100,
    height: 100,
    points: const [
      Point(0, 0),
      Point(0, 50),
      Point(50, 50),
      Point(50, 100),
      Point(100, 100),
    ],
    endArrowhead: Arrowhead.arrow,
    arrowType: ArrowType.sharpElbow,
  );

  /// 3-point elbowed arrow (L-shape).
  /// Absolute points: (50,50)→(50,150)→(150,150)
  /// Segments:
  ///   0: vertical   (50,50)→(50,150)
  ///   1: horizontal  (50,150)→(150,150)
  final lShapeArrow = ArrowElement(
    id: const ElementId('ea3'),
    x: 50,
    y: 50,
    width: 100,
    height: 100,
    points: const [Point(0, 0), Point(0, 100), Point(100, 100)],
    endArrowhead: Arrowhead.arrow,
    arrowType: ArrowType.sharpElbow,
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

  List<Point> absolutePoints(ArrowElement arrow) {
    return arrow.points
        .map((p) => Point(arrow.x + p.x, arrow.y + p.y))
        .toList();
  }

  void assertOrthogonal(List<Point> points) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final isHorizontal = (a.y - b.y).abs() < 0.5;
      final isVertical = (a.x - b.x).abs() < 0.5;
      expect(isHorizontal || isVertical, isTrue,
          reason: 'Segment $i ($a → $b) is neither horizontal nor vertical');
    }
  }

  group('2D segment drag on 5-point elbow arrow', () {
    test('drag horizontal segment diagonally moves segment and cascades', () {
      final ctx = contextWith(
        elements: [fivePointArrow],
        selectedIds: {fivePointArrow.id},
      );

      // Click on horizontal segment 1: y=150, between x=100..150
      // Drag diagonally by (10, 20)
      tool.onPointerDown(const Point(125, 150), ctx);
      final result = tool.onPointerMove(const Point(135, 170), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // Segment 1 endpoints moved by (dx=10, dy=20):
      //   was (100,150)→(150,150), now ~(110,170)→(160,170)
      // Cascade: P[0] x += 10, P[3] x += 10
      //   P[0]: was (100,100), now ~(110,100)
      //   P[3]: was (150,200), now ~(160,200)
      // P[4] unchanged: (200,200)

      expect(abs[0].x, closeTo(110, 1));
      expect(abs[0].y, closeTo(100, 1));
      expect(abs[1].x, closeTo(110, 1));
      expect(abs[1].y, closeTo(170, 1));
      expect(abs[2].x, closeTo(160, 1));
      expect(abs[2].y, closeTo(170, 1));
      expect(abs[3].x, closeTo(160, 1));
      expect(abs[3].y, closeTo(200, 1));
      expect(abs[4].x, closeTo(200, 1));
      expect(abs[4].y, closeTo(200, 1));
    });

    test('drag vertical segment diagonally moves segment and cascades', () {
      final ctx = contextWith(
        elements: [fivePointArrow],
        selectedIds: {fivePointArrow.id},
      );

      // Click on vertical segment 2: x=150, between y=150..200
      // Drag diagonally by (15, -10)
      tool.onPointerDown(const Point(150, 175), ctx);
      final result = tool.onPointerMove(const Point(165, 165), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // Segment 2 endpoints moved by (dx=15, dy=-10):
      //   was (150,150)→(150,200), now ~(165,140)→(165,190)
      // Cascade: P[1] y += -10, P[4] y += -10
      //   P[1]: was (100,150), now ~(100,140)
      //   P[4]: was (200,200), now ~(200,190)
      // P[0] unchanged: (100,100)

      expect(abs[0].x, closeTo(100, 1));
      expect(abs[0].y, closeTo(100, 1));
      expect(abs[1].x, closeTo(100, 1));
      expect(abs[1].y, closeTo(140, 1));
      expect(abs[2].x, closeTo(165, 1));
      expect(abs[2].y, closeTo(140, 1));
      expect(abs[3].x, closeTo(165, 1));
      expect(abs[3].y, closeTo(190, 1));
      expect(abs[4].x, closeTo(200, 1));
      expect(abs[4].y, closeTo(190, 1));
    });
  });

  group('2D segment drag on terminal segments (3-point arrow)', () {
    test('drag first segment (vertical) diagonally — no cascade before', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Segment 0 is vertical: (50,50)→(50,150)
      // Drag by (10, 5)
      tool.onPointerDown(const Point(50, 100), ctx);
      final result = tool.onPointerMove(const Point(60, 105), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // P[0] += (10, 5) → (60, 55)
      // P[1] += (10, 5) → (60, 155)
      // Cascade: no P[-1]; P[2] y += 5 → (150, 155)
      expect(abs[0].x, closeTo(60, 1));
      expect(abs[0].y, closeTo(55, 1));
      expect(abs[1].x, closeTo(60, 1));
      expect(abs[1].y, closeTo(155, 1));
      expect(abs[2].x, closeTo(150, 1));
      expect(abs[2].y, closeTo(155, 1));
    });

    test('drag last segment (horizontal) diagonally — no cascade after', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Segment 1 is horizontal: (50,150)→(150,150)
      // Drag by (-5, 15)
      tool.onPointerDown(const Point(100, 150), ctx);
      final result = tool.onPointerMove(const Point(95, 165), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // P[1] += (-5, 15) → (45, 165)
      // P[2] += (-5, 15) → (145, 165)
      // Cascade: P[0] x += -5 → (45, 50); no P[3]
      expect(abs[0].x, closeTo(45, 1));
      expect(abs[0].y, closeTo(50, 1));
      expect(abs[1].x, closeTo(45, 1));
      expect(abs[1].y, closeTo(165, 1));
      expect(abs[2].x, closeTo(145, 1));
      expect(abs[2].y, closeTo(165, 1));
    });
  });

  group('2D segment drag — pure perpendicular still works', () {
    test('horizontal segment dragged purely vertically (dx=0)', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Segment 1 horizontal: drag vertically by 20 (no x change)
      tool.onPointerDown(const Point(100, 150), ctx);
      final result = tool.onPointerMove(const Point(100, 170), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // Y shifts by 20, X unchanged
      expect(abs[1].y, closeTo(170, 1));
      expect(abs[2].y, closeTo(170, 1));
      expect(abs[1].x, closeTo(50, 1));
      expect(abs[2].x, closeTo(150, 1));
    });

    test('vertical segment dragged purely horizontally (dy=0)', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Segment 0 vertical: drag horizontally by -20 (no y change)
      tool.onPointerDown(const Point(50, 100), ctx);
      final result = tool.onPointerMove(const Point(30, 100), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      assertOrthogonal(abs);

      // X shifts by -20, Y unchanged
      expect(abs[0].x, closeTo(30, 1));
      expect(abs[1].x, closeTo(30, 1));
      expect(abs[0].y, closeTo(50, 1));
      expect(abs[1].y, closeTo(150, 1));
    });
  });

  group('Point handle priority over segment on elbowed arrows', () {
    test('clicking on endpoint enters dragPoint mode, not dragSegment', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Click exactly on the first endpoint (50, 50)
      tool.onPointerDown(const Point(50, 50), ctx);
      // Drag to a new position — should be a point drag (only P[0] moves)
      final result = tool.onPointerMove(const Point(30, 40), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      // If it were segment drag, both P[0] and P[1] would move.
      // With point drag, only P[0] moves.
      // P[0] moved to ~(30, 40), P[1] stays at (50, 150)
      expect(abs[0].x, closeTo(30, 1));
      expect(abs[0].y, closeTo(40, 1));
      expect(abs[1].x, closeTo(50, 1));
      expect(abs[1].y, closeTo(150, 1));
    });

    test('clicking on last endpoint enters dragPoint mode', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Click exactly on the last endpoint (150, 150)
      tool.onPointerDown(const Point(150, 150), ctx);
      // Drag — should only move the last point
      final result = tool.onPointerMove(const Point(170, 160), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      // P[2] moved, P[1] stays at (50, 150)
      expect(abs[2].x, closeTo(170, 1));
      expect(abs[2].y, closeTo(160, 1));
      expect(abs[1].x, closeTo(50, 1));
      expect(abs[1].y, closeTo(150, 1));
    });

    test('clicking mid-segment still enters dragSegment mode', () {
      final ctx = contextWith(
        elements: [lShapeArrow],
        selectedIds: {lShapeArrow.id},
      );

      // Click in the middle of vertical segment 0 at (50, 100)
      // This is 50 units from both endpoints — well away from point handles
      tool.onPointerDown(const Point(50, 100), ctx);
      // Drag horizontally — segment drag moves both P[0] and P[1]
      final result = tool.onPointerMove(const Point(70, 100), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      final abs = absolutePoints(updated);

      // Both P[0] and P[1] moved in X (segment drag behavior)
      expect(abs[0].x, closeTo(70, 1));
      expect(abs[1].x, closeTo(70, 1));
    });
  });

  group('Point drag on elbowed arrow creates binding', () {
    test('drag elbowed arrow start point near shape → binding created', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 30,
        width: 40,
        height: 40,
      );
      final arrow = ArrowElement(
        id: const ElementId('ea1'),
        x: 100,
        y: 50,
        width: 100,
        height: 0,
        points: const [Point(0, 0), Point(0, 50), Point(100, 50)],
        endArrowhead: Arrowhead.arrow,
        arrowType: ArrowType.sharpElbow,
      );

      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {arrow.id},
      );

      // Click on start point (100, 50) and drag near rect's right edge (40, 50)
      tool.onPointerDown(const Point(100, 50), ctx);
      tool.onPointerMove(const Point(40, 50), ctx);
      final result = tool.onPointerUp(const Point(40, 50), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      expect(updated.startBinding, isNotNull,
          reason: 'Start binding should be set after dragging near shape');
      expect(updated.startBinding!.elementId, 'r1');
    });

    test('drag elbowed arrow last point near shape → endBinding created', () {
      final rect = RectangleElement(
        id: const ElementId('r2'),
        x: 250,
        y: 80,
        width: 60,
        height: 60,
      );
      final arrow = ArrowElement(
        id: const ElementId('ea2'),
        x: 50,
        y: 50,
        width: 200,
        height: 100,
        points: const [Point(0, 0), Point(0, 100), Point(200, 100)],
        endArrowhead: Arrowhead.arrow,
        arrowType: ArrowType.sharpElbow,
      );

      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {arrow.id},
      );

      // Click on last point (250, 150) and drag near rect's left edge (250, 110)
      tool.onPointerDown(const Point(250, 150), ctx);
      tool.onPointerMove(const Point(250, 110), ctx);
      final result = tool.onPointerUp(const Point(250, 110), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      expect(updated.endBinding, isNotNull,
          reason: 'End binding should be set after dragging near shape');
      expect(updated.endBinding!.elementId, 'r2');
    });
  });

  group('Point drag on regular (non-elbowed) arrow creates binding', () {
    test('drag regular arrow endpoint near shape → binding created', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 30,
        width: 40,
        height: 40,
      );
      final arrow = ArrowElement(
        id: const ElementId('ra1'),
        x: 100,
        y: 50,
        width: 100,
        height: 0,
        points: const [Point(0, 0), Point(100, 0)],
        endArrowhead: Arrowhead.arrow,
      );

      final scene = Scene().addElement(rect).addElement(arrow);
      final ctx = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {arrow.id},
      );

      // Click on start point (100, 50) and drag near rect's right edge (40, 50)
      tool.onPointerDown(const Point(100, 50), ctx);
      tool.onPointerMove(const Point(40, 50), ctx);
      final result = tool.onPointerUp(const Point(40, 50), ctx);
      expect(result, isA<UpdateElementResult>());

      final updated =
          (result! as UpdateElementResult).element as ArrowElement;
      expect(updated.startBinding, isNotNull,
          reason: 'Start binding should be set after dragging near shape');
      expect(updated.startBinding!.elementId, 'r1');
    });
  });
}
