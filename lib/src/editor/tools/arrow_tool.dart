import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/arrow_element.dart';
import '../../core/elements/element.dart';
import '../../core/elements/element_id.dart';
import '../../core/elements/line_element.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import '../bindings/binding_utils.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Tool for creating arrow elements by clicking to add points.
/// Double-click or Enter finalizes the arrow.
class ArrowTool implements Tool {
  final List<Point> _points = [];
  Point? _previewPoint;
  PointBinding? _startBinding;
  PointBinding? _endBinding;
  Element? _bindTarget;

  @override
  ToolType get type => ToolType.arrow;

  @override
  ToolResult? onPointerDown(Point point, ToolContext context) {
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    if (_points.isNotEmpty) {
      _previewPoint = point;
      _bindTarget = BindingUtils.findBindTarget(context.scene, point);
    }
    return null;
  }

  /// Extended onPointerUp with double-click detection.
  @override
  ToolResult? onPointerUp(Point point, ToolContext context,
      {bool isDoubleClick = false}) {
    // Check for binding at this point
    final target = BindingUtils.findBindTarget(context.scene, point);
    Point snappedPoint = point;

    if (target != null) {
      final fixedPoint = BindingUtils.computeFixedPoint(target, point);
      final binding = PointBinding(
        elementId: target.id.value,
        fixedPoint: fixedPoint,
      );
      snappedPoint = BindingUtils.resolveBindingPoint(target, binding);

      if (_points.isEmpty) {
        // This will be the first point (start)
        _startBinding = binding;
      } else {
        // This will be the last point (end) — updated on each click
        _endBinding = binding;
      }
    } else {
      if (_points.isEmpty) {
        _startBinding = null;
      } else {
        _endBinding = null;
      }
    }

    _points.add(snappedPoint);
    _previewPoint = null;
    _bindTarget = null;

    if (isDoubleClick && _points.length >= 2) {
      return _finalize();
    }
    return null;
  }

  @override
  ToolResult? onKeyEvent(String key,
      {bool shift = false, bool ctrl = false, ToolContext? context}) {
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
    final element = _createArrow(_points);
    reset();
    return CompoundResult([
      AddElementResult(element),
      SetSelectionResult({element.id}),
      SwitchToolResult(ToolType.select),
    ]);
  }

  ArrowElement _createArrow(List<Point> points) {
    final minX = points.map((p) => p.x).reduce(math.min);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final maxY = points.map((p) => p.y).reduce(math.max);

    final relativePoints =
        points.map((p) => Point(p.x - minX, p.y - minY)).toList();

    return ArrowElement(
      id: ElementId.generate(),
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
      points: relativePoints,
      endArrowhead: Arrowhead.arrow,
      startBinding: _startBinding,
      endBinding: _endBinding,
    );
  }

  @override
  ToolOverlay? get overlay {
    if (_points.isEmpty) return null;
    final displayPoints = [..._points];
    if (_previewPoint != null) {
      displayPoints.add(_previewPoint!);
    }
    Bounds? targetBounds;
    if (_bindTarget != null) {
      targetBounds = Bounds.fromLTWH(
        _bindTarget!.x,
        _bindTarget!.y,
        _bindTarget!.width,
        _bindTarget!.height,
      );
    }
    return ToolOverlay(
      creationPoints: displayPoints,
      bindTargetBounds: targetBounds,
    );
  }

  @override
  void reset() {
    _points.clear();
    _previewPoint = null;
    _startBinding = null;
    _endBinding = null;
    _bindTarget = null;
  }
}
