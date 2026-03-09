import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('tool shortcuts', () {
    test('K maps to laser', () {
      expect(toolTypeForKey('k'), ToolType.laser);
    });

    test('shortcutForToolType returns K for laser', () {
      expect(shortcutForToolType(ToolType.laser), 'K');
    });
  });

  group('tool factory', () {
    test('creates LaserTool', () {
      expect(createTool(ToolType.laser), isA<LaserTool>());
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

    test('laser is not a creation tool', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.laser);
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
