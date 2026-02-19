import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/text_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late TextTool tool;
  late ToolContext context;

  setUp(() {
    tool = TextTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('TextTool', () {
    test('type is text', () {
      expect(tool.type, ToolType.text);
    });

    test('click creates TextElement at position', () {
      tool.onPointerDown(const Point(100, 200), context);
      final result = tool.onPointerUp(const Point(100, 200), context);

      expect(result, isA<CompoundResult>());
      final compound = result! as CompoundResult;
      expect(compound.results[0], isA<AddElementResult>());
      final addResult = compound.results[0] as AddElementResult;
      expect(addResult.element, isA<TextElement>());
      expect(addResult.element.x, 100);
      expect(addResult.element.y, 200);
    });

    test('created text has empty string', () {
      tool.onPointerDown(const Point(100, 200), context);
      final result = tool.onPointerUp(const Point(100, 200), context);
      final compound = result! as CompoundResult;
      final text =
          (compound.results[0] as AddElementResult).element as TextElement;
      expect(text.text, '');
    });

    test('result includes selection and switch to select', () {
      tool.onPointerDown(const Point(100, 200), context);
      final result = tool.onPointerUp(const Point(100, 200), context);
      final compound = result! as CompoundResult;
      expect(compound.results[1], isA<SetSelectionResult>());
      expect((compound.results[2] as SwitchToolResult).toolType,
          ToolType.select);
    });

    test('overlay is null', () {
      expect(tool.overlay, isNull);
    });

    test('reset is safe to call', () {
      tool.reset();
      expect(tool.overlay, isNull);
    });
  });
}
