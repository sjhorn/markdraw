import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('tool shortcuts', () {
    test('K maps to laser', () {
      expect(toolTypeForKey('k'), ToolType.laser);
    });

    test('I maps to eyedropper', () {
      expect(toolTypeForKey('i'), ToolType.eyedropper);
    });

    test('shortcutForToolType returns K for laser', () {
      expect(shortcutForToolType(ToolType.laser), 'K');
    });

    test('shortcutForToolType returns I for eyedropper', () {
      expect(shortcutForToolType(ToolType.eyedropper), 'I');
    });
  });

  group('tool factory', () {
    test('creates LaserTool', () {
      expect(createTool(ToolType.laser), isA<LaserTool>());
    });

    test('creates EyedropperTool', () {
      expect(createTool(ToolType.eyedropper), isA<EyedropperTool>());
    });
  });

  group('controller tool switching', () {
    test('switch to laser tool', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.laser);

      expect(controller.editorState.activeToolType, ToolType.laser);
      expect(controller.activeTool, isA<LaserTool>());
    });

    test('switch to eyedropper tool', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.eyedropper);

      expect(controller.editorState.activeToolType, ToolType.eyedropper);
      expect(controller.activeTool, isA<EyedropperTool>());
    });

    test('laser is not a creation tool', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.laser);
      expect(controller.isCreationTool, isFalse);
    });

    test('eyedropper is not a creation tool', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.eyedropper);
      expect(controller.isCreationTool, isFalse);
    });

    test('laser cursor is precise', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.laser);
      expect(controller.cursorForTool, isNotNull);
    });
  });
}
