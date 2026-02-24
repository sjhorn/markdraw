import 'dart:ui';

import '../../core/elements/line_element.dart';
import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import 'draw_style.dart';

/// Abstracts rough-style drawing behind a clean API.
///
/// Implementations translate core element geometry into canvas draw calls,
/// typically using `rough_flutter` for the hand-drawn aesthetic.
abstract class RoughAdapter {
  /// Draws a rectangle with rough/hand-drawn styling.
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style);

  /// Draws an ellipse with rough/hand-drawn styling.
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style);

  /// Draws a diamond (4 midpoints of bounding box) with rough/hand-drawn styling.
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style);

  /// Draws a line (open polyline) through the given points.
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style);

  /// Draws an arrow (line with arrowheads) through the given points.
  void drawArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  );

  /// Draws an elbow (orthogonal) arrow with clean straight lines.
  void drawElbowArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  );

  /// Draws a freehand path through the given points.
  void drawFreedraw(
    Canvas canvas,
    List<Point> points,
    List<double> pressures,
    bool simulatePressure,
    DrawStyle style,
  );
}
