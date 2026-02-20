import 'dart:math' as math;

import '../../core/elements/arrow_element.dart';
import '../../core/elements/element.dart';
import '../../core/elements/element_id.dart';
import '../../core/math/point.dart';
import '../../core/scene/scene.dart';

/// Snap radius for binding detection (in scene units).
const double bindingSnapRadius = 20.0;

/// Bindable element types.
const _bindableTypes = {'rectangle', 'ellipse', 'diamond'};

/// Stateless utility methods for arrow–shape binding geometry.
class BindingUtils {
  BindingUtils._();

  /// Returns true for element types that arrows can bind to.
  static bool isBindable(Element element) =>
      _bindableTypes.contains(element.type);

  /// Find the nearest bindable element within [snapRadius] of [scenePoint].
  ///
  /// Returns null if no bindable element is close enough. Optionally
  /// [excludeId] to skip a specific element (e.g., the arrow being created).
  static Element? findBindTarget(
    Scene scene,
    Point scenePoint, {
    double snapRadius = bindingSnapRadius,
    ElementId? excludeId,
  }) {
    Element? best;
    var bestDist = double.infinity;

    for (final element in scene.activeElements) {
      if (!isBindable(element)) continue;
      if (excludeId != null && element.id == excludeId) continue;

      final dist = _distanceToEdge(element, scenePoint);
      if (dist <= snapRadius && dist < bestDist) {
        bestDist = dist;
        best = element;
      }
    }
    return best;
  }

  /// Project [scenePoint] onto the nearest bounding-box edge of [target],
  /// returning a normalized (0-1, 0-1) fixedPoint.
  static Point computeFixedPoint(Element target, Point scenePoint) {
    final left = target.x;
    final top = target.y;
    final right = target.x + target.width;
    final bottom = target.y + target.height;
    final w = target.width;
    final h = target.height;

    // Clamp point to bounding box first
    final cx = scenePoint.x.clamp(left, right);
    final cy = scenePoint.y.clamp(top, bottom);

    // Distance to each edge from the (clamped or original) point
    final dLeft = (cx - left).abs();
    final dRight = (cx - right).abs();
    final dTop = (cy - top).abs();
    final dBottom = (cy - bottom).abs();

    // For points outside the bounds, also consider distance to the actual edge
    final distLeft = (scenePoint.x - left).abs();
    final distRight = (scenePoint.x - right).abs();
    final distTop = (scenePoint.y - top).abs();
    final distBottom = (scenePoint.y - bottom).abs();

    // Use distance from original point for outside; from clamped for inside
    final isInside = scenePoint.x >= left &&
        scenePoint.x <= right &&
        scenePoint.y >= top &&
        scenePoint.y <= bottom;

    double edgeDistLeft, edgeDistRight, edgeDistTop, edgeDistBottom;
    if (isInside) {
      edgeDistLeft = dLeft;
      edgeDistRight = dRight;
      edgeDistTop = dTop;
      edgeDistBottom = dBottom;
    } else {
      edgeDistLeft = distLeft + (cy - scenePoint.y).abs();
      edgeDistRight = distRight + (cy - scenePoint.y).abs();
      edgeDistTop = distTop + (cx - scenePoint.x).abs();
      edgeDistBottom = distBottom + (cx - scenePoint.x).abs();
    }

    final minDist = [edgeDistLeft, edgeDistRight, edgeDistTop, edgeDistBottom]
        .reduce(math.min);

    if (minDist == edgeDistLeft) {
      // Project onto left edge
      final yFrac = h > 0 ? (cy - top) / h : 0.5;
      return Point(0.0, yFrac);
    } else if (minDist == edgeDistRight) {
      // Project onto right edge
      final yFrac = h > 0 ? (cy - top) / h : 0.5;
      return Point(1.0, yFrac);
    } else if (minDist == edgeDistTop) {
      // Project onto top edge
      final xFrac = w > 0 ? (cx - left) / w : 0.5;
      return Point(xFrac, 0.0);
    } else {
      // Project onto bottom edge
      final xFrac = w > 0 ? (cx - left) / w : 0.5;
      return Point(xFrac, 1.0);
    }
  }

  /// Convert a fixedPoint binding back to a scene-space coordinate.
  static Point resolveBindingPoint(Element target, PointBinding binding) {
    final fx = binding.fixedPoint.x;
    final fy = binding.fixedPoint.y;
    return Point(
      target.x + fx * target.width,
      target.y + fy * target.height,
    );
  }

  /// Recompute arrow start/end points from current target positions.
  ///
  /// If a binding's target is not found in the scene, that endpoint is left
  /// unchanged.
  static ArrowElement updateBoundArrowEndpoints(
      ArrowElement arrow, Scene scene) {
    if (arrow.startBinding == null && arrow.endBinding == null) return arrow;

    final absPoints = arrow.points
        .map((p) => Point(arrow.x + p.x, arrow.y + p.y))
        .toList();

    var changed = false;

    // Update start point
    if (arrow.startBinding != null) {
      final target =
          scene.getElementById(ElementId(arrow.startBinding!.elementId));
      if (target != null) {
        absPoints[0] = resolveBindingPoint(target, arrow.startBinding!);
        changed = true;
      }
    }

    // Update end point
    if (arrow.endBinding != null) {
      final target =
          scene.getElementById(ElementId(arrow.endBinding!.elementId));
      if (target != null) {
        absPoints[absPoints.length - 1] =
            resolveBindingPoint(target, arrow.endBinding!);
        changed = true;
      }
    }

    if (!changed) return arrow;

    // Recalculate bounding box and relative points
    var minX = absPoints.first.x;
    var minY = absPoints.first.y;
    var maxX = absPoints.first.x;
    var maxY = absPoints.first.y;
    for (final p in absPoints) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }

    final relPoints = absPoints.map((p) => Point(p.x - minX, p.y - minY)).toList();

    return arrow.copyWithLine(points: relPoints).copyWith(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    ) as ArrowElement;
  }

  /// Find all arrows in [scene] that are bound to [elementId].
  static List<ArrowElement> findBoundArrows(Scene scene, ElementId elementId) {
    final result = <ArrowElement>[];
    for (final e in scene.activeElements) {
      if (e is ArrowElement) {
        if (e.startBinding?.elementId == elementId.value ||
            e.endBinding?.elementId == elementId.value) {
          result.add(e);
        }
      }
    }
    return result;
  }

  /// Minimum distance from [point] to the bounding-box edges of [element].
  static double _distanceToEdge(Element element, Point point) {
    final left = element.x;
    final top = element.y;
    final right = element.x + element.width;
    final bottom = element.y + element.height;

    // Clamp to find nearest point on boundary
    final cx = point.x.clamp(left, right);
    final cy = point.y.clamp(top, bottom);

    // If inside, distance is to nearest edge
    if (point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom) {
      return [
        (point.x - left),
        (right - point.x),
        (point.y - top),
        (bottom - point.y),
      ].reduce(math.min);
    }

    // Outside: distance to nearest point on boundary
    return point.distanceTo(Point(cx, cy));
  }
}
