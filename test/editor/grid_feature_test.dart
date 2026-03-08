import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('MarkdrawController grid state', () {
    test('gridSize defaults to null', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      expect(controller.gridSize, isNull);
    });

    test('toggleGrid toggles between null and 20', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.toggleGrid();
      expect(controller.gridSize, 20);

      controller.toggleGrid();
      expect(controller.gridSize, isNull);
    });

    test('toggleGrid notifies listeners', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.toggleGrid();
      expect(notified, isTrue);
    });

    test('gridSize is passed to toolContext', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      expect(controller.toolContext.gridSize, isNull);

      controller.toggleGrid();
      expect(controller.toolContext.gridSize, 20);
    });

    test('grid persists in serialized document', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.toggleGrid();
      final content = controller.serializeScene();

      expect(content, contains('grid: 20'));
    });

    test('grid not in serialized document when null', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final content = controller.serializeScene();
      expect(content, isNot(contains('grid:')));
    });

    test('grid loaded from document', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Create content with grid
      const content = '---\ngrid: 20\n---\n';
      controller.loadFromContent(content, 'test.markdraw');

      expect(controller.gridSize, 20);
    });

    test('grid roundtrip: save and reload', () {
      final controller1 = MarkdrawController();
      addTearDown(controller1.dispose);

      controller1.toggleGrid();
      final content = controller1.serializeScene();

      final controller2 = MarkdrawController();
      addTearDown(controller2.dispose);

      controller2.loadFromContent(content, 'test.markdraw');
      expect(controller2.gridSize, 20);
    });
  });

  group('StaticCanvasPainter grid', () {
    test('shouldRepaint returns true when gridSize changes', () {
      final adapter = RoughCanvasAdapter();
      final scene = Scene();

      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when gridSize is same', () {
      final adapter = RoughCanvasAdapter();
      final scene = Scene();

      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('shouldRepaint returns true when isDarkBackground changes', () {
      final adapter = RoughCanvasAdapter();
      final scene = Scene();

      final painter1 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
      );
      final painter2 = StaticCanvasPainter(
        scene: scene,
        adapter: adapter,
        viewport: const ViewportState(),
        gridSize: 20,
        isDarkBackground: true,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('accepts gridSize parameter', () {
      final painter = StaticCanvasPainter(
        scene: Scene(),
        adapter: RoughCanvasAdapter(),
        viewport: const ViewportState(),
        gridSize: 20,
      );

      expect(painter.gridSize, 20);
    });
  });
}
