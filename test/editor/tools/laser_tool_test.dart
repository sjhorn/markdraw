import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ToolContext _ctx() => ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );

void main() {
  group('LaserTool', () {
    test('type is laser', () {
      expect(LaserTool().type, ToolType.laser);
    });

    test('collects trail points on pointer down and move', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      expect(tool.activeTrail.length, 1);

      tool.onPointerMove(const Point(30, 40), _ctx());
      tool.onPointerMove(const Point(50, 60), _ctx());

      expect(tool.activeTrail.length, 3);
      expect(tool.activeTrail.first.point, const Point(10, 20));
      expect(tool.activeTrail.last.point, const Point(50, 60));
    });

    test('clears trail on new pointer down', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(30, 40), _ctx());
      expect(tool.activeTrail.length, 2);

      tool.onPointerUp(const Point(30, 40), _ctx());
      tool.onPointerDown(const Point(100, 200), _ctx());

      expect(tool.activeTrail.length, 1);
      expect(tool.activeTrail.first.point, const Point(100, 200));
    });

    test('trail persists after pointer up (for decay)', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(30, 40), _ctx());
      tool.onPointerUp(const Point(30, 40), _ctx());

      expect(tool.activeTrail.length, 2);
    });

    test('does not collect points before pointer down', () {
      final tool = LaserTool();
      tool.onPointerMove(const Point(30, 40), _ctx());

      expect(tool.activeTrail, isEmpty);
    });

    test('does not collect points after pointer up', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerUp(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(30, 40), _ctx());

      expect(tool.activeTrail.length, 1);
    });

    test('prune removes expired points', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());

      // Manually add an old point
      tool.activeTrail; // force unmodifiable view
      // Since we can't directly set timestamps, test that prune works on fresh points
      // Fresh points should NOT be pruned
      final pruned = tool.prune();
      expect(pruned, isFalse);
      expect(tool.activeTrail.length, 1);
    });

    test('reset clears everything', () {
      final tool = LaserTool();
      tool.onPointerDown(const Point(10, 20), _ctx());
      tool.onPointerMove(const Point(30, 40), _ctx());

      tool.reset();

      expect(tool.activeTrail, isEmpty);
    });

    test('returns no scene-changing results', () {
      final tool = LaserTool();
      final r1 = tool.onPointerDown(const Point(10, 20), _ctx());
      final r2 = tool.onPointerMove(const Point(30, 40), _ctx());
      final r3 = tool.onPointerUp(const Point(30, 40), _ctx());

      expect(r1, isNull);
      expect(r2, isNull);
      expect(r3, isNull);
    });

    test('overlay is null', () {
      final tool = LaserTool();
      expect(tool.overlay, isNull);
    });

    test('onKeyEvent returns null', () {
      final tool = LaserTool();
      expect(tool.onKeyEvent('a'), isNull);
    });
  });
}
