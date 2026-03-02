import 'dart:math' as math;
import 'dart:ui';

import '../../core/elements/elements.dart';
import '../../core/math/math.dart';

/// Renders arrowhead shapes at line endpoints.
class ArrowheadRenderer {
  /// The size multiplier for arrowheads relative to stroke width.
  static const double _sizeMultiplier = 6.0;

  /// The half-angle of arrow/triangle arrowheads in radians (~25 degrees).
  static const double _halfAngle = 0.44;

  /// Computes the direction angle at a line endpoint.
  ///
  /// For [isStart] = true, returns the angle from the second point toward
  /// the first (i.e., the incoming direction at the start).
  /// For [isStart] = false, returns the angle from the second-to-last point
  /// toward the last (i.e., the outgoing direction at the end).
  ///
  /// Returns 0.0 for single-point or coincident-point cases.
  static double directionAngle(List<Point> points, {required bool isStart}) {
    if (points.length < 2) return 0.0;

    final Point from;
    final Point to;
    if (isStart) {
      from = points[1];
      to = points[0];
    } else {
      from = points[points.length - 2];
      to = points[points.length - 1];
    }

    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx == 0 && dy == 0) return 0.0;

    return math.atan2(dy, dx);
  }

  /// Builds a [Path] for the given arrowhead type at the given tip point.
  ///
  /// [angle] is the direction the arrow is pointing (in radians).
  /// [strokeWidth] scales the arrowhead size.
  static Path buildPath(
    Arrowhead type,
    Point tip,
    double angle,
    double strokeWidth,
  ) {
    final size = math.max(strokeWidth * _sizeMultiplier, 8.0);
    return switch (type) {
      Arrowhead.arrow => _buildArrowPath(tip, angle, size),
      Arrowhead.triangle => _buildTrianglePath(tip, angle, size),
      Arrowhead.triangleOutline => _buildTrianglePath(tip, angle, size),
      Arrowhead.bar => _buildBarPath(tip, angle, size),
      Arrowhead.dot => _buildDotPath(tip, size),
      Arrowhead.circle => _buildDotPath(tip, size),
      Arrowhead.circleOutline => _buildDotPath(tip, size),
      Arrowhead.diamond => _buildDiamondPath(tip, angle, size),
      Arrowhead.diamondOutline => _buildDiamondPath(tip, angle, size),
      Arrowhead.crowfootOne => _buildCrowfootOnePath(tip, angle, size),
      Arrowhead.crowfootMany => _buildCrowfootManyPath(tip, angle, size),
      Arrowhead.crowfootOneOrMany =>
        _buildCrowfootOneOrManyPath(tip, angle, size),
    };
  }

  /// Open chevron: two lines from tip at an angle.
  static Path _buildArrowPath(Point tip, double angle, double size) {
    // The arrow points in [angle] direction; the two arms go backward
    final backAngle = angle + math.pi;
    final arm1X = tip.x + size * math.cos(backAngle + _halfAngle);
    final arm1Y = tip.y + size * math.sin(backAngle + _halfAngle);
    final arm2X = tip.x + size * math.cos(backAngle - _halfAngle);
    final arm2Y = tip.y + size * math.sin(backAngle - _halfAngle);

    return Path()
      ..moveTo(arm1X, arm1Y)
      ..lineTo(tip.x, tip.y)
      ..lineTo(arm2X, arm2Y);
  }

  /// Filled triangle: three-point closed polygon.
  static Path _buildTrianglePath(Point tip, double angle, double size) {
    final backAngle = angle + math.pi;
    final arm1X = tip.x + size * math.cos(backAngle + _halfAngle);
    final arm1Y = tip.y + size * math.sin(backAngle + _halfAngle);
    final arm2X = tip.x + size * math.cos(backAngle - _halfAngle);
    final arm2Y = tip.y + size * math.sin(backAngle - _halfAngle);

    return Path()
      ..moveTo(tip.x, tip.y)
      ..lineTo(arm1X, arm1Y)
      ..lineTo(arm2X, arm2Y)
      ..close();
  }

  /// Perpendicular bar across the endpoint.
  static Path _buildBarPath(Point tip, double angle, double size) {
    final perpAngle = angle + math.pi / 2;
    final halfSize = size * 0.5;
    final x1 = tip.x + halfSize * math.cos(perpAngle);
    final y1 = tip.y + halfSize * math.sin(perpAngle);
    final x2 = tip.x - halfSize * math.cos(perpAngle);
    final y2 = tip.y - halfSize * math.sin(perpAngle);

    return Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }

  /// Filled circle at the endpoint.
  static Path _buildDotPath(Point tip, double size) {
    final radius = size * 0.35;
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(tip.x, tip.y),
        radius: radius,
      ));
  }

  /// Diamond (4-point polygon): tip, left, back, right.
  static Path _buildDiamondPath(Point tip, double angle, double size) {
    final s = size * 0.6;
    final backAngle = angle + math.pi;
    final perpAngle = angle + math.pi / 2;

    final backX = tip.x + s * math.cos(backAngle);
    final backY = tip.y + s * math.sin(backAngle);
    final midX = tip.x + s * 0.5 * math.cos(backAngle);
    final midY = tip.y + s * 0.5 * math.sin(backAngle);
    final leftX = midX + s * 0.4 * math.cos(perpAngle);
    final leftY = midY + s * 0.4 * math.sin(perpAngle);
    final rightX = midX - s * 0.4 * math.cos(perpAngle);
    final rightY = midY - s * 0.4 * math.sin(perpAngle);

    return Path()
      ..moveTo(tip.x, tip.y)
      ..lineTo(leftX, leftY)
      ..lineTo(backX, backY)
      ..lineTo(rightX, rightY)
      ..close();
  }

  /// Crow's foot "one": perpendicular bar offset slightly back from tip.
  static Path _buildCrowfootOnePath(Point tip, double angle, double size) {
    final perpAngle = angle + math.pi / 2;
    final halfSize = size * 0.5;
    final backAngle = angle + math.pi;
    final offsetX = tip.x + size * 0.3 * math.cos(backAngle);
    final offsetY = tip.y + size * 0.3 * math.sin(backAngle);
    final x1 = offsetX + halfSize * math.cos(perpAngle);
    final y1 = offsetY + halfSize * math.sin(perpAngle);
    final x2 = offsetX - halfSize * math.cos(perpAngle);
    final y2 = offsetY - halfSize * math.sin(perpAngle);

    return Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }

  /// Crow's foot "many": V-fork from a point on the shaft.
  static Path _buildCrowfootManyPath(Point tip, double angle, double size) {
    final backAngle = angle + math.pi;
    final forkX = tip.x + size * 0.5 * math.cos(backAngle);
    final forkY = tip.y + size * 0.5 * math.sin(backAngle);
    final perpAngle = angle + math.pi / 2;
    final halfSpread = size * 0.4;
    final armX1 = tip.x + halfSpread * math.cos(perpAngle);
    final armY1 = tip.y + halfSpread * math.sin(perpAngle);
    final armX2 = tip.x - halfSpread * math.cos(perpAngle);
    final armY2 = tip.y - halfSpread * math.sin(perpAngle);

    return Path()
      ..moveTo(armX1, armY1)
      ..lineTo(forkX, forkY)
      ..lineTo(armX2, armY2);
  }

  /// Crow's foot "one or many": V-fork + perpendicular bar.
  static Path _buildCrowfootOneOrManyPath(
      Point tip, double angle, double size) {
    final manyPath = _buildCrowfootManyPath(tip, angle, size);
    final onePath = _buildCrowfootOnePath(tip, angle, size);
    return manyPath..addPath(onePath, Offset.zero);
  }

  /// The set of arrowhead types that are drawn with fill style.
  static const _filledTypes = {
    Arrowhead.triangle,
    Arrowhead.dot,
    Arrowhead.circle,
    Arrowhead.diamond,
  };

  /// Draws an arrowhead on the canvas.
  static void draw(
    Canvas canvas,
    Arrowhead type,
    Point tip,
    double angle,
    double strokeWidth,
    Paint paint,
  ) {
    final path = buildPath(type, tip, angle, strokeWidth);
    if (_filledTypes.contains(type)) {
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }
}
