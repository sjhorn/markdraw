import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('zen mode', () {
    test('toggles zen mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      expect(controller.zenMode, isFalse);

      controller.toggleZenMode();
      expect(controller.zenMode, isTrue);

      controller.toggleZenMode();
      expect(controller.zenMode, isFalse);
    });
  });

  group('view mode', () {
    test('toggles view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      expect(controller.viewMode, isFalse);

      controller.toggleViewMode();
      expect(controller.viewMode, isTrue);

      controller.toggleViewMode();
      expect(controller.viewMode, isFalse);
    });

    test('forces hand tool when entering view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.rectangle);
      expect(controller.editorState.activeToolType, ToolType.rectangle);

      controller.toggleViewMode();

      expect(controller.editorState.activeToolType, ToolType.hand);
    });

    test('restores previous tool when exiting view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.rectangle);
      controller.toggleViewMode();
      controller.toggleViewMode();

      expect(controller.editorState.activeToolType, ToolType.rectangle);
    });

    test('blocks tool switching while in view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.toggleViewMode();
      controller.switchTool(ToolType.rectangle);

      expect(controller.editorState.activeToolType, ToolType.hand);
    });

    test('allows hand tool in view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.toggleViewMode();
      controller.switchTool(ToolType.hand);

      expect(controller.editorState.activeToolType, ToolType.hand);
    });

    test('clears selection when entering view mode', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ));
      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({const ElementId('r1')}));
      expect(controller.editorState.selectedIds, isNotEmpty);

      controller.toggleViewMode();

      expect(controller.editorState.selectedIds, isEmpty);
    });
  });

  group('color picker shortcuts', () {
    test('requestColorPicker sets pendingColorPicker', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.requestColorPicker(ColorPickerTarget.stroke);
      expect(controller.pendingColorPicker, ColorPickerTarget.stroke);
    });

    test('clearPendingColorPicker clears it', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.requestColorPicker(ColorPickerTarget.stroke);
      controller.clearPendingColorPicker();
      expect(controller.pendingColorPicker, isNull);
    });

    test('background target', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.requestColorPicker(ColorPickerTarget.background);
      expect(controller.pendingColorPicker, ColorPickerTarget.background);
    });

    test('font target', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.requestColorPicker(ColorPickerTarget.font);
      expect(controller.pendingColorPicker, ColorPickerTarget.font);
    });
  });
}
