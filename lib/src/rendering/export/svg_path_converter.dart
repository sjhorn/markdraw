import 'dart:math' as math;

import 'package:rough_flutter/rough_flutter.dart';

import '../../core/elements/line_element.dart';
import '../../core/math/point.dart';

/// Converts rough_flutter operations and geometry to SVG path `d` attribute strings.
class SvgPathConverter {
  /// Converts an [OpSet]'s operations to an SVG path `d` attribute.
  ///
  /// Maps OpType.move → M, OpType.lineTo → L, OpType.curveTo → C.
  static String opSetToPathData(OpSet opSet) {
    final buf = StringBuffer();
    for (final op in opSet.ops) {
      switch (op.op) {
        case OpType.move:
          buf.write('M${_n(op.data[0].x)} ${_n(op.data[0].y)}');
        case OpType.lineTo:
          buf.write('L${_n(op.data[0].x)} ${_n(op.data[0].y)}');
        case OpType.curveTo:
          buf.write('C${_n(op.data[0].x)} ${_n(op.data[0].y)} '
              '${_n(op.data[1].x)} ${_n(op.data[1].y)} '
              '${_n(op.data[2].x)} ${_n(op.data[2].y)}');
      }
    }
    return buf.toString();
  }

  /// Converts arrowhead geometry to an SVG path `d` attribute.
  ///
  /// Uses the same math as [ArrowheadRenderer.buildPath].
  static String arrowheadToPathData(
    Arrowhead type,
    Point tip,
    double angle,
    double strokeWidth,
  ) {
    final size = math.max(strokeWidth * 6.0, 8.0);
    return switch (type) {
      Arrowhead.arrow => _arrowPath(tip, angle, size),
      Arrowhead.triangle => _trianglePath(tip, angle, size),
      Arrowhead.bar => _barPath(tip, angle, size),
      Arrowhead.dot => _dotPath(tip, size),
    };
  }

  /// Converts freehand draw points to an SVG path `d` attribute.
  ///
  /// Uses the same Catmull-Rom → cubic Bezier logic as [FreedrawRenderer].
  static String freedrawToPathData(List<Point> points, double strokeWidth) {
    if (points.isEmpty) return '';

    if (points.length == 1) {
      // Small circle (dot) — approximate with arcs
      final p = points[0];
      final r = strokeWidth * 0.5;
      return 'M${_n(p.x - r)} ${_n(p.y)}'
          'A${_n(r)} ${_n(r)} 0 1 0 ${_n(p.x + r)} ${_n(p.y)}'
          'A${_n(r)} ${_n(r)} 0 1 0 ${_n(p.x - r)} ${_n(p.y)}';
    }

    if (points.length == 2) {
      return 'M${_n(points[0].x)} ${_n(points[0].y)}'
          'L${_n(points[1].x)} ${_n(points[1].y)}';
    }

    // 3+ points: Catmull-Rom → cubic Bezier
    final buf = StringBuffer('M${_n(points[0].x)} ${_n(points[0].y)}');
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final cp1x = p1.x + (p2.x - p0.x) / 6;
      final cp1y = p1.y + (p2.y - p0.y) / 6;
      final cp2x = p2.x - (p3.x - p1.x) / 6;
      final cp2y = p2.y - (p3.y - p1.y) / 6;

      buf.write('C${_n(cp1x)} ${_n(cp1y)} '
          '${_n(cp2x)} ${_n(cp2y)} '
          '${_n(p2.x)} ${_n(p2.y)}');
    }
    return buf.toString();
  }

  // -- Arrowhead path builders (same math as ArrowheadRenderer) --

  static const double _halfAngle = 0.44;

  static String _arrowPath(Point tip, double angle, double size) {
    final backAngle = angle + math.pi;
    final arm1X = tip.x + size * math.cos(backAngle + _halfAngle);
    final arm1Y = tip.y + size * math.sin(backAngle + _halfAngle);
    final arm2X = tip.x + size * math.cos(backAngle - _halfAngle);
    final arm2Y = tip.y + size * math.sin(backAngle - _halfAngle);

    return 'M${_n(arm1X)} ${_n(arm1Y)}'
        'L${_n(tip.x)} ${_n(tip.y)}'
        'L${_n(arm2X)} ${_n(arm2Y)}';
  }

  static String _trianglePath(Point tip, double angle, double size) {
    final backAngle = angle + math.pi;
    final arm1X = tip.x + size * math.cos(backAngle + _halfAngle);
    final arm1Y = tip.y + size * math.sin(backAngle + _halfAngle);
    final arm2X = tip.x + size * math.cos(backAngle - _halfAngle);
    final arm2Y = tip.y + size * math.sin(backAngle - _halfAngle);

    return 'M${_n(tip.x)} ${_n(tip.y)}'
        'L${_n(arm1X)} ${_n(arm1Y)}'
        'L${_n(arm2X)} ${_n(arm2Y)}Z';
  }

  static String _barPath(Point tip, double angle, double size) {
    final perpAngle = angle + math.pi / 2;
    final halfSize = size * 0.5;
    final x1 = tip.x + halfSize * math.cos(perpAngle);
    final y1 = tip.y + halfSize * math.sin(perpAngle);
    final x2 = tip.x - halfSize * math.cos(perpAngle);
    final y2 = tip.y - halfSize * math.sin(perpAngle);

    return 'M${_n(x1)} ${_n(y1)}L${_n(x2)} ${_n(y2)}';
  }

  static String _dotPath(Point tip, double size) {
    final radius = size * 0.35;
    // Circle via two half-arcs
    return 'M${_n(tip.x - radius)} ${_n(tip.y)}'
        'A${_n(radius)} ${_n(radius)} 0 1 0 ${_n(tip.x + radius)} ${_n(tip.y)}'
        'A${_n(radius)} ${_n(radius)} 0 1 0 ${_n(tip.x - radius)} ${_n(tip.y)}';
  }

  /// Formats a number with up to 2 decimal places, stripping trailing zeros.
  static String _n(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(2);
    // Strip trailing zeros after decimal
    if (s.contains('.')) {
      var end = s.length;
      while (end > 0 && s[end - 1] == '0') {
        end--;
      }
      if (end > 0 && s[end - 1] == '.') end--;
      return s.substring(0, end);
    }
    return s;
  }
}
