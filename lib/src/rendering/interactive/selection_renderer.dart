import 'dart:ui';

import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import 'handle.dart';
import 'snap_line.dart';

/// Static utilities for drawing selection UI overlay elements.
///
/// Similar in pattern to [TextRenderer] and [FreedrawRenderer] — a stateless
/// helper class with static draw methods.
class SelectionRenderer {
  SelectionRenderer._();

  // -- Style constants --

  static const _selectionColor = Color(0xFF4A90D9);
  static const _selectionStrokeWidth = 1.5;
  static const _handleSize = 8.0;
  static const _handleStrokeWidth = 1.5;
  static const _rotationHandleRadius = 4.0;
  static const _hoverColor = Color(0x224A90D9);
  static const _marqueeColor = Color(0xFF4A90D9);
  static const _marqueeStrokeWidth = 1.0;
  static const _marqueeFillColor = Color(0x114A90D9);
  static const _snapLineColor = Color(0xFFE03131);
  static const _snapLineStrokeWidth = 1.0;
  static const _creationPreviewColor = Color(0xFF4A90D9);
  static const _creationPreviewStrokeWidth = 1.5;

  /// Draws a dashed selection bounding box around [bounds].
  ///
  /// The caller is responsible for applying any rotation transform to the
  /// canvas before calling this method.
  static void drawSelectionBox(Canvas canvas, Bounds bounds) {
    final paint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _selectionStrokeWidth;

    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.size.width,
      bounds.size.height,
    );

    _drawDashedRect(canvas, rect, paint);
  }

  /// Draws resize handles at each handle position.
  ///
  /// Resize handles are small filled squares; the rotation handle is
  /// drawn separately via [drawRotationHandle].
  static void drawHandles(Canvas canvas, List<Handle> handles) {
    final fillPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _handleStrokeWidth;

    for (final handle in handles) {
      if (handle.type == HandleType.rotation) continue;

      final rect = Rect.fromCenter(
        center: Offset(handle.position.x, handle.position.y),
        width: _handleSize,
        height: _handleSize,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }
  }

  /// Draws the rotation handle: a line from [topCenter] to [rotationPos]
  /// and a small circle at [rotationPos].
  static void drawRotationHandle(
      Canvas canvas, Point rotationPos, Point topCenter) {
    final linePaint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(topCenter.x, topCenter.y),
      Offset(rotationPos.x, rotationPos.y),
      linePaint,
    );

    final fillPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _handleStrokeWidth;

    canvas.drawCircle(
      Offset(rotationPos.x, rotationPos.y),
      _rotationHandleRadius,
      fillPaint,
    );
    canvas.drawCircle(
      Offset(rotationPos.x, rotationPos.y),
      _rotationHandleRadius,
      strokePaint,
    );
  }

  /// Draws a semi-transparent highlight over [bounds] for hover feedback.
  static void drawHoverHighlight(Canvas canvas, Bounds bounds) {
    final paint = Paint()
      ..color = _hoverColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.size.width,
      bounds.size.height,
    );
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, strokePaint);
  }

  /// Draws a marquee (drag-to-select) rectangle.
  static void drawMarquee(Canvas canvas, Rect rect) {
    final fillPaint = Paint()
      ..color = _marqueeFillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _marqueeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _marqueeStrokeWidth;

    canvas.drawRect(rect, fillPaint);
    _drawDashedRect(canvas, rect, strokePaint);
  }

  /// Draws a single snap/alignment guide line.
  static void drawSnapLine(Canvas canvas, SnapLine snapLine) {
    final paint = Paint()
      ..color = _snapLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _snapLineStrokeWidth;

    final Offset start;
    final Offset end;

    if (snapLine.orientation == SnapLineOrientation.horizontal) {
      start = Offset(snapLine.start, snapLine.position);
      end = Offset(snapLine.end, snapLine.position);
    } else {
      start = Offset(snapLine.position, snapLine.start);
      end = Offset(snapLine.position, snapLine.end);
    }

    _drawDashedLine(canvas, start, end, paint);
  }

  /// Draws circular point handles at each position in [points].
  ///
  /// Used for line/arrow endpoint editing — each point is a draggable vertex.
  static void drawPointHandles(Canvas canvas, List<Point> points) {
    final fillPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _handleStrokeWidth;

    for (final point in points) {
      final center = Offset(point.x, point.y);
      canvas.drawCircle(center, _handleSize / 2, fillPaint);
      canvas.drawCircle(center, _handleSize / 2, strokePaint);
    }
  }

  /// Draws a creation preview line/arrow from a list of points.
  static void drawCreationPreviewLine(Canvas canvas, List<Point> points) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = _creationPreviewColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _creationPreviewStrokeWidth;

    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  /// Draws a creation preview shape (rectangle outline) from [bounds].
  static void drawCreationPreviewShape(Canvas canvas, Bounds bounds) {
    final paint = Paint()
      ..color = _creationPreviewColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _creationPreviewStrokeWidth;

    final rect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.size.width,
      bounds.size.height,
    );
    canvas.drawRect(rect, paint);
  }

  // -- Dashed drawing helpers --

  static void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  static void _drawDashedLine(
      Canvas canvas, Offset start, Offset end, Paint paint,
      {double dashLength = 6, double gapLength = 4}) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = Offset(dx, dy).distance;
    if (distance == 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    var drawn = 0.0;
    var drawing = true;
    while (drawn < distance) {
      final segLen = drawing ? dashLength : gapLength;
      final remaining = distance - drawn;
      final len = segLen < remaining ? segLen : remaining;

      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(
              start.dx + unitX * (drawn + len), start.dy + unitY * (drawn + len)),
          paint,
        );
      }
      drawn += len;
      drawing = !drawing;
    }
  }
}
