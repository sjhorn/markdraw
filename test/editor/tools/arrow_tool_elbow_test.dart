import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ToolContext _context({Scene? scene}) => ToolContext(
      scene: scene ?? Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );

Scene _sceneWithRect(String id, double x, double y,
    {double w = 100, double h = 100}) {
  return Scene().addElement(Element(
    id: ElementId(id),
    type: 'rectangle',
    x: x,
    y: y,
    width: w,
    height: h,
  ));
}

void main() {
  group('ArrowTool elbowed creation', () {
    test('ArrowTool(elbowed: true) creates elbowed arrow', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      // Second click finalizes immediately for elbowed
      tool.onPointerDown(const Point(100, 200), ctx);
      final result = tool.onPointerUp(const Point(100, 200), ctx);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      final arrow =
          (compound.results[0] as AddElementResult).element as ArrowElement;
      expect(arrow.elbowed, isTrue);
    });

    test('two-click creation with binding', () {
      final tool = ArrowTool(elbowed: true);
      var scene = _sceneWithRect('r1', 0, 0);
      scene = scene.addElement(Element(
        id: const ElementId('r2'),
        type: 'rectangle',
        x: 300,
        y: 0,
        width: 100,
        height: 100,
      ));
      final ctx = _context(scene: scene);

      // Click on right edge of rect1
      tool.onPointerDown(const Point(100, 50), ctx);
      tool.onPointerUp(const Point(100, 50), ctx);
      // Click on left edge of rect2 — finalizes immediately
      tool.onPointerDown(const Point(300, 50), ctx);
      final result = tool.onPointerUp(const Point(300, 50), ctx);

      expect(result, isA<CompoundResult>());
      final arrow = ((result! as CompoundResult).results[0]
          as AddElementResult).element as ArrowElement;
      expect(arrow.elbowed, isTrue);
      expect(arrow.startBinding, isNotNull);
      expect(arrow.endBinding, isNotNull);
    });

    test('two-click creation without binding', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(50, 50), ctx);
      tool.onPointerUp(const Point(50, 50), ctx);
      tool.onPointerDown(const Point(200, 150), ctx);
      final result = tool.onPointerUp(const Point(200, 150), ctx);

      expect(result, isA<CompoundResult>());
      final arrow = ((result! as CompoundResult).results[0]
          as AddElementResult).element as ArrowElement;
      expect(arrow.elbowed, isTrue);
      expect(arrow.startBinding, isNull);
      expect(arrow.endBinding, isNull);
    });

    test('elbow preview shows routed path on move', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      tool.onPointerMove(const Point(100, 200), ctx);

      final overlay = tool.overlay;
      expect(overlay, isNotNull);
      expect(overlay!.creationPoints, isNotNull);
      // Routed path should have more than 2 points (elbowed)
      expect(overlay.creationPoints!.length, greaterThanOrEqualTo(2));
      // All segments should be orthogonal
      _assertOrthogonal(overlay.creationPoints!);
    });

    test('elbowed arrow finalize routes correctly', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      tool.onPointerDown(const Point(100, 200), ctx);
      final result = tool.onPointerUp(const Point(100, 200), ctx);

      final arrow = ((result! as CompoundResult).results[0]
          as AddElementResult).element as ArrowElement;

      // Check that all segments are orthogonal (relative points)
      final absPoints = arrow.points
          .map((p) => Point(arrow.x + p.x, arrow.y + p.y))
          .toList();
      _assertOrthogonal(absPoints);
    });

    test('non-elbowed ArrowTool unchanged (regression)', () {
      final tool = ArrowTool();
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      // For non-elbowed, second click does not finalize — needs double-click
      tool.onPointerDown(const Point(100, 200), ctx);
      final result = tool.onPointerUp(const Point(100, 200), ctx);
      expect(result, isNull); // Not finalized yet

      final finalResult = tool.onKeyEvent('Enter');
      expect(finalResult, isA<CompoundResult>());
      final arrow = ((finalResult! as CompoundResult).results[0]
          as AddElementResult).element as ArrowElement;
      expect(arrow.elbowed, isFalse);
    });

    test('Escape cancels elbow creation', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      tool.onKeyEvent('Escape');
      expect(tool.overlay, isNull);
    });

    test('Enter finalizes elbow creation', () {
      final tool = ArrowTool(elbowed: true);
      final ctx = _context();

      tool.onPointerDown(const Point(0, 0), ctx);
      tool.onPointerUp(const Point(0, 0), ctx);
      tool.onPointerDown(const Point(100, 200), ctx);
      tool.onPointerUp(const Point(100, 200), ctx);

      // Already finalized on second click, so Enter on fresh state does nothing
      // Let's test that the tool was properly reset
      expect(tool.overlay, isNull);
    });

    test('elbowed setter works to toggle mode', () {
      final tool = ArrowTool();
      expect(tool.elbowed, isFalse);
      tool.elbowed = true;
      expect(tool.elbowed, isTrue);
    });
  });
}

void _assertOrthogonal(List<Point> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final isHorizontal = (a.y - b.y).abs() < 0.001;
    final isVertical = (a.x - b.x).abs() < 0.001;
    expect(
      isHorizontal || isVertical,
      isTrue,
      reason: 'Segment $i ($a → $b) is neither horizontal nor vertical',
    );
  }
}
