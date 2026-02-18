import 'dart:ui';

/// An immutable value object representing viewport pan and zoom state.
///
/// Used by [StaticCanvasPainter] to apply canvas transforms. A full
/// interactive ViewportController is deferred to Phase 2.4.
class ViewportState {
  final Offset offset;
  final double zoom;

  const ViewportState({this.offset = Offset.zero, this.zoom = 1.0});

  /// Returns the visible scene rectangle for the given canvas [size].
  ///
  /// The visible rect is the inverse of the viewport transform: it maps
  /// the canvas pixel area back to scene coordinates.
  Rect visibleRect(Size size) {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width / zoom,
      size.height / zoom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportState && offset == other.offset && zoom == other.zoom;

  @override
  int get hashCode => Object.hash(offset, zoom);
}
