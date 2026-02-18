import 'package:flutter/foundation.dart';

import '../../core/elements/element.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import 'handle.dart';

/// The gap (in scene units) between the top-center handle and the rotation
/// handle above it.
const double _rotationHandleGap = 20.0;

/// Describes the selection UI to draw: bounding box, handles, and rotation.
class SelectionOverlay {
  final Bounds bounds;
  final List<Handle> handles;
  final double angle;

  const SelectionOverlay({
    required this.bounds,
    required this.handles,
    this.angle = 0.0,
  });

  /// Creates a [SelectionOverlay] from a list of selected elements.
  ///
  /// Returns `null` if the list is empty.
  /// For a single element, the angle is preserved from the element.
  /// For multiple elements, the angle defaults to 0.
  static SelectionOverlay? fromElements(List<Element> elements) {
    if (elements.isEmpty) return null;

    Bounds union = Bounds.fromLTWH(
      elements.first.x,
      elements.first.y,
      elements.first.width,
      elements.first.height,
    );
    for (var i = 1; i < elements.length; i++) {
      final e = elements[i];
      union = union.union(Bounds.fromLTWH(e.x, e.y, e.width, e.height));
    }

    final angle = elements.length == 1 ? elements.first.angle : 0.0;

    return SelectionOverlay(
      bounds: union,
      handles: computeHandles(union),
      angle: angle,
    );
  }

  /// Computes 9 handles (8 resize + 1 rotation) for the given [bounds].
  static List<Handle> computeHandles(Bounds bounds) {
    final l = bounds.left;
    final t = bounds.top;
    final r = bounds.right;
    final b = bounds.bottom;
    final cx = (l + r) / 2;
    final cy = (t + b) / 2;

    return [
      Handle(type: HandleType.topLeft, position: Point(l, t)),
      Handle(type: HandleType.topCenter, position: Point(cx, t)),
      Handle(type: HandleType.topRight, position: Point(r, t)),
      Handle(type: HandleType.middleLeft, position: Point(l, cy)),
      Handle(type: HandleType.middleRight, position: Point(r, cy)),
      Handle(type: HandleType.bottomLeft, position: Point(l, b)),
      Handle(type: HandleType.bottomCenter, position: Point(cx, b)),
      Handle(type: HandleType.bottomRight, position: Point(r, b)),
      Handle(
        type: HandleType.rotation,
        position: Point(cx, t - _rotationHandleGap),
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionOverlay &&
          bounds == other.bounds &&
          angle == other.angle &&
          listEquals(handles, other.handles);

  @override
  int get hashCode => Object.hash(bounds, angle, Object.hashAll(handles));

  @override
  String toString() => 'SelectionOverlay($bounds, angle=$angle)';
}
