import 'dart:convert';

import '../elements/diamond_element.dart';
import '../elements/element.dart';
import '../elements/element_id.dart';
import '../elements/ellipse_element.dart';
import '../elements/fill_style.dart';
import '../elements/rectangle_element.dart';
import '../elements/roundness.dart';
import '../elements/stroke_style.dart';
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
        ParseWarning(line: 0, message: 'Expected JSON object at root'),
      );
      return ParseResult(
        value: MarkdrawDocument(sections: [SketchSection(const [])]),
        warnings: warnings,
      );
    }

    final elementsJson = decoded['elements'];
    if (elementsJson is! List) {
      warnings.add(
        ParseWarning(line: 0, message: 'Missing or invalid "elements" array'),
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
}
