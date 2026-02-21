import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/element_id.dart';
import '../../core/elements/line_element.dart';
import '../../core/math/point.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Tool for creating line elements by clicking to add points.
/// Double-click or Enter finalizes the line.
class LineTool implements Tool {
  final List<Point> _points = [];
  Point? _previewPoint;

  @override
  ToolType get type => ToolType.line;

  @override
  ToolResult? onPointerDown(Point point, ToolContext context) {
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    if (_points.isNotEmpty) {
      _previewPoint = point;
    }
    return null;
  }

  /// Extended onPointerUp with double-click detection.
  @override
  ToolResult? onPointerUp(Point point, ToolContext context,
      {bool isDoubleClick = false}) {
    _points.add(point);
    _previewPoint = null;

    if (isDoubleClick && _points.length >= 2) {
      return _finalize();
    }
    return null;
  }

  @override
  ToolResult? onKeyEvent(String key, {bool shift = false, bool ctrl = false, ToolContext? context}) {
    if ((key == 'Escape' || key == 'Enter') && _points.length >= 2) {
      return _finalize();
    }
    if (key == 'Escape') {
      reset();
      return null;
    }
    return null;
  }

  ToolResult _finalize() {
    final element = _createElement(_points);
    reset();
    return CompoundResult([
      AddElementResult(element),
      SetSelectionResult({element.id}),
      SwitchToolResult(ToolType.select),
    ]);
  }

  /// Creates the line element. Override in subclasses for different element types.
  LineElement _createElement(List<Point> points) {
    return _buildLineElement(points);
  }

  LineElement _buildLineElement(List<Point> points) {
    final minX = points.map((p) => p.x).reduce(math.min);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final maxY = points.map((p) => p.y).reduce(math.max);

    // Make points relative to origin
    final relativePoints =
        points.map((p) => Point(p.x - minX, p.y - minY)).toList();

    return LineElement(
      id: ElementId.generate(),
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
      points: relativePoints,
    );
  }

  @override
  ToolOverlay? get overlay {
    if (_points.isEmpty) return null;
    final displayPoints = [..._points];
    if (_previewPoint != null) {
      displayPoints.add(_previewPoint!);
    }
    return ToolOverlay(creationPoints: displayPoints);
  }

  @override
  void reset() {
    _points.clear();
    _previewPoint = null;
  }
}
