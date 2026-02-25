import 'dart:convert';
import 'dart:math' as math;

import 'package:rough_flutter/rough_flutter.dart';

import '../../core/elements/elements.dart';
import '../../core/math/math.dart';
import '../rough/rough.dart';
import 'svg_path_converter.dart';

/// Renders a single element to SVG markup.
///
/// Mirrors [ElementRenderer] + [RoughCanvasAdapter] dispatch but outputs
/// XML strings instead of canvas draw calls.
class SvgElementRenderer {
  /// Renders [element] to an SVG markup string.
  ///
  /// If [files] is provided, image elements embed their data as data URIs.
  static String render(Element element, {Map<String, ImageFile>? files}) {
    final buf = StringBuffer();
    final hasRotation = element.angle != 0.0;
    final hasOpacity = element.opacity < 1.0;

    // Open rotation group if needed
    if (hasRotation) {
      final cx = element.x + element.width / 2;
      final cy = element.y + element.height / 2;
      final deg = element.angle * 180 / math.pi;
      buf.write('<g transform="rotate(${_n(deg)},${_n(cx)},${_n(cy)})"');
      if (hasOpacity) {
        buf.write(' opacity="${_n(element.opacity)}"');
      }
      buf.write('>');
    } else if (hasOpacity) {
      buf.write('<g opacity="${_n(element.opacity)}">');
    }

    _dispatch(buf, element, files);

    // Close rotation/opacity group
    if (hasRotation || hasOpacity) {
      buf.write('</g>');
    }

    return buf.toString();
  }

  static void _dispatch(
      StringBuffer buf, Element element, Map<String, ImageFile>? files) {
    switch (element.type) {
      case 'rectangle':
        _renderShape(buf, element, _ShapeType.rectangle);
      case 'ellipse':
        _renderShape(buf, element, _ShapeType.ellipse);
      case 'diamond':
        _renderShape(buf, element, _ShapeType.diamond);
      case 'image':
        if (element is ImageElement) _renderImage(buf, element, files);
      case 'line':
        if (element is LineElement) _renderLine(buf, element);
      case 'arrow':
        if (element is ArrowElement) _renderArrow(buf, element);
      case 'freedraw':
        if (element is FreedrawElement) _renderFreedraw(buf, element);
      case 'text':
        if (element is TextElement) _renderText(buf, element);
      case 'frame':
        if (element is FrameElement) _renderFrame(buf, element);
    }
  }

  static void _renderShape(
      StringBuffer buf, Element element, _ShapeType shapeType) {
    final style = DrawStyle.fromElement(element);
    final generator = style.toGenerator();
    final bounds = Bounds.fromLTWH(
      element.x,
      element.y,
      element.width,
      element.height,
    );

    final Drawable drawable;
    switch (shapeType) {
      case _ShapeType.rectangle:
        drawable = generator.rectangle(
          bounds.left,
          bounds.top,
          bounds.size.width,
          bounds.size.height,
        );
      case _ShapeType.ellipse:
        drawable = generator.ellipse(
          bounds.center.x,
          bounds.center.y,
          bounds.size.width,
          bounds.size.height,
        );
      case _ShapeType.diamond:
        final top = PointD(bounds.center.x, bounds.top);
        final right = PointD(bounds.right, bounds.center.y);
        final bottom = PointD(bounds.center.x, bounds.bottom);
        final left = PointD(bounds.left, bounds.center.y);
        drawable = generator.polygon([top, right, bottom, left]);
    }

    _drawableToSvg(buf, drawable, style, element);
  }

  static void _renderLine(StringBuffer buf, LineElement element) {
    final style = DrawStyle.fromElement(element);
    final generator = style.toGenerator();
    final absPoints = _absolutePoints(element.points, element.x, element.y);

    if (absPoints.length < 2) return;

    for (var i = 0; i < absPoints.length - 1; i++) {
      final drawable = generator.line(
        absPoints[i].x,
        absPoints[i].y,
        absPoints[i + 1].x,
        absPoints[i + 1].y,
      );
      _drawableToSvg(buf, drawable, style, element);
    }
  }

  static void _renderArrow(StringBuffer buf, ArrowElement element) {
    final absPoints = _absolutePoints(element.points, element.x, element.y);

    if (absPoints.length < 2) return;

    if (element.elbowed) {
      _renderElbowArrow(buf, element, absPoints);
    } else {
      _renderRoughArrow(buf, element, absPoints);
    }
  }

  static void _renderRoughArrow(
      StringBuffer buf, ArrowElement element, List<Point> absPoints) {
    final style = DrawStyle.fromElement(element);
    final generator = style.toGenerator();

    // Draw line segments
    for (var i = 0; i < absPoints.length - 1; i++) {
      final drawable = generator.line(
        absPoints[i].x,
        absPoints[i].y,
        absPoints[i + 1].x,
        absPoints[i + 1].y,
      );
      _drawableToSvg(buf, drawable, style, element);
    }

    _renderArrowheads(buf, element, absPoints);
  }

  static void _renderElbowArrow(
      StringBuffer buf, ArrowElement element, List<Point> absPoints) {
    // Build clean polyline path (M...L...L...)
    final d = StringBuffer();
    d.write('M${_n(absPoints.first.x)},${_n(absPoints.first.y)}');
    for (var i = 1; i < absPoints.length; i++) {
      d.write(' L${_n(absPoints[i].x)},${_n(absPoints[i].y)}');
    }

    buf.write('<path d="$d" ');
    buf.write('stroke="${element.strokeColor}" ');
    buf.write('stroke-width="${_n(element.strokeWidth)}" ');
    buf.write('fill="none"');
    final dashArray = _dashArrayFor(element.strokeStyle);
    if (dashArray != null) {
      buf.write(' stroke-dasharray="$dashArray"');
    }
    buf.write('/>');

    _renderArrowheads(buf, element, absPoints);
  }

  static void _renderArrowheads(
      StringBuffer buf, ArrowElement element, List<Point> absPoints) {
    // Draw start arrowhead
    if (element.startArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(absPoints, isStart: true);
      final d = SvgPathConverter.arrowheadToPathData(
        element.startArrowhead!,
        absPoints.first,
        angle,
        element.strokeWidth,
      );
      final isFilled = element.startArrowhead == Arrowhead.triangle ||
          element.startArrowhead == Arrowhead.dot;
      _writeArrowheadPath(buf, d, element, isFilled);
    }

    // Draw end arrowhead
    if (element.endArrowhead != null) {
      final angle = ArrowheadRenderer.directionAngle(absPoints, isStart: false);
      final d = SvgPathConverter.arrowheadToPathData(
        element.endArrowhead!,
        absPoints.last,
        angle,
        element.strokeWidth,
      );
      final isFilled = element.endArrowhead == Arrowhead.triangle ||
          element.endArrowhead == Arrowhead.dot;
      _writeArrowheadPath(buf, d, element, isFilled);
    }
  }

  static void _renderFreedraw(StringBuffer buf, FreedrawElement element) {
    final absPoints = _absolutePoints(element.points, element.x, element.y);
    final d = SvgPathConverter.freedrawToPathData(
      absPoints,
      element.strokeWidth,
    );
    if (d.isEmpty) return;

    buf.write('<path d="$d" ');
    buf.write('stroke="${element.strokeColor}" ');
    buf.write('stroke-width="${_n(element.strokeWidth)}" ');
    buf.write('fill="none" ');
    buf.write('stroke-linecap="round" ');
    buf.write('stroke-linejoin="round"');
    buf.write('/>');
  }

  static void _renderText(StringBuffer buf, TextElement element) {
    final textAnchor = switch (element.textAlign) {
      TextAlign.left => 'start',
      TextAlign.center => 'middle',
      TextAlign.right => 'end',
    };

    final x = switch (element.textAlign) {
      TextAlign.left => element.x,
      TextAlign.center => element.x + element.width / 2,
      TextAlign.right => element.x + element.width,
    };

    buf.write('<text ');
    buf.write('x="${_n(x)}" ');
    buf.write('y="${_n(element.y + element.fontSize)}" ');
    buf.write('font-size="${_n(element.fontSize)}" ');
    buf.write('font-family="${element.fontFamily}" ');
    buf.write('fill="${element.strokeColor}" ');
    buf.write('text-anchor="$textAnchor"');
    buf.write('>');
    buf.write(_escapeXml(element.text));
    buf.write('</text>');
  }

  static void _renderFrame(StringBuffer buf, FrameElement element) {
    // Clean rectangle border (not rough)
    buf.write('<rect ');
    buf.write('x="${_n(element.x)}" ');
    buf.write('y="${_n(element.y)}" ');
    buf.write('width="${_n(element.width)}" ');
    buf.write('height="${_n(element.height)}" ');
    buf.write('stroke="${element.strokeColor}" ');
    buf.write('stroke-width="${_n(element.strokeWidth)}" ');
    buf.write('fill="none"');
    buf.write('/>');

    // Label above top-left corner
    if (element.label.isNotEmpty) {
      buf.write('<text ');
      buf.write('x="${_n(element.x)}" ');
      buf.write('y="${_n(element.y - 4)}" ');
      buf.write('font-size="14" ');
      buf.write('font-family="Helvetica" ');
      buf.write('fill="${element.strokeColor}" ');
      buf.write('text-anchor="start"');
      buf.write('>');
      buf.write(_escapeXml(element.label));
      buf.write('</text>');
    }
  }

  static void _renderImage(
    StringBuffer buf,
    ImageElement element,
    Map<String, ImageFile>? files,
  ) {
    final file = files?[element.fileId];
    if (file == null) {
      // Placeholder rect for missing image
      buf.write('<rect ');
      buf.write('x="${_n(element.x)}" ');
      buf.write('y="${_n(element.y)}" ');
      buf.write('width="${_n(element.width)}" ');
      buf.write('height="${_n(element.height)}" ');
      buf.write('fill="#E0E0E0" stroke="#999999" stroke-width="1"');
      buf.write('/>');
      return;
    }

    final dataUrl =
        'data:${file.mimeType};base64,${base64Encode(file.bytes)}';
    buf.write('<image ');
    buf.write('x="${_n(element.x)}" ');
    buf.write('y="${_n(element.y)}" ');
    buf.write('width="${_n(element.width)}" ');
    buf.write('height="${_n(element.height)}" ');
    buf.write('href="$dataUrl"');
    buf.write(' preserveAspectRatio="none"');
    buf.write('/>');
  }

  static void _drawableToSvg(
    StringBuffer buf,
    Drawable drawable,
    DrawStyle style,
    Element element,
  ) {
    final isTransparent = element.backgroundColor == 'transparent';

    for (final opSet in drawable.sets) {
      final d = SvgPathConverter.opSetToPathData(opSet);
      if (d.isEmpty) continue;

      switch (opSet.type) {
        case OpSetType.fillPath:
          if (!isTransparent) {
            buf.write('<path d="$d" ');
            buf.write('fill="${element.backgroundColor}" ');
            buf.write('stroke="none"');
            buf.write('/>');
          }
        case OpSetType.fillSketch:
          if (!isTransparent) {
            buf.write('<path d="$d" ');
            buf.write('stroke="${element.backgroundColor}" ');
            buf.write('stroke-width="1" ');
            buf.write('fill="none"');
            buf.write('/>');
          }
        case OpSetType.path:
          buf.write('<path d="$d" ');
          buf.write('stroke="${element.strokeColor}" ');
          buf.write('stroke-width="${_n(element.strokeWidth)}" ');
          buf.write('fill="none"');
          final dashArray = _dashArrayFor(element.strokeStyle);
          if (dashArray != null) {
            buf.write(' stroke-dasharray="$dashArray"');
          }
          buf.write('/>');
      }
    }
  }

  static void _writeArrowheadPath(
    StringBuffer buf,
    String d,
    Element element,
    bool isFilled,
  ) {
    if (isFilled) {
      buf.write('<path d="$d" ');
      buf.write('fill="${element.strokeColor}" ');
      buf.write('stroke="none"');
      buf.write('/>');
    } else {
      buf.write('<path d="$d" ');
      buf.write('stroke="${element.strokeColor}" ');
      buf.write('stroke-width="${_n(element.strokeWidth)}" ');
      buf.write('fill="none"');
      buf.write('/>');
    }
  }

  static String? _dashArrayFor(StrokeStyle style) {
    return switch (style) {
      StrokeStyle.solid => null,
      StrokeStyle.dashed => '8,6',
      StrokeStyle.dotted => '1.5,6',
    };
  }

  static List<Point> _absolutePoints(
    List<Point> points,
    double x,
    double y,
  ) {
    return points.map((p) => Point(p.x + x, p.y + y)).toList();
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _n(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(2);
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

enum _ShapeType { rectangle, ellipse, diamond }
