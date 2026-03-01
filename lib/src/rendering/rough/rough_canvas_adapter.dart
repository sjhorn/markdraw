import 'dart:math' as math;
import 'dart:ui';

import 'package:rough_flutter/rough_flutter.dart';

import '../../core/elements/elements.dart' as core show StrokeStyle;
import '../../core/elements/elements.dart' hide StrokeStyle;
import '../../core/math/math.dart';
import 'arrowhead_renderer.dart';
import 'draw_style.dart';
import 'freedraw_renderer.dart';
import 'path_dash_utility.dart';
import 'rough_adapter.dart';

/// Concrete [RoughAdapter] implementation using `rough_flutter`.
///
/// Draws elements with a hand-drawn aesthetic. Shapes (rectangle, ellipse,
/// diamond) use rough_flutter's Generator for the sketchy look. Lines and
/// arrows use rough linear paths. Freedraw uses smooth Bezier curves.
class RoughCanvasAdapter implements RoughAdapter {
  @override
  void drawRectangle(Canvas canvas, Bounds bounds, DrawStyle style) {
    final generator = style.toGenerator();
    final drawable = generator.rectangle(
      bounds.left,
      bounds.top,
      bounds.size.width,
      bounds.size.height,
    );
    // Clip fill inset by half the stroke width so the background doesn't
    // bleed past the visible stroke outline at large stroke widths.
    final inset = style.strokeWidth / 2;
    final clipRect = Rect.fromLTWH(
      bounds.left + inset,
      bounds.top + inset,
      bounds.size.width - inset * 2,
      bounds.size.height - inset * 2,
    );
    _drawClippedFillThenStroke(canvas, drawable, style, clipRect: clipRect);
  }

  @override
  void drawEllipse(Canvas canvas, Bounds bounds, DrawStyle style) {
    final generator = style.toGenerator();
    // rough_flutter ellipse takes center coordinates
    final drawable = generator.ellipse(
      bounds.center.x,
      bounds.center.y,
      bounds.size.width,
      bounds.size.height,
    );
    _drawRough(canvas, drawable, style);
  }

  @override
  void drawDiamond(Canvas canvas, Bounds bounds, DrawStyle style) {
    final generator = style.toGenerator();
    // Diamond: polygon through the 4 midpoints of the bounding box edges
    final top = PointD(bounds.center.x, bounds.top);
    final right = PointD(bounds.right, bounds.center.y);
    final bottom = PointD(bounds.center.x, bounds.bottom);
    final left = PointD(bounds.left, bounds.center.y);
    final drawable = generator.polygon([top, right, bottom, left]);
    // Clip fill inset by half the stroke width so the background doesn't
    // bleed past the visible stroke outline at large stroke widths.
    final inset = style.strokeWidth / 2;
    final cx = bounds.center.x;
    final cy = bounds.center.y;
    final clip = Path()
      ..moveTo(cx, bounds.top + inset)
      ..lineTo(bounds.right - inset, cy)
      ..lineTo(cx, bounds.bottom - inset)
      ..lineTo(bounds.left + inset, cy)
      ..close();
    _drawClippedFillThenStroke(canvas, drawable, style, clipPath: clip);
  }

  @override
  void drawPolygonLine(Canvas canvas, List<Point> points, DrawStyle style) {
    if (points.length < 3) return;

    final generator = style.toGenerator();
    final roughPoints = points.map((p) => PointD(p.x, p.y)).toList();
    final drawable = generator.polygon(roughPoints);

    // Build clip path from points for fill clipping
    final clip = Path();
    clip.moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      clip.lineTo(points[i].x, points[i].y);
    }
    clip.close();
    _drawClippedFillThenStroke(canvas, drawable, style, clipPath: clip);
  }

  @override
  void drawLine(Canvas canvas, List<Point> points, DrawStyle style) {
    if (points.length < 2) return;

    final generator = style.toGenerator();
    // Draw individual segments instead of linearPath, which always closes
    // the path (draws a return line from last point to first point).
    for (var i = 0; i < points.length - 1; i++) {
      final drawable = generator.line(
        points[i].x, points[i].y,
        points[i + 1].x, points[i + 1].y,
      );
      _drawRough(canvas, drawable, style);
    }
  }

  @override
  void drawCurvedLine(Canvas canvas, List<Point> points, DrawStyle style) {
    if (points.length < 2) return;

    final generator = style.toGenerator();
    // Pad points so curvePath (which starts at points[1] and ends at
    // points[n-2]) passes through all user points.
    final paddedPoints = [
      PointD(points.first.x, points.first.y),
      ...points.map((p) => PointD(p.x, p.y)),
      PointD(points.last.x, points.last.y),
    ];
    final drawable = generator.curvePath(paddedPoints);
    _drawRough(canvas, drawable, style);
  }

  @override
  void drawCurvedArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    if (points.length < 2) return;

    // Build smooth Bezier path that passes exactly through all points
    // (including endpoints). We don't use rough_flutter's curvePath here
    // because it applies random offsets to endpoints, causing arrowheads
    // to visually disconnect from the curve.
    final path = FreedrawRenderer.buildPath(points, style.strokeWidth);

    // Apply dash/dot pattern if needed
    final strokePaint = style.toStrokePaint();
    strokePaint.strokeCap = StrokeCap.round;
    strokePaint.strokeJoin = StrokeJoin.round;
    if (style.strokeStyle == core.StrokeStyle.solid) {
      canvas.drawPath(path, strokePaint);
    } else {
      final dashedPath = PathDashUtility.dashPath(path, style.strokeStyle);
      canvas.drawPath(dashedPath, strokePaint);
    }

    // Draw arrowheads at exact endpoint positions
    final paint = Paint()
      ..color = strokePaint.color
      ..strokeWidth = strokePaint.strokeWidth;

    if (startArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: true);
      ArrowheadRenderer.draw(
        canvas,
        startArrowhead,
        points.first,
        angle,
        style.strokeWidth,
        paint,
      );
    }

    if (endArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: false);
      ArrowheadRenderer.draw(
        canvas,
        endArrowhead,
        points.last,
        angle,
        style.strokeWidth,
        paint,
      );
    }
  }

  @override
  void drawArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    // Draw the line portion
    drawLine(canvas, points, style);

    if (points.length < 2) return;

    final paint = style.toStrokePaint();

    // Draw start arrowhead
    if (startArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: true);
      ArrowheadRenderer.draw(
        canvas,
        startArrowhead,
        points.first,
        angle,
        style.strokeWidth,
        Paint()..color = paint.color..strokeWidth = paint.strokeWidth,
      );
    }

    // Draw end arrowhead
    if (endArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: false);
      ArrowheadRenderer.draw(
        canvas,
        endArrowhead,
        points.last,
        angle,
        style.strokeWidth,
        Paint()..color = paint.color..strokeWidth = paint.strokeWidth,
      );
    }
  }

  @override
  void drawElbowArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    if (points.length < 2) return;

    // Build clean polyline path (no rough generator)
    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    // Apply dash/dot pattern if needed
    final strokePaint = style.toStrokePaint();
    if (style.strokeStyle == core.StrokeStyle.solid) {
      canvas.drawPath(path, strokePaint);
    } else {
      final dashedPath = PathDashUtility.dashPath(path, style.strokeStyle);
      canvas.drawPath(dashedPath, strokePaint);
    }

    // Draw arrowheads
    final paint = Paint()
      ..color = strokePaint.color
      ..strokeWidth = strokePaint.strokeWidth;

    if (startArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: true);
      ArrowheadRenderer.draw(
        canvas,
        startArrowhead,
        points.first,
        angle,
        style.strokeWidth,
        paint,
      );
    }

    if (endArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: false);
      ArrowheadRenderer.draw(
        canvas,
        endArrowhead,
        points.last,
        angle,
        style.strokeWidth,
        paint,
      );
    }
  }

  @override
  void drawRoundElbowArrow(
    Canvas canvas,
    List<Point> points,
    Arrowhead? startArrowhead,
    Arrowhead? endArrowhead,
    DrawStyle style,
  ) {
    if (points.length < 2) return;

    // Build polyline path with rounded corners at interior vertices
    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      // Compute segment lengths
      final segALen = _dist(prev, curr);
      final segBLen = _dist(curr, next);
      final radius = _min(10.0, _min(segALen, segBLen) / 2);

      if (radius < 0.5) {
        // Too short to round — just line to the corner
        path.lineTo(curr.x, curr.y);
        continue;
      }

      // Compute direction vectors
      final dxA = (curr.x - prev.x) / segALen;
      final dyA = (curr.y - prev.y) / segALen;
      final dxB = (next.x - curr.x) / segBLen;
      final dyB = (next.y - curr.y) / segBLen;

      // Line to the start of the arc
      final arcStartX = curr.x - dxA * radius;
      final arcStartY = curr.y - dyA * radius;
      path.lineTo(arcStartX, arcStartY);

      // Quadratic bezier to the end of the arc (corner is control point)
      final arcEndX = curr.x + dxB * radius;
      final arcEndY = curr.y + dyB * radius;
      path.quadraticBezierTo(curr.x, curr.y, arcEndX, arcEndY);
    }

    path.lineTo(points.last.x, points.last.y);

    // Apply dash/dot pattern if needed
    final strokePaint = style.toStrokePaint();
    if (style.strokeStyle == core.StrokeStyle.solid) {
      canvas.drawPath(path, strokePaint);
    } else {
      final dashedPath = PathDashUtility.dashPath(path, style.strokeStyle);
      canvas.drawPath(dashedPath, strokePaint);
    }

    // Draw arrowheads
    final paint = Paint()
      ..color = strokePaint.color
      ..strokeWidth = strokePaint.strokeWidth;

    if (startArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: true);
      ArrowheadRenderer.draw(
        canvas,
        startArrowhead,
        points.first,
        angle,
        style.strokeWidth,
        paint,
      );
    }

    if (endArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(points, isStart: false);
      ArrowheadRenderer.draw(
        canvas,
        endArrowhead,
        points.last,
        angle,
        style.strokeWidth,
        paint,
      );
    }
  }

  static double _dist(Point a, Point b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _min(double a, double b) => a < b ? a : b;

  @override
  void drawFreedraw(
    Canvas canvas,
    List<Point> points,
    List<double> pressures,
    bool simulatePressure,
    DrawStyle style,
  ) {
    FreedrawRenderer.draw(canvas, points, style);
  }

  /// Draws fill clipped to [clipRect] or [clipPath], then draws stroke
  /// unclipped so it renders at full width.
  void _drawClippedFillThenStroke(
    Canvas canvas,
    Drawable drawable,
    DrawStyle style, {
    Rect? clipRect,
    Path? clipPath,
  }) {
    final fillPaint = style.toFillPaint();

    // Draw fill inside clip region
    canvas.save();
    if (clipRect != null) {
      canvas.clipRect(clipRect);
    } else if (clipPath != null) {
      canvas.clipPath(clipPath);
    }
    _drawFillOnly(canvas, drawable, fillPaint);
    canvas.restore();

    // Draw stroke without clipping
    if (style.strokeStyle == core.StrokeStyle.solid) {
      _drawStrokeOnly(canvas, drawable, style);
    } else {
      _drawDashedStroke(canvas, drawable, style);
    }
  }

  /// Draws only the stroke (outline) portion of a rough drawable.
  void _drawStrokeOnly(Canvas canvas, Drawable drawable, DrawStyle style) {
    final strokePaint = style.toStrokePaint();
    for (final opSet in drawable.sets) {
      if (opSet.type == OpSetType.path) {
        final path = _opsToPath(opSet);
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  /// Renders a rough_flutter [Drawable] onto [canvas] with the given [style].
  ///
  /// For dashed/dotted strokes, the fill is drawn rough but the outline
  /// is extracted and dashed separately.
  void _drawRough(Canvas canvas, Drawable drawable, DrawStyle style) {
    final strokePaint = style.toStrokePaint();
    final fillPaint = style.toFillPaint();

    if (style.strokeStyle == core.StrokeStyle.solid) {
      canvas.drawRough(drawable, strokePaint, fillPaint);
    } else {
      // For dashed/dotted: draw fill normally, then dash the stroke paths
      _drawFillOnly(canvas, drawable, fillPaint);
      _drawDashedStroke(canvas, drawable, style);
    }
  }

  /// Draws only the fill portion of a rough drawable.
  void _drawFillOnly(Canvas canvas, Drawable drawable, Paint fillPaint) {
    for (final opSet in drawable.sets) {
      if (opSet.type == OpSetType.fillPath ||
          opSet.type == OpSetType.fillSketch) {
        final path = _opsToPath(opSet);
        if (opSet.type == OpSetType.fillPath) {
          canvas.drawPath(
            path,
            fillPaint..style = PaintingStyle.fill,
          );
        } else {
          canvas.drawPath(path, fillPaint);
        }
      }
    }
  }

  /// Draws the stroke portion of a rough drawable with dash/dot pattern.
  void _drawDashedStroke(
      Canvas canvas, Drawable drawable, DrawStyle style) {
    final strokePaint = style.toStrokePaint();
    for (final opSet in drawable.sets) {
      if (opSet.type == OpSetType.path) {
        final path = _opsToPath(opSet);
        final dashedPath = PathDashUtility.dashPath(path, style.strokeStyle);
        canvas.drawPath(dashedPath, strokePaint);
      }
    }
  }

  /// Converts an [OpSet] to a Flutter [Path].
  Path _opsToPath(OpSet opSet) {
    final path = Path();
    for (final op in opSet.ops) {
      switch (op.op) {
        case OpType.move:
          path.moveTo(op.data[0].x, op.data[0].y);
        case OpType.lineTo:
          path.lineTo(op.data[0].x, op.data[0].y);
        case OpType.curveTo:
          path.cubicTo(
            op.data[0].x,
            op.data[0].y,
            op.data[1].x,
            op.data[1].y,
            op.data[2].x,
            op.data[2].y,
          );
      }
    }
    return path;
  }
}
