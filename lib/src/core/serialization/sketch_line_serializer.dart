import '../elements/arrow_element.dart';
import '../elements/diamond_element.dart';
import '../elements/element.dart';
import '../elements/ellipse_element.dart';
import '../elements/fill_style.dart';
import '../elements/freedraw_element.dart';
import '../elements/line_element.dart';
import '../elements/rectangle_element.dart';
import '../elements/stroke_style.dart';
import '../elements/text_element.dart';
import '../math/point.dart';

/// Serializes a single Element to a .markdraw sketch line string.
class SketchLineSerializer {
  /// Serialize an element to a single sketch line.
  ///
  /// [alias] is the short alias for this element's ID (if any).
  /// [aliasMap] maps element IDs to aliases (used for arrow binding references).
  String serialize(
    Element element, {
    String? alias,
    Map<String, String> aliasMap = const {},
  }) {
    return switch (element) {
      ArrowElement() => _serializeArrow(element, alias, aliasMap),
      LineElement() => _serializeLine(element, alias),
      RectangleElement() => _serializeShape('rect', element, alias),
      EllipseElement() => _serializeShape('ellipse', element, alias),
      DiamondElement() => _serializeShape('diamond', element, alias),
      TextElement() => _serializeText(element, alias),
      FreedrawElement() => _serializeFreedraw(element, alias),
      _ => _serializeShape(element.type, element, alias),
    };
  }

  String _serializeShape(String keyword, Element element, String? alias) {
    final parts = <String>[keyword];
    _addId(parts, alias);
    _addPosition(parts, element.x, element.y);
    _addSize(parts, element.width, element.height);
    _addCommonProperties(parts, element);
    return parts.join(' ');
  }

  String _serializeText(TextElement element, String? alias) {
    final parts = <String>['text'];
    parts.add('"${element.text}"');
    _addId(parts, alias);
    _addPosition(parts, element.x, element.y);
    if (element.fontSize != 20.0) {
      parts.add('size=${_formatNum(element.fontSize)}');
    }
    if (element.fontFamily != 'Virgil') {
      parts.add('font=${element.fontFamily}');
    }
    if (element.textAlign != TextAlign.left) {
      parts.add('align=${element.textAlign.name}');
    }
    _addCommonProperties(parts, element);
    return parts.join(' ');
  }

  String _serializeLine(LineElement element, String? alias) {
    final parts = <String>['line'];
    _addId(parts, alias);
    _addPoints(parts, element.points);
    _addArrowheads(parts, element.startArrowhead, element.endArrowhead, false);
    _addCommonProperties(parts, element);
    return parts.join(' ');
  }

  String _serializeArrow(
    ArrowElement element,
    String? alias,
    Map<String, String> aliasMap,
  ) {
    final parts = <String>['arrow'];
    _addId(parts, alias);

    final hasBindings =
        element.startBinding != null || element.endBinding != null;

    if (hasBindings) {
      if (element.startBinding != null) {
        final fromAlias =
            aliasMap[element.startBinding!.elementId] ??
            element.startBinding!.elementId;
        parts.add('from $fromAlias');
      }
      if (element.endBinding != null) {
        final toAlias =
            aliasMap[element.endBinding!.elementId] ??
            element.endBinding!.elementId;
        parts.add('to $toAlias');
      }
    } else {
      _addPoints(parts, element.points);
    }

    // Arrow default endArrowhead is Arrowhead.arrow, so only emit non-defaults
    _addArrowheads(parts, element.startArrowhead, element.endArrowhead, true);
    _addCommonProperties(parts, element);
    return parts.join(' ');
  }

  String _serializeFreedraw(FreedrawElement element, String? alias) {
    final parts = <String>['freedraw'];
    _addId(parts, alias);
    _addPoints(parts, element.points);
    if (element.pressures.isNotEmpty) {
      final pressureStr = element.pressures.map(_formatNum).join(',');
      parts.add('pressure=[$pressureStr]');
    }
    if (element.simulatePressure) {
      parts.add('simulate-pressure');
    }
    _addCommonProperties(parts, element);
    return parts.join(' ');
  }

  void _addId(List<String> parts, String? alias) {
    if (alias != null) {
      parts.add('id=$alias');
    }
  }

  void _addPosition(List<String> parts, double x, double y) {
    parts.add('at ${_formatNum(x)},${_formatNum(y)}');
  }

  void _addSize(List<String> parts, double width, double height) {
    parts.add('size ${_formatNum(width)}x${_formatNum(height)}');
  }

  void _addPoints(List<String> parts, List<Point> points) {
    final pointsStr = points
        .map((p) => '[${_formatNum(p.x)},${_formatNum(p.y)}]')
        .join(',');
    parts.add('points=[$pointsStr]');
  }

  void _addArrowheads(
    List<String> parts,
    Arrowhead? start,
    Arrowhead? end,
    bool isArrow,
  ) {
    if (start != null) {
      parts.add('start-arrow=${start.name}');
    }
    if (isArrow) {
      // Arrow's default endArrowhead is Arrowhead.arrow — only emit if different
      if (end != null && end != Arrowhead.arrow) {
        parts.add('end-arrow=${end.name}');
      }
    } else {
      // Line has no default arrowhead — emit if present
      if (end != null) {
        parts.add('end-arrow=${end.name}');
      }
    }
  }

  void _addCommonProperties(List<String> parts, Element element) {
    if (element.backgroundColor != 'transparent') {
      parts.add('fill=${element.backgroundColor}');
    }
    if (element.strokeColor != '#000000') {
      parts.add('color=${element.strokeColor}');
    }
    if (element.strokeStyle != StrokeStyle.solid) {
      parts.add('stroke=${element.strokeStyle.name}');
    }
    if (element.fillStyle != FillStyle.solid) {
      parts.add('fill-style=${_fillStyleName(element.fillStyle)}');
    }
    if (element.strokeWidth != 2.0) {
      parts.add('stroke-width=${_formatNum(element.strokeWidth)}');
    }
    if (element.roughness != 1.0) {
      parts.add('roughness=${_formatNum(element.roughness)}');
    }
    if (element.opacity != 1.0) {
      parts.add('opacity=${_formatNum(element.opacity)}');
    }
    if (element.roundness != null) {
      parts.add('rounded=${_formatNum(element.roundness!.value)}');
    }
    if (element.angle != 0.0) {
      parts.add('angle=${_formatNum(element.angle)}');
    }
    if (element.locked) {
      parts.add('locked');
    }
    parts.add('seed=${element.seed}');
  }

  String _fillStyleName(FillStyle style) {
    return switch (style) {
      FillStyle.solid => 'solid',
      FillStyle.hachure => 'hachure',
      FillStyle.crossHatch => 'cross-hatch',
      FillStyle.zigzag => 'zigzag',
    };
  }

  /// Formats a number: integers without decimal, doubles with decimals.
  String _formatNum(num value) {
    if (value is int) return value.toString();
    final d = value.toDouble();
    if (d == d.truncateToDouble()) {
      return d.toInt().toString();
    }
    return d.toString();
  }
}
