import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/arrow_element.dart';
import '../../core/elements/element.dart';
import '../../core/elements/element_id.dart';
import '../../core/elements/freedraw_element.dart';
import '../../core/elements/line_element.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import '../../core/scene/scene.dart';
import '../../rendering/interactive/handle.dart';
import '../../rendering/interactive/selection_overlay.dart';
import '../bindings/binding_utils.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Minimum drag distance to distinguish a drag from a click.
const double _clickThreshold = 3.0;

/// Hit-test radius for handles (in scene units).
const double _handleHitRadius = 8.0;

/// Minimum element size enforced during resize.
const double _minSize = 10.0;

/// Drag mode for the select tool.
enum _DragMode {
  none,
  move,
  resize,
  rotate,
  dragPoint,
  marquee,
}

/// Tool for selecting, moving, resizing, rotating, and point-editing elements.
class SelectTool implements Tool {
  Point? _downPoint;
  Point? _current;
  Element? _hitElement;
  bool _isDragging = false;
  bool _shiftDown = false;
  _DragMode _dragMode = _DragMode.none;

  // Starting state for transforms
  Bounds? _startBounds;
  double _startAngle = 0.0;
  List<Point>? _startPoints;
  HandleType? _activeHandle;
  int? _activePointIndex;

  // For multi-element transforms
  List<Element>? _startElements;
  Bounds? _startUnionBounds;

  // Binding indicator during point drag
  Element? _bindTarget;

  @override
  ToolType get type => ToolType.select;

  /// Extended onPointerDown that accepts shift modifier.
  @override
  ToolResult? onPointerDown(Point point, ToolContext context,
      {bool shift = false}) {
    _downPoint = point;
    _current = point;
    _isDragging = false;
    _shiftDown = shift;
    _dragMode = _DragMode.none;

    final selectedElements = _getSelectedElements(context);

    // 1. Point handle hit-test (line/arrow only, single selection)
    if (selectedElements.length == 1) {
      final pointIndex = _hitTestPointHandle(point, selectedElements.first);
      if (pointIndex != null) {
        _dragMode = _DragMode.dragPoint;
        _activePointIndex = pointIndex;
        _hitElement = selectedElements.first;
        final elem = selectedElements.first;
        _startBounds = Bounds.fromLTWH(elem.x, elem.y, elem.width, elem.height);
        if (elem is LineElement) {
          _startPoints = List.of(elem.points);
        }
        return null;
      }
    }

    // 2. Resize/rotation handle hit-test
    if (selectedElements.isNotEmpty) {
      final handleType = _hitTestHandle(point, selectedElements);
      if (handleType != null) {
        if (handleType == HandleType.rotation) {
          _dragMode = _DragMode.rotate;
        } else {
          _dragMode = _DragMode.resize;
        }
        _activeHandle = handleType;
        _hitElement = selectedElements.length == 1 ? selectedElements.first : null;
        _captureStartState(selectedElements);
        return null;
      }
    }

    // 3. Element body hit-test
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

    // Check if we've started dragging
    if (!_isDragging && distance >= _clickThreshold) {
      _isDragging = true;

      // If we haven't committed to a mode yet, determine it now
      if (_dragMode == _DragMode.none) {
        if (_hitElement == null) {
          _dragMode = _DragMode.marquee;
        } else {
          _dragMode = _DragMode.move;
          _captureStartStateForMove(context);
        }
      }
    }

    if (!_isDragging) return null;

    // Dispatch based on mode
    return switch (_dragMode) {
      _DragMode.resize => _applyResize(point, context),
      _DragMode.rotate => _applyRotation(point, context),
      _DragMode.dragPoint => _applyPointDrag(point, context),
      _DragMode.move => _applyMove(point, context),
      _DragMode.marquee => null, // Marquee is overlay-only during drag
      _DragMode.none => null,
    };
  }

  @override
  ToolResult? onPointerUp(Point point, ToolContext context) {
    final down = _downPoint;
    if (down == null) return null;

    _current = point;

    try {
      // If we were in a transform mode and dragging, the final update
      // was already emitted by onPointerMove. Just reset.
      if (_isDragging && _dragMode == _DragMode.resize) {
        return _applyResize(point, context);
      }
      if (_isDragging && _dragMode == _DragMode.rotate) {
        return _applyRotation(point, context);
      }
      if (_isDragging && _dragMode == _DragMode.dragPoint) {
        return _applyPointDrag(point, context);
      }
      if (_isDragging && _dragMode == _DragMode.move) {
        return _applyMove(point, context);
      }

      // Marquee selection
      if (_dragMode == _DragMode.marquee) {
        return _handleMarquee(down, point, context);
      }

      // Click on element
      final hit = _hitElement;
      if (hit != null) {
        return _handleClick(hit, context);
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

  ToolResult? _applyMove(Point current, ToolContext context) {
    final down = _downPoint;
    if (down == null) return null;
    final hit = _hitElement;
    if (hit == null) return null;

    final dx = current.x - down.x;
    final dy = current.y - down.y;

    final selectedElements = _getSelectedElements(context);
    final isSelected = context.selectedIds.contains(hit.id);

    // Multi-element move
    if (isSelected && selectedElements.length > 1) {
      final updates = <ToolResult>[];
      final movedElements = <Element>[];
      for (final elem in _startElements ?? selectedElements) {
        final moved = elem.copyWith(x: elem.x + dx, y: elem.y + dy);
        updates.add(UpdateElementResult(moved));
        movedElements.add(moved);
      }
      updates.addAll(_buildBoundArrowUpdates(
          context.scene, movedElements, context.selectedIds));
      return CompoundResult(updates);
    }

    // Single element move
    final startElem = _startElements?.firstWhere((e) => e.id == hit.id,
        orElse: () => hit) ?? hit;
    final moved = startElem.copyWith(x: startElem.x + dx, y: startElem.y + dy);

    if (isSelected) {
      final arrowUpdates = _buildBoundArrowUpdates(
          context.scene, [moved], context.selectedIds);
      if (arrowUpdates.isEmpty) {
        return UpdateElementResult(moved);
      }
      return CompoundResult([UpdateElementResult(moved), ...arrowUpdates]);
    }
    // Dragging an unselected element: select then move
    final arrowUpdates = _buildBoundArrowUpdates(
        context.scene, [moved], {hit.id});
    return CompoundResult([
      SetSelectionResult({hit.id}),
      UpdateElementResult(moved),
      ...arrowUpdates,
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

  // --- Handle hit-testing ---

  /// Hit-test for point handles on a line/arrow element.
  int? _hitTestPointHandle(Point scenePoint, Element element) {
    if (element is! LineElement) return null;
    for (var i = 0; i < element.points.length; i++) {
      final absPoint = Point(
        element.x + element.points[i].x,
        element.y + element.points[i].y,
      );
      if (absPoint.distanceTo(scenePoint) <= _handleHitRadius) {
        return i;
      }
    }
    return null;
  }

  /// Hit-test for resize/rotation handles on selected elements.
  HandleType? _hitTestHandle(Point scenePoint, List<Element> elements) {
    final overlay = SelectionOverlay.fromElements(elements);
    if (overlay == null) return null;

    // Transform scene point into the selection's local space (undo rotation)
    final localPoint = _unrotatePoint(
      scenePoint,
      overlay.bounds.center,
      overlay.angle,
    );

    for (final handle in overlay.handles) {
      if (handle.position.distanceTo(localPoint) <= _handleHitRadius) {
        return handle.type;
      }
    }
    return null;
  }

  /// Rotates [point] around [center] by -[angle] (inverse rotation).
  static Point _unrotatePoint(Point point, Point center, double angle) {
    if (angle == 0) return point;
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    return Point(
      center.x + dx * cos - dy * sin,
      center.y + dx * sin + dy * cos,
    );
  }

  /// Rotates [point] around [center] by [angle].
  static Point _rotatePoint(Point point, Point center, double angle) {
    if (angle == 0) return point;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    return Point(
      center.x + dx * cos - dy * sin,
      center.y + dx * sin + dy * cos,
    );
  }

  // --- Resize ---

  ToolResult? _applyResize(Point current, ToolContext context) {
    final down = _downPoint;
    if (down == null || _startBounds == null || _activeHandle == null) {
      return null;
    }

    // Unrotate the drag delta into the element's local coordinate system
    // so that resize directions align with the element's axes.
    final angle = _startAngle;
    final center = _startBounds!.center;
    final localCurrent = _unrotatePoint(current, center, angle);
    final localDown = _unrotatePoint(down, center, angle);
    final dx = localCurrent.x - localDown.x;
    final dy = localCurrent.y - localDown.y;
    final b = _startBounds!;

    var newLeft = b.left;
    var newTop = b.top;
    var newRight = b.right;
    var newBottom = b.bottom;

    switch (_activeHandle!) {
      case HandleType.topLeft:
        newLeft += dx;
        newTop += dy;
      case HandleType.topCenter:
        newTop += dy;
      case HandleType.topRight:
        newRight += dx;
        newTop += dy;
      case HandleType.middleLeft:
        newLeft += dx;
      case HandleType.middleRight:
        newRight += dx;
      case HandleType.bottomLeft:
        newLeft += dx;
        newBottom += dy;
      case HandleType.bottomCenter:
        newBottom += dy;
      case HandleType.bottomRight:
        newRight += dx;
        newBottom += dy;
      case HandleType.rotation:
        return null;
    }

    // Enforce minimum size
    if (newRight - newLeft < _minSize) {
      if (_activeHandle == HandleType.topLeft ||
          _activeHandle == HandleType.middleLeft ||
          _activeHandle == HandleType.bottomLeft) {
        newLeft = newRight - _minSize;
      } else {
        newRight = newLeft + _minSize;
      }
    }
    if (newBottom - newTop < _minSize) {
      if (_activeHandle == HandleType.topLeft ||
          _activeHandle == HandleType.topCenter ||
          _activeHandle == HandleType.topRight) {
        newTop = newBottom - _minSize;
      } else {
        newBottom = newTop + _minSize;
      }
    }

    // Shift for aspect ratio lock
    if (_shiftDown) {
      final origW = b.right - b.left;
      final origH = b.bottom - b.top;
      if (origW > 0 && origH > 0) {
        final aspect = origW / origH;
        final newW = newRight - newLeft;
        final newH = newBottom - newTop;
        final currentAspect = newW / newH;
        if (currentAspect > aspect) {
          // Width is too big, adjust width
          final adjustedW = newH * aspect;
          if (_activeHandle == HandleType.topLeft ||
              _activeHandle == HandleType.middleLeft ||
              _activeHandle == HandleType.bottomLeft) {
            newLeft = newRight - adjustedW;
          } else {
            newRight = newLeft + adjustedW;
          }
        } else {
          // Height is too big, adjust height
          final adjustedH = newW / aspect;
          if (_activeHandle == HandleType.topLeft ||
              _activeHandle == HandleType.topCenter ||
              _activeHandle == HandleType.topRight) {
            newTop = newBottom - adjustedH;
          } else {
            newBottom = newTop + adjustedH;
          }
        }
      }
    }

    final newW = newRight - newLeft;
    final newH = newBottom - newTop;

    // For rotated elements, adjust x/y to keep the anchor point (opposite
    // the dragged handle) fixed in world space. Changing width/height shifts
    // the center of rotation, so we must compensate.
    if (angle != 0.0) {
      final oldW = b.right - b.left;
      final oldH = b.bottom - b.top;
      final (fx, fy) = _anchorFraction(_activeHandle!);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Anchor offset from center in old bounds
      final oldAX = fx * oldW / 2;
      final oldAY = fy * oldH / 2;
      // Anchor world position = old center + rotated old offset
      final oldCx = b.left + oldW / 2;
      final oldCy = b.top + oldH / 2;
      final anchorWx = oldCx + oldAX * cosA - oldAY * sinA;
      final anchorWy = oldCy + oldAX * sinA + oldAY * cosA;

      // Anchor offset from center in new bounds
      final newAX = fx * newW / 2;
      final newAY = fy * newH / 2;
      // new center = anchor world - rotated new offset
      final newCx = anchorWx - (newAX * cosA - newAY * sinA);
      final newCy = anchorWy - (newAX * sinA + newAY * cosA);

      newLeft = newCx - newW / 2;
      newTop = newCy - newH / 2;
    }

    final newBounds = Bounds.fromLTWH(newLeft, newTop, newW, newH);

    // Multi-element resize: scale proportionally
    if (_startElements != null && _startElements!.length > 1) {
      return _applyMultiResize(newBounds, context);
    }

    // Single element resize
    final elem = _hitElement ?? _startElements?.first;
    if (elem == null) return null;

    final startElem = _startElements?.firstWhere((e) => e.id == elem.id,
        orElse: () => elem) ?? elem;

    Element resized;
    // For point-based elements, scale points proportionally to new bounds
    if (startElem is LineElement || startElem is FreedrawElement) {
      final oldW = _startBounds!.right - _startBounds!.left;
      final oldH = _startBounds!.bottom - _startBounds!.top;
      final scaleX = oldW > 0 ? newW / oldW : 1.0;
      final scaleY = oldH > 0 ? newH / oldH : 1.0;

      if (startElem is LineElement) {
        final scaledPoints = startElem.points
            .map((p) => Point(p.x * scaleX, p.y * scaleY))
            .toList();
        resized = startElem.copyWithLine(points: scaledPoints).copyWith(
            x: newLeft, y: newTop, width: newW, height: newH,
          );
      } else {
        final fd = startElem as FreedrawElement;
        final scaledPoints = fd.points
            .map((p) => Point(p.x * scaleX, p.y * scaleY))
            .toList();
        resized = fd.copyWithFreedraw(points: scaledPoints).copyWith(
            x: newLeft, y: newTop, width: newW, height: newH,
          );
      }
    } else {
      resized = startElem.copyWith(
        x: newLeft,
        y: newTop,
        width: newW,
        height: newH,
      );
    }

    final arrowUpdates = _buildBoundArrowUpdates(
        context.scene, [resized], context.selectedIds);
    if (arrowUpdates.isEmpty) {
      return UpdateElementResult(resized);
    }
    return CompoundResult([UpdateElementResult(resized), ...arrowUpdates]);
  }

  /// Returns the anchor point's offset from center as fractions of half-size.
  /// The anchor is the fixed point opposite the handle being dragged.
  static (double, double) _anchorFraction(HandleType handle) {
    return switch (handle) {
      HandleType.topLeft => (1.0, 1.0),
      HandleType.topCenter => (0.0, 1.0),
      HandleType.topRight => (-1.0, 1.0),
      HandleType.middleLeft => (1.0, 0.0),
      HandleType.middleRight => (-1.0, 0.0),
      HandleType.bottomLeft => (1.0, -1.0),
      HandleType.bottomCenter => (0.0, -1.0),
      HandleType.bottomRight => (-1.0, -1.0),
      HandleType.rotation => (0.0, 0.0),
    };
  }

  ToolResult _applyMultiResize(Bounds newBounds, ToolContext context) {
    final oldBounds = _startUnionBounds ?? _startBounds!;
    final scaleX = oldBounds.size.width > 0
        ? newBounds.size.width / oldBounds.size.width
        : 1.0;
    final scaleY = oldBounds.size.height > 0
        ? newBounds.size.height / oldBounds.size.height
        : 1.0;

    final updates = <ToolResult>[];
    final movedElements = <Element>[];
    for (final elem in _startElements!) {
      final newX = newBounds.left + (elem.x - oldBounds.left) * scaleX;
      final newY = newBounds.top + (elem.y - oldBounds.top) * scaleY;
      final newW = elem.width * scaleX;
      final newH = elem.height * scaleY;
      Element resized;
      if (elem is LineElement) {
        final elemScaleX = elem.width > 0 ? newW / elem.width : 1.0;
        final elemScaleY = elem.height > 0 ? newH / elem.height : 1.0;
        final scaledPoints = elem.points
            .map((p) => Point(p.x * elemScaleX, p.y * elemScaleY))
            .toList();
        resized = elem.copyWithLine(points: scaledPoints).copyWith(
            x: newX, y: newY, width: newW, height: newH,
          );
      } else if (elem is FreedrawElement) {
        final elemScaleX = elem.width > 0 ? newW / elem.width : 1.0;
        final elemScaleY = elem.height > 0 ? newH / elem.height : 1.0;
        final scaledPoints = elem.points
            .map((p) => Point(p.x * elemScaleX, p.y * elemScaleY))
            .toList();
        resized = elem.copyWithFreedraw(points: scaledPoints).copyWith(
            x: newX, y: newY, width: newW, height: newH,
          );
      } else {
        resized = elem.copyWith(
          x: newX,
          y: newY,
          width: newW,
          height: newH,
        );
      }
      updates.add(UpdateElementResult(resized));
      movedElements.add(resized);
    }
    updates.addAll(_buildBoundArrowUpdates(
        context.scene, movedElements, context.selectedIds));
    return CompoundResult(updates);
  }

  // --- Rotation ---

  ToolResult? _applyRotation(Point current, ToolContext context) {
    final down = _downPoint;
    if (down == null || _startBounds == null) return null;

    final center = _startBounds!.center;
    final startAngle = math.atan2(down.y - center.y, down.x - center.x);
    final currentAngle = math.atan2(
      current.y - center.y, current.x - center.x,
    );
    var delta = currentAngle - startAngle;

    // Shift snaps to 15° increments
    if (_shiftDown) {
      const snap = math.pi / 12; // 15°
      delta = (delta / snap).roundToDouble() * snap;
    }

    // Multi-element rotate
    if (_startElements != null && _startElements!.length > 1) {
      return _applyMultiRotation(delta, context);
    }

    // Single element rotate
    final elem = _hitElement ?? _startElements?.first;
    if (elem == null) return null;

    final startElem = _startElements?.firstWhere((e) => e.id == elem.id,
        orElse: () => elem) ?? elem;

    final rotated = startElem.copyWith(angle: _startAngle + delta);
    final arrowUpdates = _buildBoundArrowUpdates(
        context.scene, [rotated], context.selectedIds);
    if (arrowUpdates.isEmpty) {
      return UpdateElementResult(rotated);
    }
    return CompoundResult([UpdateElementResult(rotated), ...arrowUpdates]);
  }

  ToolResult _applyMultiRotation(double angleDelta, ToolContext context) {
    final unionCenter = _startUnionBounds!.center;
    final updates = <ToolResult>[];
    final movedElements = <Element>[];

    for (final elem in _startElements!) {
      final elemCenter = Point(
        elem.x + elem.width / 2,
        elem.y + elem.height / 2,
      );
      final rotated = _rotatePoint(elemCenter, unionCenter, angleDelta);
      final newX = rotated.x - elem.width / 2;
      final newY = rotated.y - elem.height / 2;

      final moved = elem.copyWith(
        x: newX,
        y: newY,
        angle: elem.angle + angleDelta,
      );
      updates.add(UpdateElementResult(moved));
      movedElements.add(moved);
    }
    updates.addAll(_buildBoundArrowUpdates(
        context.scene, movedElements, context.selectedIds));
    return CompoundResult(updates);
  }

  // --- Point drag ---

  ToolResult? _applyPointDrag(Point current, ToolContext context) {
    final down = _downPoint;
    if (down == null || _hitElement is! LineElement || _activePointIndex == null) {
      return null;
    }

    final dx = current.x - down.x;
    final dy = current.y - down.y;

    final startPts = _startPoints!;
    final oldPt = startPts[_activePointIndex!];
    final newPoints = List<Point>.from(startPts);
    newPoints[_activePointIndex!] = Point(oldPt.x + dx, oldPt.y + dy);

    // Recalculate bounding box from points
    double minX = newPoints.first.x;
    double minY = newPoints.first.y;
    double maxX = newPoints.first.x;
    double maxY = newPoints.first.y;
    for (final pt in newPoints) {
      minX = math.min(minX, pt.x);
      minY = math.min(minY, pt.y);
      maxX = math.max(maxX, pt.x);
      maxY = math.max(maxY, pt.y);
    }

    final line = _hitElement! as LineElement;
    var updated = line.copyWithLine(points: newPoints).copyWith(
      width: maxX - minX,
      height: maxY - minY,
    );

    // Handle binding for arrow first/last point
    if (updated is ArrowElement) {
      final isFirst = _activePointIndex == 0;
      final isLast = _activePointIndex == newPoints.length - 1;

      if (isFirst || isLast) {
        // Compute absolute position of the dragged point
        final absPoint = Point(
          updated.x + newPoints[_activePointIndex!].x,
          updated.y + newPoints[_activePointIndex!].y,
        );
        final target = BindingUtils.findBindTarget(context.scene, absPoint);
        _bindTarget = target;

        if (target != null) {
          final fixedPoint =
              BindingUtils.computeFixedPoint(target, absPoint);
          final binding = PointBinding(
            elementId: target.id.value,
            fixedPoint: fixedPoint,
          );

          // Snap the point to the edge
          final snapped =
              BindingUtils.resolveBindingPoint(target, binding);
          newPoints[_activePointIndex!] =
              Point(snapped.x - updated.x, snapped.y - updated.y);

          // Recalculate bounding box with snapped point
          minX = newPoints.first.x;
          minY = newPoints.first.y;
          maxX = newPoints.first.x;
          maxY = newPoints.first.y;
          for (final pt in newPoints) {
            minX = math.min(minX, pt.x);
            minY = math.min(minY, pt.y);
            maxX = math.max(maxX, pt.x);
            maxY = math.max(maxY, pt.y);
          }

          updated = (updated)
              .copyWithLine(points: newPoints)
              .copyWith(
                width: maxX - minX,
                height: maxY - minY,
              );

          if (isFirst) {
            updated = (updated).copyWithArrow(
              startBinding: binding,
            );
          } else {
            updated = (updated).copyWithArrow(
              endBinding: binding,
            );
          }
        } else {
          // No target — clear binding if was bound
          if (isFirst && (line as ArrowElement).startBinding != null) {
            updated = (updated).copyWithArrow(
              clearStartBinding: true,
            );
          }
          if (isLast && (line as ArrowElement).endBinding != null) {
            updated = (updated).copyWithArrow(
              clearEndBinding: true,
            );
          }
        }
      } else {
        _bindTarget = null;
      }
    }

    return UpdateElementResult(updated);
  }

  // --- Keyboard ---

  @override
  ToolResult? onKeyEvent(String key,
      {bool shift = false, bool ctrl = false, ToolContext? context}) {
    if (key == 'Escape') {
      reset();
      return SetSelectionResult({});
    }

    if (context == null) return null;

    final selectedElements = _getSelectedElements(context);

    // Delete/Backspace
    if (key == 'Delete' || key == 'Backspace') {
      if (selectedElements.isEmpty) return null;
      final results = <ToolResult>[
        for (final e in selectedElements) RemoveElementResult(e.id),
        SetSelectionResult({}),
      ];
      // Clear bindings on arrows that were bound to deleted elements
      final deletedIds =
          selectedElements.map((e) => e.id).toSet();
      final seen = <ElementId>{};
      for (final elem in selectedElements) {
        final arrows = BindingUtils.findBoundArrows(context.scene, elem.id);
        for (final arrow in arrows) {
          if (deletedIds.contains(arrow.id)) continue;
          if (seen.contains(arrow.id)) continue;
          seen.add(arrow.id);
          var updated = arrow;
          if (arrow.startBinding != null &&
              deletedIds.contains(
                  ElementId(arrow.startBinding!.elementId))) {
            updated = updated.copyWithArrow(clearStartBinding: true);
          }
          if (arrow.endBinding != null &&
              deletedIds.contains(
                  ElementId(arrow.endBinding!.elementId))) {
            updated = updated.copyWithArrow(clearEndBinding: true);
          }
          if (!identical(updated, arrow)) {
            results.add(UpdateElementResult(updated));
          }
        }
      }
      return CompoundResult(results);
    }

    // Ctrl+D: Duplicate
    if (ctrl && (key == 'd' || key == 'D')) {
      if (selectedElements.isEmpty) return null;
      return _duplicateElements(selectedElements);
    }

    // Ctrl+A: Select all
    if (ctrl && (key == 'a' || key == 'A')) {
      final allIds = context.scene.activeElements.map((e) => e.id).toSet();
      return SetSelectionResult(allIds);
    }

    // Ctrl+C: Copy
    if (ctrl && (key == 'c' || key == 'C')) {
      if (selectedElements.isEmpty) return null;
      return SetClipboardResult(List.of(selectedElements));
    }

    // Ctrl+V: Paste
    if (ctrl && (key == 'v' || key == 'V')) {
      if (context.clipboard.isEmpty) return null;
      return _pasteElements(context.clipboard);
    }

    // Ctrl+X: Cut
    if (ctrl && (key == 'x' || key == 'X')) {
      if (selectedElements.isEmpty) return null;
      final results = <ToolResult>[
        SetClipboardResult(List.of(selectedElements)),
        for (final e in selectedElements) RemoveElementResult(e.id),
        SetSelectionResult({}),
      ];
      return CompoundResult(results);
    }

    // Arrow keys: Nudge
    final nudge = shift ? 10.0 : 1.0;
    if (key == 'ArrowLeft' || key == 'ArrowRight' ||
        key == 'ArrowUp' || key == 'ArrowDown') {
      if (selectedElements.isEmpty) return null;
      final dx = key == 'ArrowLeft' ? -nudge : key == 'ArrowRight' ? nudge : 0.0;
      final dy = key == 'ArrowUp' ? -nudge : key == 'ArrowDown' ? nudge : 0.0;
      return _nudgeElements(selectedElements, dx, dy, context);
    }

    return null;
  }

  ToolResult _duplicateElements(List<Element> elements) {
    final results = <ToolResult>[];
    final newIds = <ElementId>{};
    for (final e in elements) {
      final newId = ElementId.generate();
      newIds.add(newId);
      results.add(AddElementResult(e.copyWith(
        id: newId,
        x: e.x + 10,
        y: e.y + 10,
      )));
    }
    results.add(SetSelectionResult(newIds));
    return CompoundResult(results);
  }

  ToolResult _pasteElements(List<Element> clipboard) {
    final results = <ToolResult>[];
    final newIds = <ElementId>{};
    for (final e in clipboard) {
      final newId = ElementId.generate();
      newIds.add(newId);
      results.add(AddElementResult(e.copyWith(
        id: newId,
        x: e.x + 10,
        y: e.y + 10,
      )));
    }
    results.add(SetSelectionResult(newIds));
    return CompoundResult(results);
  }

  ToolResult _nudgeElements(
      List<Element> elements, double dx, double dy, ToolContext context) {
    final movedElements = <Element>[];
    final results = <ToolResult>[];
    for (final e in elements) {
      final moved = e.copyWith(x: e.x + dx, y: e.y + dy);
      results.add(UpdateElementResult(moved));
      movedElements.add(moved);
    }
    results.addAll(_buildBoundArrowUpdates(
        context.scene, movedElements, context.selectedIds));
    if (results.length == 1) return results.first;
    return CompoundResult(results);
  }

  @override
  ToolOverlay? get overlay {
    // Binding indicator during point drag
    if (_dragMode == _DragMode.dragPoint && _isDragging && _bindTarget != null) {
      return ToolOverlay(
        bindTargetBounds: Bounds.fromLTWH(
          _bindTarget!.x,
          _bindTarget!.y,
          _bindTarget!.width,
          _bindTarget!.height,
        ),
      );
    }
    if (_dragMode != _DragMode.marquee || !_isDragging) return null;
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
    _shiftDown = false;
    _dragMode = _DragMode.none;
    _startBounds = null;
    _startAngle = 0.0;
    _startPoints = null;
    _activeHandle = null;
    _activePointIndex = null;
    _startElements = null;
    _startUnionBounds = null;
    _bindTarget = null;
  }

  // --- Helpers ---

  List<Element> _getSelectedElements(ToolContext context) {
    return context.scene.activeElements
        .where((e) => context.selectedIds.contains(e.id))
        .toList();
  }

  void _captureStartState(List<Element> elements) {
    _startElements = List.of(elements);
    if (elements.length == 1) {
      final e = elements.first;
      _startBounds = Bounds.fromLTWH(e.x, e.y, e.width, e.height);
      _startAngle = e.angle;
      if (e is LineElement) {
        _startPoints = List.of(e.points);
      }
    } else {
      // Multi-element: union bounds
      Bounds union = Bounds.fromLTWH(
        elements.first.x, elements.first.y,
        elements.first.width, elements.first.height,
      );
      for (var i = 1; i < elements.length; i++) {
        final e = elements[i];
        union = union.union(
          Bounds.fromLTWH(e.x, e.y, e.width, e.height),
        );
      }
      _startBounds = union;
      _startUnionBounds = union;
      _startAngle = 0.0;
    }
  }

  void _captureStartStateForMove(ToolContext context) {
    final hit = _hitElement;
    if (hit == null) return;
    final isSelected = context.selectedIds.contains(hit.id);
    if (isSelected && context.selectedIds.length > 1) {
      _startElements = _getSelectedElements(context);
    } else {
      _startElements = [hit];
    }
  }

  /// Build UpdateElementResults for arrows bound to any of [movedElements],
  /// excluding arrows already in [selectedIds] (to avoid double-move).
  List<ToolResult> _buildBoundArrowUpdates(
    Scene scene,
    List<Element> movedElements,
    Set<ElementId> selectedIds,
  ) {
    // Build a temporary scene with the moved elements applied
    var tempScene = scene;
    for (final elem in movedElements) {
      tempScene = tempScene.updateElement(elem);
    }

    // Collect all bound arrows, deduplicated
    final seen = <ElementId>{};
    final results = <ToolResult>[];

    for (final elem in movedElements) {
      final arrows = BindingUtils.findBoundArrows(scene, elem.id);
      for (final arrow in arrows) {
        if (selectedIds.contains(arrow.id)) continue;
        if (seen.contains(arrow.id)) continue;
        seen.add(arrow.id);
        final updated =
            BindingUtils.updateBoundArrowEndpoints(arrow, tempScene);
        if (!identical(updated, arrow)) {
          results.add(UpdateElementResult(updated));
        }
      }
    }
    return results;
  }
}
