import 'dart:ui';

import '../../core/elements/element_id.dart';
import '../../core/elements/text_element.dart';
import '../../core/math/point.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Tool for creating text elements by clicking.
class TextTool implements Tool {
  Point? _clickPoint;

  @override
  ToolType get type => ToolType.text;

  @override
  ToolResult? onPointerDown(Point point, ToolContext context) {
    _clickPoint = point;
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    return null;
  }

  @override
  ToolResult? onPointerUp(Point point, ToolContext context) {
    final click = _clickPoint;
    if (click == null) return null;

    final element = TextElement(
      id: ElementId.generate(),
      x: click.x,
      y: click.y,
      width: 0,
      height: 0,
      text: '',
    );

    reset();
    return CompoundResult([
      AddElementResult(element),
      SetSelectionResult({element.id}),
      SwitchToolResult(ToolType.select),
    ]);
  }

  @override
  ToolResult? onKeyEvent(String key, {bool shift = false, bool ctrl = false}) {
    return null;
  }

  @override
  ToolOverlay? get overlay => null;

  @override
  void reset() {
    _clickPoint = null;
  }
}
