import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/diamond_element.dart';
import '../../core/elements/element_id.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

const double _minDragDistance = 5.0;

/// Tool for creating diamond elements by dragging.
class DiamondTool implements Tool {
  Point? _start;
  Point? _current;

  @override
  ToolType get type => ToolType.diamond;

  @override
  ToolResult? onPointerDown(Point point, ToolContext context) {
    _start = point;
    _current = point;
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    if (_start == null) return null;
    _current = point;
    return null;
  }

  @override
  ToolResult? onPointerUp(Point point, ToolContext context) {
    final start = _start;
    if (start == null) return null;

    _current = point;
    if (start.distanceTo(point) < _minDragDistance) {
      reset();
      return null;
    }

    final x = math.min(start.x, point.x);
    final y = math.min(start.y, point.y);
    final w = (start.x - point.x).abs();
    final h = (start.y - point.y).abs();

    final element = DiamondElement(
      id: ElementId.generate(),
      x: x,
      y: y,
      width: w,
      height: h,
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
    if (key == 'Escape') reset();
    return null;
  }

  @override
  ToolOverlay? get overlay {
    final start = _start;
    final current = _current;
    if (start == null || current == null) return null;
    final x = math.min(start.x, current.x);
    final y = math.min(start.y, current.y);
    final w = (start.x - current.x).abs();
    final h = (start.y - current.y).abs();
    return ToolOverlay(creationBounds: Bounds.fromLTWH(x, y, w, h));
  }

  @override
  void reset() {
    _start = null;
    _current = null;
  }
}
