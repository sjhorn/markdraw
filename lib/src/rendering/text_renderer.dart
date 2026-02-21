import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/elements/text_element.dart' as core;

/// Renders text elements using Flutter's [TextPainter].
///
/// Text is not drawn with rough_flutter — it uses standard Flutter text
/// layout for readability. This mirrors how Excalidraw renders text
/// (clean, not hand-drawn).
class TextRenderer {
  /// Measures the text in [element] and returns `(width, height)`.
  ///
  /// If [maxWidth] is provided, the text wraps within that width.
  /// Returns `(0, 0)` for empty text.
  static (double, double) measure(core.TextElement element,
      {double? maxWidth}) {
    if (element.text.isEmpty) return (0.0, 0.0);

    final painter = buildTextPainter(element);
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    final result = (painter.width, painter.height);
    painter.dispose();
    return result;
  }

  /// Draws a [TextElement] onto [canvas] at the element's position.
  static void draw(ui.Canvas canvas, core.TextElement element) {
    if (element.text.isEmpty) return;

    final painter = buildTextPainter(element);
    painter.layout(maxWidth: element.width);
    painter.paint(canvas, Offset(element.x, element.y));
    painter.dispose();
  }

  /// Builds a [TextPainter] configured from the given [element].
  ///
  /// Callers must call [TextPainter.layout] before painting, and
  /// [TextPainter.dispose] when done.
  static TextPainter buildTextPainter(core.TextElement element) {
    final color = _parseColor(element.strokeColor)
        .withValues(alpha: element.opacity);

    final style = TextStyle(
      color: color,
      fontSize: element.fontSize,
      fontFamily: element.fontFamily,
      height: element.lineHeight,
    );

    return TextPainter(
      text: TextSpan(text: element.text, style: style),
      textAlign: _mapTextAlign(element.textAlign),
      textDirection: ui.TextDirection.ltr,
    );
  }

  static TextAlign _mapTextAlign(core.TextAlign align) {
    return switch (align) {
      core.TextAlign.left => TextAlign.left,
      core.TextAlign.center => TextAlign.center,
      core.TextAlign.right => TextAlign.right,
    };
  }

  static Color _parseColor(String colorStr) {
    if (colorStr == 'transparent') {
      return const Color(0x00000000);
    }
    final hex = colorStr.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('ff$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF000000);
  }
}
