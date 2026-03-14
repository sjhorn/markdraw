import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('copyStyle / pasteStyle', () {
    test('captures stroke style from first selected element', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          strokeColor: '#ff0000',
          backgroundColor: '#00ff00',
          strokeWidth: 4.0,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      controller.copyStyle();

      expect(controller.copiedStyle, isNotNull);
      expect(controller.copiedStyle!.strokeColor, '#ff0000');
      expect(controller.copiedStyle!.backgroundColor, '#00ff00');
      expect(controller.copiedStyle!.strokeWidth, 4.0);
    });

    test('applies copied style to selected elements', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene()
          .addElement(
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              strokeColor: '#ff0000',
              strokeWidth: 4.0,
            ),
          )
          .addElement(
            RectangleElement(
              id: const ElementId('r2'),
              x: 200,
              y: 0,
              width: 100,
              height: 50,
              strokeColor: '#000000',
              strokeWidth: 2.0,
            ),
          );
      controller.loadScene(scene);

      // Copy style from r1
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));
      controller.copyStyle();

      // Paste style onto r2
      controller.applyResult(SetSelectionResult({const ElementId('r2')}));
      controller.pasteStyle();

      final r2 = controller.editorState.scene.getElementById(
        const ElementId('r2'),
      )!;
      expect(r2.strokeColor, '#ff0000');
      expect(r2.strokeWidth, 4.0);
    });

    test('no-op when no style copied', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      // Should not throw
      controller.pasteStyle();
    });

    test('no-op when nothing selected for copy', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.copyStyle();
      expect(controller.copiedStyle, isNull);
    });
  });

  group('flip via SelectTool', () {
    test('Shift+H flips horizontally', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene()
          .addElement(
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 50,
              height: 50,
            ),
          )
          .addElement(
            RectangleElement(
              id: const ElementId('r2'),
              x: 150,
              y: 0,
              width: 50,
              height: 50,
            ),
          );
      controller.loadScene(scene);
      controller.applyResult(
        SetSelectionResult({const ElementId('r1'), const ElementId('r2')}),
      );

      controller.dispatchKey('h', shift: true);

      final r1 = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      final r2 = controller.editorState.scene.getElementById(
        const ElementId('r2'),
      )!;
      expect(r1.x, 150);
      expect(r2.x, 0);
    });

    test('Shift+V flips vertically', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene()
          .addElement(
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 50,
              height: 50,
            ),
          )
          .addElement(
            RectangleElement(
              id: const ElementId('r2'),
              x: 0,
              y: 150,
              width: 50,
              height: 50,
            ),
          );
      controller.loadScene(scene);
      controller.applyResult(
        SetSelectionResult({const ElementId('r1'), const ElementId('r2')}),
      );

      controller.dispatchKey('v', shift: true);

      final r1 = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      final r2 = controller.editorState.scene.getElementById(
        const ElementId('r2'),
      )!;
      expect(r1.y, 150);
      expect(r2.y, 0);
    });

    test('flip no-op when all locked', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 100,
          y: 50,
          width: 50,
          height: 50,
          locked: true,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      controller.dispatchKey('h', shift: true);

      final r1 = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      expect(r1.x, 100);
    });
  });

  group('shape cycling via SelectTool', () {
    test('Tab cycles rectangle to diamond', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 50,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      controller.dispatchKey('Tab');

      final elem = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      expect(elem, isA<DiamondElement>());
      expect(elem.x, 10);
    });

    test('Tab no-op for non-shape elements', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        LineElement(
          id: const ElementId('l1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('l1')}));

      controller.dispatchKey('Tab');

      final elem = controller.editorState.scene.getElementById(
        const ElementId('l1'),
      )!;
      expect(elem, isA<LineElement>());
    });

    test('Shift+Tab reverses cycle', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 50,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      controller.dispatchKey('Tab', shift: true);

      final elem = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      expect(elem, isA<EllipseElement>());
    });

    test('Tab no-op when locked', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 50,
          locked: true,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));

      controller.dispatchKey('Tab');

      final elem = controller.editorState.scene.getElementById(
        const ElementId('r1'),
      )!;
      expect(elem, isA<RectangleElement>());
    });
  });
}
