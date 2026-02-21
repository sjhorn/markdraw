import '../core/elements/element.dart';
import '../core/elements/fill_style.dart';
import '../core/elements/roundness.dart';
import '../core/elements/stroke_style.dart';
import '../core/elements/text_element.dart';
import 'tool_result.dart';

/// Represents the current (possibly mixed) style values for the property panel.
///
/// A `null` value means the selected elements have mixed values for that
/// property. Text-specific properties are only populated when at least one
/// [TextElement] is selected.
class ElementStyle {
  final String? strokeColor;
  final String? backgroundColor;
  final double? strokeWidth;
  final StrokeStyle? strokeStyle;
  final FillStyle? fillStyle;
  final double? roughness;
  final double? opacity;
  final Roundness? roundness;

  /// True if any selected element has a non-null roundness.
  final bool hasRoundness;

  /// True if at least one selected element is a [TextElement].
  final bool hasText;

  // Text-only properties (null if no text elements or mixed):
  final double? fontSize;
  final String? fontFamily;
  final TextAlign? textAlign;

  const ElementStyle({
    this.strokeColor,
    this.backgroundColor,
    this.strokeWidth,
    this.strokeStyle,
    this.fillStyle,
    this.roughness,
    this.opacity,
    this.roundness,
    this.hasRoundness = false,
    this.hasText = false,
    this.fontSize,
    this.fontFamily,
    this.textAlign,
  });
}

/// Pure-logic class that reads selected elements and produces style state
/// and [ToolResult]s. No Flutter widgets — keeps it testable.
class PropertyPanelState {
  /// Extract the common style properties from a set of elements.
  ///
  /// Returns `null` for a property if elements have mixed values.
  /// Returns an all-null [ElementStyle] if [elements] is empty.
  static ElementStyle fromElements(List<Element> elements) {
    if (elements.isEmpty) {
      return const ElementStyle();
    }

    final first = elements.first;

    // Base properties — check if all elements share the same value.
    String? strokeColor = first.strokeColor;
    String? backgroundColor = first.backgroundColor;
    double? strokeWidth = first.strokeWidth;
    StrokeStyle? strokeStyle = first.strokeStyle;
    FillStyle? fillStyle = first.fillStyle;
    double? roughness = first.roughness;
    double? opacity = first.opacity;

    bool hasRoundness = first.roundness != null;
    Roundness? roundness = first.roundness;
    bool roundnessMixed = false;

    for (var i = 1; i < elements.length; i++) {
      final e = elements[i];
      if (strokeColor != null && e.strokeColor != strokeColor) {
        strokeColor = null;
      }
      if (backgroundColor != null && e.backgroundColor != backgroundColor) {
        backgroundColor = null;
      }
      if (strokeWidth != null && e.strokeWidth != strokeWidth) {
        strokeWidth = null;
      }
      if (strokeStyle != null && e.strokeStyle != strokeStyle) {
        strokeStyle = null;
      }
      if (fillStyle != null && e.fillStyle != fillStyle) {
        fillStyle = null;
      }
      if (roughness != null && e.roughness != roughness) {
        roughness = null;
      }
      if (opacity != null && e.opacity != opacity) {
        opacity = null;
      }
      if (e.roundness != null) hasRoundness = true;
      if (!roundnessMixed && e.roundness != roundness) {
        roundness = null;
        roundnessMixed = true;
      }
    }

    // Text properties — only if at least one TextElement is present.
    final textElements =
        elements.whereType<TextElement>().toList();
    final hasText = textElements.isNotEmpty;

    double? fontSize;
    String? fontFamily;
    TextAlign? textAlign;

    if (hasText) {
      final firstText = textElements.first;
      fontSize = firstText.fontSize;
      fontFamily = firstText.fontFamily;
      textAlign = firstText.textAlign;

      for (var i = 1; i < textElements.length; i++) {
        final t = textElements[i];
        if (fontSize != null && t.fontSize != fontSize) fontSize = null;
        if (fontFamily != null && t.fontFamily != fontFamily) fontFamily = null;
        if (textAlign != null && t.textAlign != textAlign) textAlign = null;
      }
    }

    return ElementStyle(
      strokeColor: strokeColor,
      backgroundColor: backgroundColor,
      strokeWidth: strokeWidth,
      strokeStyle: strokeStyle,
      fillStyle: fillStyle,
      roughness: roughness,
      opacity: opacity,
      roundness: roundness,
      hasRoundness: hasRoundness,
      hasText: hasText,
      fontSize: fontSize,
      fontFamily: fontFamily,
      textAlign: textAlign,
    );
  }

  /// Build [ToolResult]s that apply [style] to each element.
  ///
  /// Only non-null properties in [style] are applied. Returns a single
  /// [UpdateElementResult] for one element, or a [CompoundResult] for
  /// multiple elements.
  static ToolResult applyStyle(
    List<Element> elements,
    ElementStyle style,
  ) {
    final results = <ToolResult>[];

    for (final element in elements) {
      Element updated = element;

      // Apply text-specific properties first if applicable
      if (element is TextElement) {
        if (style.fontSize != null ||
            style.fontFamily != null ||
            style.textAlign != null) {
          updated = (updated as TextElement).copyWithText(
            fontSize: style.fontSize,
            fontFamily: style.fontFamily,
            textAlign: style.textAlign,
          );
        }
      }

      // Apply base properties
      updated = updated.copyWith(
        strokeColor: style.strokeColor,
        backgroundColor: style.backgroundColor,
        strokeWidth: style.strokeWidth,
        strokeStyle: style.strokeStyle,
        fillStyle: style.fillStyle,
        roughness: style.roughness,
        opacity: style.opacity,
        roundness: style.roundness,
        clearRoundness: style.roundness == null && style.hasRoundness,
      );

      results.add(UpdateElementResult(updated));
    }

    if (results.length == 1) return results.first;
    return CompoundResult(results);
  }
}
