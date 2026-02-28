import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Resolves font family names to Flutter [TextStyle]s.
///
/// Three resolution strategies:
/// - **Bundled** (`Excalifont`, `Virgil`): resolved from pubspec font assets
/// - **Google Fonts** (`Nunito`, `Lilita One`, `Assistant`): resolved via
///   [GoogleFonts]
/// - **System** (everything else): plain `TextStyle(fontFamily:)` — platform
///   fallback
class FontResolver {
  /// The default font family used for new text elements.
  static const defaultFontFamily = 'Excalifont';

  /// Bundled font families (declared in pubspec.yaml).
  static const _bundledFonts = {'Excalifont', 'Virgil'};

  /// Google Fonts families we support.
  static const _googleFonts = {'Nunito', 'Lilita One', 'Assistant'};

  /// All known font families (for serialization compatibility).
  static const allFonts = [
    'Excalifont',
    'Virgil',
    'Helvetica',
    'Cascadia',
    'Nunito',
    'Lilita One',
    'Comic Shanns',
    'Liberation Sans',
    'Assistant',
  ];

  /// Curated list for the property panel font picker.
  static const uiFonts = [
    'Excalifont',
    'Virgil',
    'Nunito',
    'Lilita One',
    'Assistant',
    'Helvetica',
    'Cascadia',
  ];

  /// Resolves a font family name to a [TextStyle].
  ///
  /// Merges the resolved font into [baseStyle] if provided.
  static TextStyle resolve(String fontFamily, {TextStyle? baseStyle}) {
    final base = baseStyle ?? const TextStyle();

    if (_bundledFonts.contains(fontFamily)) {
      return base.copyWith(fontFamily: fontFamily);
    }

    if (_googleFonts.contains(fontFamily)) {
      return GoogleFonts.getFont(fontFamily, textStyle: base);
    }

    // System font fallback
    return base.copyWith(fontFamily: fontFamily);
  }
}
