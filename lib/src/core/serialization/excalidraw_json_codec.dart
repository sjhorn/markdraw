import 'dart:convert';

import '../elements/arrow_element.dart';
import '../elements/diamond_element.dart';
import '../elements/element.dart';
import '../elements/element_id.dart';
import '../elements/ellipse_element.dart';
import '../elements/fill_style.dart';
import '../elements/freedraw_element.dart';
import '../elements/line_element.dart';
import '../elements/rectangle_element.dart';
import '../elements/roundness.dart';
import '../elements/stroke_style.dart';
import '../elements/text_element.dart';
import '../math/point.dart';
import 'document_section.dart';
import 'markdraw_document.dart';
import 'parse_result.dart';

/// Codec for importing/exporting Excalidraw JSON (.excalidraw) files.
///
/// Provides lenient parsing that never throws — unsupported element types
/// and property values produce [ParseWarning]s and are skipped or mapped
/// to the closest equivalent.
class ExcalidrawJsonCodec {
  // Unsupported Excalidraw element types that we skip with a warning.
  static const _unsupportedTypes = {
    'image',
    'frame',
    'magicframe',
    'iframe',
    'embeddable',
    'selection',
  };

  /// Font family number → name mapping (Excalidraw convention).
  static const fontFamilyFromNumber = <int, String>{
    1: 'Virgil',
    2: 'Helvetica',
    3: 'Cascadia',
    5: 'Excalifont',
    6: 'Nunito',
    7: 'Lilita One',
    8: 'Comic Shanns',
    9: 'Liberation Sans',
    10: 'Assistant',
  };

  /// Font family name → number mapping (reverse of [fontFamilyFromNumber]).
  static final fontFamilyToNumber = <String, int>{
    for (final entry in fontFamilyFromNumber.entries) entry.value: entry.key,
  };

  /// FillStyle string → enum mapping.
  static const _fillStyleFromString = <String, FillStyle>{
    'solid': FillStyle.solid,
    'hachure': FillStyle.hachure,
    'cross-hatch': FillStyle.crossHatch,
    'zigzag': FillStyle.zigzag,
  };

  /// StrokeStyle string → enum mapping.
  static const _strokeStyleFromString = <String, StrokeStyle>{
    'solid': StrokeStyle.solid,
    'dashed': StrokeStyle.dashed,
    'dotted': StrokeStyle.dotted,
  };

  /// FillStyle enum → string mapping (reverse).
  static const _fillStyleToString = <FillStyle, String>{
    FillStyle.solid: 'solid',
    FillStyle.hachure: 'hachure',
    FillStyle.crossHatch: 'cross-hatch',
    FillStyle.zigzag: 'zigzag',
  };

  /// StrokeStyle enum → string mapping (reverse).
  static const _strokeStyleToString = <StrokeStyle, String>{
    StrokeStyle.solid: 'solid',
    StrokeStyle.dashed: 'dashed',
    StrokeStyle.dotted: 'dotted',
  };

  /// Serializes a [MarkdrawDocument] to Excalidraw JSON format.
  static String serialize(MarkdrawDocument doc) {
    final elements = doc.allElements.map(_elementToJson).toList();
    final result = {
      'type': 'excalidraw',
      'version': 2,
      'source': 'markdraw',
      'elements': elements,
      'appState': <String, dynamic>{},
      'files': <String, dynamic>{},
    };
    return jsonEncode(result);
  }

  static Map<String, dynamic> _elementToJson(Element el) {
    final base = _baseToJson(el);
    if (el is TextElement) {
      return {
        ...base,
        'text': el.text,
        'fontSize': el.fontSize,
        'fontFamily': fontFamilyToNumber[el.fontFamily] ?? 1,
        'textAlign': el.textAlign.name,
        'containerId': el.containerId,
        'lineHeight': el.lineHeight,
        'autoResize': el.autoResize,
        'originalText': el.text,
        'verticalAlign': 'top',
      };
    } else if (el is ArrowElement) {
      return {
        ...base,
        'points': el.points.map((p) => [p.x, p.y]).toList(),
        'startArrowhead': el.startArrowhead?.name,
        'endArrowhead': el.endArrowhead?.name,
        'startBinding': _bindingToJson(el.startBinding),
        'endBinding': _bindingToJson(el.endBinding),
      };
    } else if (el is LineElement) {
      return {
        ...base,
        'points': el.points.map((p) => [p.x, p.y]).toList(),
        'startArrowhead': el.startArrowhead?.name,
        'endArrowhead': el.endArrowhead?.name,
      };
    } else if (el is FreedrawElement) {
      return {
        ...base,
        'points': el.points.map((p) => [p.x, p.y]).toList(),
        'pressures': el.pressures,
        'simulatePressure': el.simulatePressure,
      };
    }
    return base;
  }

  static Map<String, dynamic> _baseToJson(Element el) {
    return {
      'id': el.id.value,
      'type': el.type,
      'x': el.x,
      'y': el.y,
      'width': el.width,
      'height': el.height,
      'angle': el.angle,
      'strokeColor': el.strokeColor,
      'backgroundColor': el.backgroundColor,
      'fillStyle': _fillStyleToString[el.fillStyle] ?? 'solid',
      'strokeWidth': el.strokeWidth,
      'strokeStyle': _strokeStyleToString[el.strokeStyle] ?? 'solid',
      'roughness': el.roughness,
      'opacity': (el.opacity * 100).round(),
      'roundness': _roundnessToJson(el.roundness),
      'seed': el.seed,
      'version': el.version,
      'versionNonce': el.versionNonce,
      'isDeleted': el.isDeleted,
      'groupIds': el.groupIds,
      'frameId': el.frameId,
      'boundElements':
          el.boundElements.isEmpty ? null : _boundElementsToJson(el),
      'updated': el.updated,
      'link': el.link,
      'locked': el.locked,
      if (el.index != null) 'index': el.index,
    };
  }

  static Map<String, dynamic>? _roundnessToJson(Roundness? roundness) {
    if (roundness == null) return null;
    return {
      'type': roundness.type == RoundnessType.proportional ? 2 : 3,
      'value': roundness.value,
    };
  }

  static List<Map<String, dynamic>> _boundElementsToJson(Element el) {
    return el.boundElements
        .map((b) => {'id': b.id, 'type': b.type})
        .toList();
  }

  static Map<String, dynamic>? _bindingToJson(PointBinding? binding) {
    if (binding == null) return null;
    return {
      'elementId': binding.elementId,
      'fixedPoint': [binding.fixedPoint.x, binding.fixedPoint.y],
      'mode': 'inside',
    };
  }

  /// Parses an Excalidraw JSON string into a [MarkdrawDocument].
  ///
  /// Returns a [ParseResult] with warnings for unsupported elements or
  /// lossy property conversions. Never throws.
  static ParseResult<MarkdrawDocument> parse(String json) {
    final warnings = <ParseWarning>[];

    // Decode JSON
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (e) {
      warnings.add(
        ParseWarning(line: 0, message: 'Invalid JSON: $e'),
      );
      return ParseResult(
        value: MarkdrawDocument(sections: [SketchSection(const [])]),
        warnings: warnings,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      warnings.add(
        const ParseWarning(line: 0, message: 'Expected JSON object at root'),
      );
      return ParseResult(
        value: MarkdrawDocument(sections: [SketchSection(const [])]),
        warnings: warnings,
      );
    }

    final elementsJson = decoded['elements'];
    if (elementsJson is! List) {
      warnings.add(
        const ParseWarning(line: 0, message: 'Missing or invalid "elements" array'),
      );
      return ParseResult(
        value: MarkdrawDocument(sections: [SketchSection(const [])]),
        warnings: warnings,
      );
    }

    final elements = <Element>[];
    for (var i = 0; i < elementsJson.length; i++) {
      final raw = elementsJson[i];
      if (raw is! Map<String, dynamic>) {
        warnings.add(
          ParseWarning(line: i, message: 'Element $i is not a JSON object'),
        );
        continue;
      }

      final type = raw['type'] as String?;
      if (type == null) {
        warnings.add(
          ParseWarning(line: i, message: 'Element $i has no type'),
        );
        continue;
      }

      if (_unsupportedTypes.contains(type)) {
        warnings.add(
          ParseWarning(
            line: i,
            message: 'Unsupported element type "$type" skipped',
          ),
        );
        continue;
      }

      final element = _parseElement(raw, type, i, warnings);
      if (element != null) {
        elements.add(element);
      }
    }

    return ParseResult(
      value: MarkdrawDocument(sections: [SketchSection(elements)]),
      warnings: warnings,
    );
  }

  static Element? _parseElement(
    Map<String, dynamic> raw,
    String type,
    int index,
    List<ParseWarning> warnings,
  ) {
    switch (type) {
      case 'rectangle':
        return _parseRectangle(raw);
      case 'ellipse':
        return _parseEllipse(raw);
      case 'diamond':
        return _parseDiamond(raw);
      case 'text':
        return _parseText(raw, index, warnings);
      case 'line':
        return _parseLine(raw, index, warnings);
      case 'arrow':
        return _parseArrow(raw, index, warnings);
      case 'freedraw':
        return _parseFreedraw(raw);
      default:
        warnings.add(
          ParseWarning(
            line: index,
            message: 'Unsupported element type "$type" skipped',
          ),
        );
        return null;
    }
  }

  // -- Base property extraction --

  static ElementId _id(Map<String, dynamic> raw) =>
      ElementId(raw['id'] as String);

  static double _double(Map<String, dynamic> raw, String key,
          [double fallback = 0.0]) =>
      (raw[key] as num?)?.toDouble() ?? fallback;

  static int _int(Map<String, dynamic> raw, String key, [int fallback = 0]) =>
      (raw[key] as num?)?.toInt() ?? fallback;

  static double _opacity(Map<String, dynamic> raw) =>
      ((raw['opacity'] as num?)?.toDouble() ?? 100.0) / 100.0;

  static FillStyle _fillStyle(Map<String, dynamic> raw) =>
      _fillStyleFromString[raw['fillStyle'] as String? ?? 'solid'] ??
      FillStyle.solid;

  static StrokeStyle _strokeStyle(Map<String, dynamic> raw) =>
      _strokeStyleFromString[raw['strokeStyle'] as String? ?? 'solid'] ??
      StrokeStyle.solid;

  static Roundness? _roundness(Map<String, dynamic> raw) {
    final r = raw['roundness'];
    if (r == null || r is! Map<String, dynamic>) return null;
    final type = (r['type'] as num?)?.toInt();
    final value = (r['value'] as num?)?.toDouble() ?? 0.0;
    switch (type) {
      case 1:
      case 3:
        return Roundness.adaptive(value: value);
      case 2:
        return Roundness.proportional(value: value);
      default:
        return null;
    }
  }

  static List<BoundElement> _boundElements(Map<String, dynamic> raw) {
    final list = raw['boundElements'];
    if (list == null || list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => BoundElement(
            id: m['id'] as String,
            type: m['type'] as String,
          ),
        )
        .toList();
  }

  static List<String> _groupIds(Map<String, dynamic> raw) {
    final list = raw['groupIds'];
    if (list == null || list is! List) return const [];
    return list.cast<String>();
  }

  static List<Point> _points(Map<String, dynamic> raw) {
    final list = raw['points'];
    if (list == null || list is! List) return const [];
    return list
        .whereType<List<dynamic>>()
        .map((p) => Point(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ))
        .toList();
  }

  static List<double> _pressures(Map<String, dynamic> raw) {
    final list = raw['pressures'];
    if (list == null || list is! List) return const [];
    return list.map((p) => (p as num).toDouble()).toList();
  }

  static TextAlign _textAlign(Map<String, dynamic> raw) {
    switch (raw['textAlign'] as String? ?? 'left') {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  static String _fontFamily(
    Map<String, dynamic> raw,
    int index,
    List<ParseWarning> warnings,
  ) {
    final num? familyNum = raw['fontFamily'] as num?;
    if (familyNum == null) return 'Virgil';
    final name = fontFamilyFromNumber[familyNum.toInt()];
    if (name != null) return name;
    warnings.add(
      ParseWarning(
        line: index,
        message: 'Unknown font family ${familyNum.toInt()}, using Virgil',
      ),
    );
    return 'Virgil';
  }

  /// Maps an Excalidraw arrowhead string to our [Arrowhead] enum.
  ///
  /// Produces a warning for lossy mappings.
  static Arrowhead? _arrowhead(
    String? value,
    int index,
    List<ParseWarning> warnings,
  ) {
    if (value == null) return null;
    switch (value) {
      case 'arrow':
        return Arrowhead.arrow;
      case 'bar':
        return Arrowhead.bar;
      case 'dot':
        return Arrowhead.dot;
      case 'triangle':
        return Arrowhead.triangle;
      case 'circle':
      case 'circle_outline':
        warnings.add(ParseWarning(
          line: index,
          message: 'Arrowhead "$value" mapped to "dot" (closest match)',
        ));
        return Arrowhead.dot;
      case 'triangle_outline':
        warnings.add(ParseWarning(
          line: index,
          message: 'Arrowhead "$value" mapped to "triangle" (closest match)',
        ));
        return Arrowhead.triangle;
      case 'diamond':
      case 'diamond_outline':
        warnings.add(ParseWarning(
          line: index,
          message: 'Arrowhead "$value" mapped to "triangle" (closest match)',
        ));
        return Arrowhead.triangle;
      default:
        if (value.startsWith('crowfoot_')) {
          warnings.add(ParseWarning(
            line: index,
            message: 'Arrowhead "$value" mapped to "arrow" (closest match)',
          ));
          return Arrowhead.arrow;
        }
        warnings.add(ParseWarning(
          line: index,
          message: 'Unknown arrowhead "$value", using "arrow"',
        ));
        return Arrowhead.arrow;
    }
  }

  static PointBinding? _binding(Map<String, dynamic> raw, String key) {
    final b = raw[key];
    if (b == null || b is! Map<String, dynamic>) return null;
    final elementId = b['elementId'] as String?;
    if (elementId == null) return null;
    final fp = b['fixedPoint'];
    final fixedPoint = (fp is List && fp.length >= 2)
        ? Point((fp[0] as num).toDouble(), (fp[1] as num).toDouble())
        : Point.zero;
    return PointBinding(elementId: elementId, fixedPoint: fixedPoint);
  }

  // -- Shape parsers --

  static RectangleElement _parseRectangle(Map<String, dynamic> raw) {
    return RectangleElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  static EllipseElement _parseEllipse(Map<String, dynamic> raw) {
    return EllipseElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  static DiamondElement _parseDiamond(Map<String, dynamic> raw) {
    return DiamondElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  // -- Text, Line, Arrow, Freedraw parsers --

  static TextElement _parseText(
    Map<String, dynamic> raw,
    int index,
    List<ParseWarning> warnings,
  ) {
    return TextElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      text: raw['text'] as String? ?? '',
      fontSize: _double(raw, 'fontSize', 20.0),
      fontFamily: _fontFamily(raw, index, warnings),
      textAlign: _textAlign(raw),
      containerId: raw['containerId'] as String?,
      lineHeight: _double(raw, 'lineHeight', 1.25),
      autoResize: raw['autoResize'] as bool? ?? true,
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  static LineElement _parseLine(
    Map<String, dynamic> raw,
    int index,
    List<ParseWarning> warnings,
  ) {
    return LineElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      points: _points(raw),
      startArrowhead:
          _arrowhead(raw['startArrowhead'] as String?, index, warnings),
      endArrowhead:
          _arrowhead(raw['endArrowhead'] as String?, index, warnings),
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  static ArrowElement _parseArrow(
    Map<String, dynamic> raw,
    int index,
    List<ParseWarning> warnings,
  ) {
    return ArrowElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      points: _points(raw),
      startArrowhead:
          _arrowhead(raw['startArrowhead'] as String?, index, warnings),
      endArrowhead:
          _arrowhead(raw['endArrowhead'] as String?, index, warnings),
      startBinding: _binding(raw, 'startBinding'),
      endBinding: _binding(raw, 'endBinding'),
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }

  static FreedrawElement _parseFreedraw(Map<String, dynamic> raw) {
    return FreedrawElement(
      id: _id(raw),
      x: _double(raw, 'x'),
      y: _double(raw, 'y'),
      width: _double(raw, 'width'),
      height: _double(raw, 'height'),
      points: _points(raw),
      pressures: _pressures(raw),
      simulatePressure: raw['simulatePressure'] as bool? ?? false,
      angle: _double(raw, 'angle'),
      strokeColor: raw['strokeColor'] as String? ?? '#000000',
      backgroundColor: raw['backgroundColor'] as String? ?? 'transparent',
      fillStyle: _fillStyle(raw),
      strokeWidth: _double(raw, 'strokeWidth', 2.0),
      strokeStyle: _strokeStyle(raw),
      roughness: _double(raw, 'roughness', 1.0),
      opacity: _opacity(raw),
      roundness: _roundness(raw),
      seed: _int(raw, 'seed'),
      version: _int(raw, 'version', 1),
      versionNonce: _int(raw, 'versionNonce'),
      isDeleted: raw['isDeleted'] as bool? ?? false,
      groupIds: _groupIds(raw),
      frameId: raw['frameId'] as String?,
      boundElements: _boundElements(raw),
      updated: _int(raw, 'updated'),
      link: raw['link'] as String?,
      locked: raw['locked'] as bool? ?? false,
      index: raw['index'] as String?,
    );
  }
}
