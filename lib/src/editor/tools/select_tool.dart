import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/element.dart';
import '../../core/elements/element_id.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Minimum drag distance to distinguish a drag from a click.
const double _clickThreshold = 3.0;

/// Tool for selecting, moving, and marquee-selecting elements.
class SelectTool implements Tool {
  Point? _downPoint;
  Point? _current;
  Element? _hitElement;
  bool _isDragging = false;
  bool _isMarquee = false;
  bool _shiftDown = false;

  @override
  ToolType get type => ToolType.select;

  /// Extended onPointerDown that accepts shift modifier.
  @override
  ToolResult? onPointerDown(Point point, ToolContext context,
      {bool shift = false}) {
    _downPoint = point;
    _current = point;
    _isDragging = false;
    _isMarquee = false;
    _shiftDown = shift;
    _hitElement = context.scene.getElementAtPoint(point);
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    final down = _downPoint;
    if (down == null) return null;

    _current = point;
    final distance = down.distanceTo(point);
    if (distance >= _clickThreshold) {
      _isDragging = true;
      if (_hitElement == null) {
        _isMarquee = true;
      }
    }
    return null;
  }

  @override
  ToolResult? onPointerUp(Point point, ToolContext context) {
    final down = _downPoint;
    if (down == null) return null;

    _current = point;

    try {
      // Marquee selection
      if (_isMarquee) {
        return _handleMarquee(down, point, context);
      }

      // Click or drag on element
      final hit = _hitElement;
      if (hit != null) {
        if (!_isDragging) {
          return _handleClick(hit, context);
        }
        return _handleDrag(hit, down, point, context);
      }

      // Click on empty
      return SetSelectionResult({});
    } finally {
      reset();
    }
  }

  ToolResult _handleClick(Element hit, ToolContext context) {
    if (_shiftDown) {
      // Toggle in/out of selection
      final ids = Set<ElementId>.from(context.selectedIds);
      if (ids.contains(hit.id)) {
        ids.remove(hit.id);
      } else {
        ids.add(hit.id);
      }
      return SetSelectionResult(ids);
    }
    return SetSelectionResult({hit.id});
  }

  ToolResult _handleDrag(
      Element hit, Point down, Point up, ToolContext context) {
    final dx = up.x - down.x;
    final dy = up.y - down.y;

    final moved = hit.copyWith(x: hit.x + dx, y: hit.y + dy);

    if (context.selectedIds.contains(hit.id)) {
      return UpdateElementResult(moved);
    }
    // Dragging an unselected element: select then move
    return CompoundResult([
      SetSelectionResult({hit.id}),
      UpdateElementResult(moved),
    ]);
  }

  ToolResult _handleMarquee(Point down, Point up, ToolContext context) {
    final minX = math.min(down.x, up.x);
    final minY = math.min(down.y, up.y);
    final maxX = math.max(down.x, up.x);
    final maxY = math.max(down.y, up.y);
    final marquee = Bounds.fromLTWH(minX, minY, maxX - minX, maxY - minY);

    final selected = <ElementId>{};
    for (final e in context.scene.activeElements) {
      final eBounds = Bounds.fromLTWH(e.x, e.y, e.width, e.height);
      if (marquee.containsPoint(eBounds.origin) &&
          marquee.containsPoint(
              Point(eBounds.right, eBounds.bottom))) {
        selected.add(e.id);
      }
    }
    return SetSelectionResult(selected);
  }

  @override
  ToolResult? onKeyEvent(String key, {bool shift = false, bool ctrl = false}) {
    if (key == 'Escape') {
      reset();
      return SetSelectionResult({});
    }
    return null;
  }

  @override
  ToolOverlay? get overlay {
    if (!_isMarquee) return null;
    final down = _downPoint;
    final current = _current;
    if (down == null || current == null) return null;
    final minX = math.min(down.x, current.x);
    final minY = math.min(down.y, current.y);
    final w = (down.x - current.x).abs();
    final h = (down.y - current.y).abs();
    return ToolOverlay(marqueeRect: Bounds.fromLTWH(minX, minY, w, h));
  }

  @override
  void reset() {
    _downPoint = null;
    _current = null;
    _hitElement = null;
    _isDragging = false;
    _isMarquee = false;
    _shiftDown = false;
  }
}
