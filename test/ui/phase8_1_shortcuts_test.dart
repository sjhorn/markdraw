import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

Scene _sceneWithElements() {
  return Scene()
      .addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ))
      .addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 100,
        width: 80,
        height: 60,
      ));
}

Scene _sceneWithText() {
  return Scene().addElement(TextElement(
    id: const ElementId('t1'),
    x: 0,
    y: 0,
    width: 100,
    height: 20,
    text: 'hello',
    fontSize: 20,
  ));
}

void main() {
  group('panViewport', () {
    test('pans viewport down by given dy', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.panViewport(0, 100);

      expect(controller.editorState.viewport.offset.dy, 100);
      expect(controller.editorState.viewport.offset.dx, 0);
    });

    test('pans viewport right by given dx', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.panViewport(200, 0);

      expect(controller.editorState.viewport.offset.dx, 200);
      expect(controller.editorState.viewport.offset.dy, 0);
    });

    test('accumulates multiple pans', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.panViewport(50, 30);
      controller.panViewport(50, 30);

      expect(controller.editorState.viewport.offset.dx, 100);
      expect(controller.editorState.viewport.offset.dy, 60);
    });

    test('pans up with negative dy', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.panViewport(0, -150);

      expect(controller.editorState.viewport.offset.dy, -150);
    });

    test('preserves zoom level', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Set zoom first
      controller.applyResult(UpdateViewportResult(
        const ViewportState(zoom: 2.0),
      ));
      controller.panViewport(100, 50);

      expect(controller.editorState.viewport.zoom, 2.0);
    });
  });

  group('cycleFontSize', () {
    test('increases from 20 to 28', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.cycleFontSize(increase: true);

      expect(controller.defaultStyle.fontSize, 28);
    });

    test('decreases from 20 to 16', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.cycleFontSize(increase: false);

      expect(controller.defaultStyle.fontSize, 16);
    });

    test('clamps at max (36) when increasing', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Increase to 28, 36, then try again
      controller.cycleFontSize(increase: true); // 28
      controller.cycleFontSize(increase: true); // 36
      controller.cycleFontSize(increase: true); // still 36

      expect(controller.defaultStyle.fontSize, 36);
    });

    test('clamps at min (16) when decreasing', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.cycleFontSize(increase: false); // 16
      controller.cycleFontSize(increase: false); // still 16

      expect(controller.defaultStyle.fontSize, 16);
    });

    test('applies to selected text element', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithText());
      controller.applyResult(SetSelectionResult({const ElementId('t1')}));
      controller.pushHistory();

      controller.cycleFontSize(increase: true);

      final text = controller.editorState.scene
          .getElementById(const ElementId('t1')) as TextElement;
      expect(text.fontSize, 28);
    });

    test('cycles through all presets ascending', () {
      final controller = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(fontSize: 16),
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.defaultStyle.fontSize, 16);
      controller.cycleFontSize(increase: true);
      expect(controller.defaultStyle.fontSize, 20);
      controller.cycleFontSize(increase: true);
      expect(controller.defaultStyle.fontSize, 28);
      controller.cycleFontSize(increase: true);
      expect(controller.defaultStyle.fontSize, 36);
    });
  });

  group('resetCanvas', () {
    test('clears all elements', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      expect(controller.editorState.scene.activeElements.length, 2);

      controller.resetCanvas();

      expect(controller.editorState.scene.activeElements, isEmpty);
    });

    test('is undoable', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.resetCanvas();
      expect(controller.editorState.scene.activeElements, isEmpty);

      controller.undo();

      expect(controller.editorState.scene.activeElements.length, 2);
    });

    test('clears selection', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(
        SetSelectionResult({const ElementId('r1')}),
      );
      expect(controller.editorState.selectedIds, isNotEmpty);

      controller.resetCanvas();

      expect(controller.editorState.selectedIds, isEmpty);
    });

    test('notifies scene change callback', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      Scene? notified;
      controller.onSceneChanged = (scene) => notified = scene;

      controller.loadScene(_sceneWithElements());
      controller.resetCanvas();

      expect(notified, isNotNull);
      expect(notified!.activeElements, isEmpty);
    });
  });

  group('alignment shortcuts via SelectTool', () {
    test('Ctrl+Shift+Left aligns left', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('r2')},
      ));

      controller.dispatchKey('ArrowLeft', shift: true, ctrl: true);

      final r1 = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      final r2 = controller.editorState.scene
          .getElementById(const ElementId('r2'))!;
      expect(r1.x, 0);
      expect(r2.x, 0);
    });

    test('Ctrl+Shift+Right aligns right', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('r2')},
      ));

      controller.dispatchKey('ArrowRight', shift: true, ctrl: true);

      final r1 = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      final r2 = controller.editorState.scene
          .getElementById(const ElementId('r2'))!;
      // Both right edges should be at 280 (200+80)
      expect(r1.x + r1.width, 280);
      expect(r2.x + r2.width, 280);
    });

    test('Ctrl+Shift+Up aligns top', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('r2')},
      ));

      controller.dispatchKey('ArrowUp', shift: true, ctrl: true);

      final r1 = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      final r2 = controller.editorState.scene
          .getElementById(const ElementId('r2'))!;
      expect(r1.y, 0);
      expect(r2.y, 0);
    });

    test('Ctrl+Shift+Down aligns bottom', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('r2')},
      ));

      controller.dispatchKey('ArrowDown', shift: true, ctrl: true);

      final r1 = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      final r2 = controller.editorState.scene
          .getElementById(const ElementId('r2'))!;
      // Both bottom edges should be at 160 (100+60)
      expect(r1.y + r1.height, 160);
      expect(r2.y + r2.height, 160);
    });

    test('no-op with fewer than 2 selected elements', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.loadScene(_sceneWithElements());
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1')},
      ));

      final before = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      controller.dispatchKey('ArrowLeft', shift: true, ctrl: true);

      final after = controller.editorState.scene
          .getElementById(const ElementId('r1'))!;
      expect(after.x, before.x);
    });

    test('no-op when all elements are locked', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 0,
            y: 0,
            width: 100,
            height: 50,
            locked: true,
          ))
          .addElement(RectangleElement(
            id: const ElementId('r2'),
            x: 200,
            y: 100,
            width: 80,
            height: 60,
            locked: true,
          ));
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('r2')},
      ));

      controller.dispatchKey('ArrowLeft', shift: true, ctrl: true);

      // Should not have changed
      final r2 = controller.editorState.scene
          .getElementById(const ElementId('r2'))!;
      expect(r2.x, 200);
    });
  });
}
