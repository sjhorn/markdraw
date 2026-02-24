import '../elements/arrow_element.dart';
import '../elements/diamond_element.dart';
import '../elements/element.dart';
import '../elements/element_id.dart';
import '../elements/ellipse_element.dart';
import '../elements/fill_style.dart';
import '../elements/frame_element.dart';
import '../elements/freedraw_element.dart';
import '../elements/line_element.dart';
import '../elements/rectangle_element.dart';
import '../elements/roundness.dart';
import '../elements/stroke_style.dart';
import '../elements/text_element.dart';
import '../math/point.dart';
import 'parse_result.dart';

/// A pending arrow binding to be resolved after all elements are parsed.
class PendingBinding {
  final String arrowElementId;
  final String? fromAlias;
  final String? toAlias;

  PendingBinding({
    required this.arrowElementId,
    this.fromAlias,
    this.toAlias,
  });
}

/// Parses single .markdraw sketch lines into Elements.
class SketchLineParser {
  /// Map of alias → element ID, built during parsing.
  final Map<String, String> aliases = {};

  /// Pending arrow bindings to resolve after all lines are parsed.
  final List<PendingBinding> pendingBindings = [];

  /// Parse a single sketch line into an Element.
  ///
  /// Returns null value for empty/comment lines. Returns warnings for
  /// unrecognized content. Never throws.
  ParseResult<Element?> parseLine(String line, int lineNumber) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return ParseResult(value: null);
    }

    final keyword = trimmed.split(RegExp(r'\s+')).first.toLowerCase();

    try {
      return switch (keyword) {
        'rect' => _parseShape(keyword, trimmed, lineNumber),
        'ellipse' => _parseShape(keyword, trimmed, lineNumber),
        'diamond' => _parseShape(keyword, trimmed, lineNumber),
        'frame' => _parseFrame(trimmed, lineNumber),
        'text' => _parseText(trimmed, lineNumber),
        'line' => _parseLine(trimmed, lineNumber),
        'arrow' => _parseArrow(trimmed, lineNumber),
        'freedraw' => _parseFreedraw(trimmed, lineNumber),
        _ => ParseResult(
            value: null,
            warnings: [
              ParseWarning(
                line: lineNumber,
                message: 'Unknown keyword: $keyword',
                context: trimmed,
              ),
            ],
          ),
      };
    } catch (e) {
      return ParseResult(
        value: null,
        warnings: [
          ParseWarning(
            line: lineNumber,
            message: 'Parse error: $e',
            context: trimmed,
          ),
        ],
      );
    }
  }

  /// Resolve pending arrow bindings after all elements have been parsed.
  ///
  /// Returns a list of updated ArrowElements with bindings set, plus
  /// any warnings for unresolved aliases.
  ParseResult<List<ArrowElement>> resolveBindings(
    List<Element> elements,
  ) {
    final warnings = <ParseWarning>[];
    final resolved = <ArrowElement>[];

    for (final binding in pendingBindings) {
      final arrowIdx = elements.indexWhere(
        (e) => e.id.value == binding.arrowElementId,
      );
      if (arrowIdx < 0) continue;

      final arrow = elements[arrowIdx] as ArrowElement;
      PointBinding? startBinding;
      PointBinding? endBinding;

      if (binding.fromAlias != null) {
        final fromId = aliases[binding.fromAlias!];
        if (fromId != null) {
          startBinding = PointBinding(
            elementId: fromId,
            fixedPoint: const Point(1, 0.5),
          );
        } else {
          warnings.add(ParseWarning(
            line: 0,
            message: 'Unresolved alias: ${binding.fromAlias}',
          ));
        }
      }

      if (binding.toAlias != null) {
        final toId = aliases[binding.toAlias!];
        if (toId != null) {
          endBinding = PointBinding(
            elementId: toId,
            fixedPoint: const Point(0, 0.5),
          );
        } else {
          warnings.add(ParseWarning(
            line: 0,
            message: 'Unresolved alias: ${binding.toAlias}',
          ));
        }
      }

      resolved.add(arrow.copyWithArrow(
        startBinding: startBinding,
        endBinding: endBinding,
      ));
    }

    return ParseResult(value: resolved, warnings: warnings);
  }

  // ── Shape parsing (rect, ellipse, diamond) ──

  ParseResult<Element?> _parseShape(
    String keyword,
    String line,
    int lineNumber,
  ) {
    final props = _PropertyBag(line, keyword);
    final id = props.id;
    final pos = props.position;
    final size = props.size;
    final common = props.commonProperties;

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final element = switch (keyword) {
      'rect' => RectangleElement(
          id: elementId,
          x: pos.$1,
          y: pos.$2,
          width: size.$1,
          height: size.$2,
          strokeColor: common.strokeColor,
          backgroundColor: common.backgroundColor,
          fillStyle: common.fillStyle,
          strokeWidth: common.strokeWidth,
          strokeStyle: common.strokeStyle,
          roughness: common.roughness,
          opacity: common.opacity,
          roundness: common.roundness,
          angle: common.angle,
          locked: common.locked,
          seed: common.seed,
          frameId: common.frameId,
          groupIds: common.groupIds,
        ),
      'ellipse' => EllipseElement(
          id: elementId,
          x: pos.$1,
          y: pos.$2,
          width: size.$1,
          height: size.$2,
          strokeColor: common.strokeColor,
          backgroundColor: common.backgroundColor,
          fillStyle: common.fillStyle,
          strokeWidth: common.strokeWidth,
          strokeStyle: common.strokeStyle,
          roughness: common.roughness,
          opacity: common.opacity,
          roundness: common.roundness,
          angle: common.angle,
          locked: common.locked,
          seed: common.seed,
          frameId: common.frameId,
          groupIds: common.groupIds,
        ),
      'diamond' => DiamondElement(
          id: elementId,
          x: pos.$1,
          y: pos.$2,
          width: size.$1,
          height: size.$2,
          strokeColor: common.strokeColor,
          backgroundColor: common.backgroundColor,
          fillStyle: common.fillStyle,
          strokeWidth: common.strokeWidth,
          strokeStyle: common.strokeStyle,
          roughness: common.roughness,
          opacity: common.opacity,
          roundness: common.roundness,
          angle: common.angle,
          locked: common.locked,
          seed: common.seed,
          frameId: common.frameId,
          groupIds: common.groupIds,
        ),
      _ => null,
    };

    return ParseResult(value: element);
  }

  // ── Frame parsing ──

  ParseResult<Element?> _parseFrame(String line, int lineNumber) {
    final props = _PropertyBag(line, 'frame');
    final id = props.id;
    final pos = props.position;
    final size = props.size;
    final common = props.commonProperties;
    final label = props.quotedString ?? 'Frame';

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final element = FrameElement(
      id: elementId,
      x: pos.$1,
      y: pos.$2,
      width: size.$1,
      height: size.$2,
      label: label,
      strokeColor: common.strokeColor,
      backgroundColor: common.backgroundColor,
      fillStyle: common.fillStyle,
      strokeWidth: common.strokeWidth,
      strokeStyle: common.strokeStyle,
      roughness: common.roughness,
      opacity: common.opacity,
      roundness: common.roundness,
      angle: common.angle,
      locked: common.locked,
      seed: common.seed,
      frameId: common.frameId,
      groupIds: common.groupIds,
    );

    return ParseResult(value: element);
  }

  // ── Text parsing ──

  ParseResult<Element?> _parseText(String line, int lineNumber) {
    final props = _PropertyBag(line, 'text');
    final id = props.id;
    final pos = props.position;
    final common = props.commonProperties;
    final text = props.quotedString;
    final fontSize = props.namedDouble('size') ?? 20.0;
    final fontFamily = props.namedString('font') ?? 'Virgil';
    final alignStr = props.namedString('align');
    final textAlign = _parseTextAlign(alignStr);

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final element = TextElement(
      id: elementId,
      x: pos.$1,
      y: pos.$2,
      width: 0,
      height: 0,
      text: text ?? '',
      fontSize: fontSize,
      fontFamily: fontFamily,
      textAlign: textAlign,
      strokeColor: common.strokeColor,
      backgroundColor: common.backgroundColor,
      fillStyle: common.fillStyle,
      strokeWidth: common.strokeWidth,
      strokeStyle: common.strokeStyle,
      roughness: common.roughness,
      opacity: common.opacity,
      angle: common.angle,
      locked: common.locked,
      seed: common.seed,
      frameId: common.frameId,
      groupIds: common.groupIds,
    );

    return ParseResult(value: element);
  }

  // ── Line parsing ──

  ParseResult<Element?> _parseLine(String line, int lineNumber) {
    final props = _PropertyBag(line, 'line');
    final id = props.id;
    final points = props.points;
    final common = props.commonProperties;
    final startArrow = _parseArrowhead(props.namedString('start-arrow'));
    final endArrow = _parseArrowhead(props.namedString('end-arrow'));

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final bounds = _boundsFromPoints(points);

    final element = LineElement(
      id: elementId,
      x: bounds.$1,
      y: bounds.$2,
      width: bounds.$3,
      height: bounds.$4,
      points: points,
      startArrowhead: startArrow,
      endArrowhead: endArrow,
      strokeColor: common.strokeColor,
      backgroundColor: common.backgroundColor,
      fillStyle: common.fillStyle,
      strokeWidth: common.strokeWidth,
      strokeStyle: common.strokeStyle,
      roughness: common.roughness,
      opacity: common.opacity,
      angle: common.angle,
      locked: common.locked,
      seed: common.seed,
      frameId: common.frameId,
      groupIds: common.groupIds,
    );

    return ParseResult(value: element);
  }

  // ── Arrow parsing ──

  ParseResult<Element?> _parseArrow(String line, int lineNumber) {
    final props = _PropertyBag(line, 'arrow');
    final id = props.id;
    final common = props.commonProperties;
    final startArrow = _parseArrowhead(props.namedString('start-arrow'));
    final endArrowStr = props.namedString('end-arrow');
    final endArrow = endArrowStr != null
        ? _parseArrowhead(endArrowStr) ?? Arrowhead.arrow
        : Arrowhead.arrow;

    final fromAlias = props.namedPositional('from');
    final toAlias = props.namedPositional('to');
    final hasBindings = fromAlias != null || toAlias != null;

    List<Point> points;
    if (hasBindings) {
      // Placeholder points — will be computed when bindings resolve
      points = [const Point(0, 0), const Point(0, 0)];
    } else {
      points = props.points;
    }

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final bounds = _boundsFromPoints(points);

    final arrow = ArrowElement(
      id: elementId,
      x: bounds.$1,
      y: bounds.$2,
      width: bounds.$3,
      height: bounds.$4,
      points: points,
      startArrowhead: startArrow,
      endArrowhead: endArrow,
      strokeColor: common.strokeColor,
      backgroundColor: common.backgroundColor,
      fillStyle: common.fillStyle,
      strokeWidth: common.strokeWidth,
      strokeStyle: common.strokeStyle,
      roughness: common.roughness,
      opacity: common.opacity,
      angle: common.angle,
      locked: common.locked,
      seed: common.seed,
      frameId: common.frameId,
      groupIds: common.groupIds,
    );

    if (hasBindings) {
      pendingBindings.add(PendingBinding(
        arrowElementId: elementId.value,
        fromAlias: fromAlias,
        toAlias: toAlias,
      ));
    }

    return ParseResult(value: arrow);
  }

  // ── Freedraw parsing ──

  ParseResult<Element?> _parseFreedraw(String line, int lineNumber) {
    final props = _PropertyBag(line, 'freedraw');
    final id = props.id;
    final points = props.points;
    final pressures = props.pressures;
    final simulatePressure = props.hasFlag('simulate-pressure');
    final common = props.commonProperties;

    final elementId = ElementId(id ?? _generateId());
    if (id != null) {
      aliases[id] = elementId.value;
    }

    final bounds = _boundsFromPoints(points);

    final element = FreedrawElement(
      id: elementId,
      x: bounds.$1,
      y: bounds.$2,
      width: bounds.$3,
      height: bounds.$4,
      points: points,
      pressures: pressures,
      simulatePressure: simulatePressure,
      strokeColor: common.strokeColor,
      backgroundColor: common.backgroundColor,
      fillStyle: common.fillStyle,
      strokeWidth: common.strokeWidth,
      strokeStyle: common.strokeStyle,
      roughness: common.roughness,
      opacity: common.opacity,
      angle: common.angle,
      locked: common.locked,
      seed: common.seed,
      frameId: common.frameId,
      groupIds: common.groupIds,
    );

    return ParseResult(value: element);
  }

  // ── Helpers ──

  TextAlign _parseTextAlign(String? value) {
    return switch (value) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  Arrowhead? _parseArrowhead(String? value) {
    return switch (value) {
      'arrow' => Arrowhead.arrow,
      'bar' => Arrowhead.bar,
      'dot' => Arrowhead.dot,
      'triangle' => Arrowhead.triangle,
      _ => null,
    };
  }

  (double, double, double, double) _boundsFromPoints(List<Point> points) {
    if (points.isEmpty) return (0, 0, 0, 0);
    var minX = points.first.x;
    var minY = points.first.y;
    var maxX = points.first.x;
    var maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return (minX, minY, maxX - minX, maxY - minY);
  }

  int _idCounter = 0;
  String _generateId() => 'gen_${_idCounter++}';
}

// ── Property bag: extracts properties from a sketch line ──

class _CommonProperties {
  final String strokeColor;
  final String backgroundColor;
  final FillStyle fillStyle;
  final double strokeWidth;
  final StrokeStyle strokeStyle;
  final double roughness;
  final double opacity;
  final Roundness? roundness;
  final double angle;
  final bool locked;
  final int seed;
  final String? frameId;
  final List<String> groupIds;

  _CommonProperties({
    required this.strokeColor,
    required this.backgroundColor,
    required this.fillStyle,
    required this.strokeWidth,
    required this.strokeStyle,
    required this.roughness,
    required this.opacity,
    required this.roundness,
    required this.angle,
    required this.locked,
    required this.seed,
    required this.frameId,
    required this.groupIds,
  });
}

class _PropertyBag {
  final String line;
  final String keyword;

  _PropertyBag(this.line, this.keyword);

  String? get id => namedString('id');

  (double, double) get position {
    final match = RegExp(r'at\s+([\d.+-]+),([\d.+-]+)').firstMatch(line);
    if (match == null) return (0, 0);
    return (double.parse(match.group(1)!), double.parse(match.group(2)!));
  }

  (double, double) get size {
    // Shape size: "size WxH"
    final match = RegExp(r'size\s+([\d.]+)x([\d.]+)').firstMatch(line);
    if (match == null) return (0, 0);
    return (double.parse(match.group(1)!), double.parse(match.group(2)!));
  }

  String? get quotedString {
    final match = RegExp(r'"([^"]*)"').firstMatch(line);
    return match?.group(1);
  }

  List<Point> get points {
    final match = RegExp(r'points=\[(.+?)\](?:\s|$)').firstMatch(line);
    if (match == null) return [];
    final inner = match.group(1)!;
    final pointMatches = RegExp(r'\[([\d.+-]+),([\d.+-]+)\]').allMatches(inner);
    return pointMatches.map((m) {
      return Point(double.parse(m.group(1)!), double.parse(m.group(2)!));
    }).toList();
  }

  List<double> get pressures {
    final match = RegExp(r'pressure=\[([\d.,]+)\]').firstMatch(line);
    if (match == null) return [];
    return match.group(1)!.split(',').map(double.parse).toList();
  }

  String? namedString(String name) {
    final match = RegExp('$name=(\\S+)').firstMatch(line);
    return match?.group(1);
  }

  double? namedDouble(String name) {
    final str = namedString(name);
    if (str == null) return null;
    return double.tryParse(str);
  }

  int? namedInt(String name) {
    final str = namedString(name);
    if (str == null) return null;
    return int.tryParse(str);
  }

  /// Parses "from alias" or "to alias" style positional named params.
  String? namedPositional(String name) {
    final match = RegExp('(?:^|\\s)$name\\s+(\\S+)').firstMatch(line);
    if (match == null) return null;
    // Avoid matching named=value patterns
    final value = match.group(1)!;
    if (value.contains('=')) return null;
    return value;
  }

  bool hasFlag(String name) {
    // Match as whole word, not as part of name=value
    return RegExp('(?:^|\\s)$name(?:\\s|\$)').hasMatch(line);
  }

  _CommonProperties get commonProperties {
    final fillStr = namedString('fill');
    final colorStr = namedString('color');
    final strokeStr = namedString('stroke');
    final fillStyleStr = namedString('fill-style');
    final strokeWidthVal = namedDouble('stroke-width');
    final roughnessVal = namedDouble('roughness');
    final opacityVal = namedDouble('opacity');
    final roundedVal = namedDouble('rounded');
    final angleVal = namedDouble('angle');
    final seedVal = namedInt('seed');
    final isLocked = hasFlag('locked');
    final frameIdStr = namedString('frame');
    final groupStr = namedString('group');
    final groupIds = groupStr != null && groupStr.isNotEmpty
        ? groupStr.split(',')
        : <String>[];

    return _CommonProperties(
      strokeColor: colorStr ?? '#000000',
      backgroundColor: fillStr ?? 'transparent',
      fillStyle: _parseFillStyle(fillStyleStr),
      strokeWidth: strokeWidthVal ?? 2.0,
      strokeStyle: _parseStrokeStyle(strokeStr),
      roughness: roughnessVal ?? 1.0,
      opacity: opacityVal ?? 1.0,
      roundness: roundedVal != null
          ? Roundness.adaptive(value: roundedVal)
          : null,
      angle: angleVal ?? 0.0,
      locked: isLocked,
      seed: seedVal ?? 1,
      frameId: frameIdStr,
      groupIds: groupIds,
    );
  }

  FillStyle _parseFillStyle(String? value) {
    return switch (value) {
      'solid' => FillStyle.solid,
      'hachure' => FillStyle.hachure,
      'cross-hatch' => FillStyle.crossHatch,
      'zigzag' => FillStyle.zigzag,
      _ => FillStyle.solid,
    };
  }

  StrokeStyle _parseStrokeStyle(String? value) {
    return switch (value) {
      'solid' => StrokeStyle.solid,
      'dashed' => StrokeStyle.dashed,
      'dotted' => StrokeStyle.dotted,
      _ => StrokeStyle.solid,
    };
  }
}
