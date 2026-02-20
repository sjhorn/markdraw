import 'dart:ui';

import '../core/math/point.dart';
import '../core/elements/arrow_element.dart';
import '../core/elements/element.dart' as core;
import '../core/elements/freedraw_element.dart';
import '../core/elements/line_element.dart';
import '../core/elements/text_element.dart' as core show TextElement;
import '../core/math/bounds.dart';
import 'rough/draw_style.dart';
import 'rough/rough_adapter.dart';
import 'text_renderer.dart';

/// Dispatches element rendering to the appropriate adapter method.
///
/// This utility maps element types to the correct [RoughAdapter] call,
/// handles canvas rotation for elements with a non-zero angle, and
/// delegates text to [TextRenderer] (not rough_flutter).
class ElementRenderer {
  /// Renders a single [element] onto [canvas] using [adapter].
  ///
  /// Applies rotation if [element.angle] is non-zero.
  static void render(
    Canvas canvas,
    core.Element element,
    RoughAdapter adapter,
  ) {
    final hasRotation = element.angle != 0.0;

    if (hasRotation) {
      canvas.save();
      // Rotate around the element's center
      final cx = element.x + element.width / 2;
      final cy = element.y + element.height / 2;
      canvas.translate(cx, cy);
      canvas.rotate(element.angle);
      canvas.translate(-cx, -cy);
    }

    _dispatch(canvas, element, adapter);

    if (hasRotation) {
      canvas.restore();
    }
  }

  static void _dispatch(
    Canvas canvas,
    core.Element element,
    RoughAdapter adapter,
  ) {
    final style = DrawStyle.fromElement(element);
    final bounds = Bounds.fromLTWH(
      element.x,
      element.y,
      element.width,
      element.height,
    );

    switch (element.type) {
      case 'rectangle':
        adapter.drawRectangle(canvas, bounds, style);
      case 'ellipse':
        adapter.drawEllipse(canvas, bounds, style);
      case 'diamond':
        adapter.drawDiamond(canvas, bounds, style);
      case 'line':
        if (element is LineElement) {
          final absPoints = _absolutePoints(element.points, element.x, element.y);
          adapter.drawLine(canvas, absPoints, style);
        }
      case 'arrow':
        if (element is ArrowElement) {
          final absPoints = _absolutePoints(element.points, element.x, element.y);
          adapter.drawArrow(
            canvas,
            absPoints,
            element.startArrowhead,
            element.endArrowhead,
            style,
          );
        }
      case 'freedraw':
        if (element is FreedrawElement) {
          final absPoints = _absolutePoints(element.points, element.x, element.y);
          adapter.drawFreedraw(
            canvas,
            absPoints,
            element.pressures,
            element.simulatePressure,
            style,
          );
        }
      case 'text':
        if (element is core.TextElement) {
          TextRenderer.draw(canvas, element);
        }
      default:
        break; // Unknown type — silently skip
    }
  }

  /// Converts relative points to absolute by adding the element's origin.
  static List<Point> _absolutePoints(
      List<Point> points, double x, double y) {
    return points.map((p) => Point(p.x + x, p.y + y)).toList();
  }
}
