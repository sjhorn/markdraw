import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

ToolContext _ctx() => ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );

void main() {
  group('EyedropperTool', () {
    test('type is eyedropper', () {
      expect(EyedropperTool().type, ToolType.eyedropper);
    });

    test('records click point on pointer down', () {
      final tool = EyedropperTool();
      tool.onPointerDown(const Point(42, 99), _ctx());

      expect(tool.clickPoint, const Point(42, 99));
    });

    test('returns no scene-changing results', () {
      final tool = EyedropperTool();
      final r1 = tool.onPointerDown(const Point(10, 20), _ctx());
      final r2 = tool.onPointerMove(const Point(30, 40), _ctx());
      final r3 = tool.onPointerUp(const Point(30, 40), _ctx());

      expect(r1, isNull);
      expect(r2, isNull);
      expect(r3, isNull);
    });

    test('overlay is null', () {
      expect(EyedropperTool().overlay, isNull);
    });

    test('onKeyEvent returns null', () {
      expect(EyedropperTool().onKeyEvent('a'), isNull);
    });

    test('reset clears click point', () {
      final tool = EyedropperTool();
      tool.onPointerDown(const Point(42, 99), _ctx());
      tool.reset();

      expect(tool.clickPoint, isNull);
    });
  });
}
