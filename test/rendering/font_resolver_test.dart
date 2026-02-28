import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Prevent HTTP calls in tests
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FontResolver', () {
    test('defaultFontFamily is Excalifont', () {
      expect(FontResolver.defaultFontFamily, 'Excalifont');
    });

    test('resolve bundled Excalifont returns TextStyle with fontFamily', () {
      final style = FontResolver.resolve('Excalifont');
      expect(style.fontFamily, 'Excalifont');
    });

    test('resolve bundled Virgil returns TextStyle with fontFamily', () {
      final style = FontResolver.resolve('Virgil');
      expect(style.fontFamily, 'Virgil');
    });

    test('resolve merges baseStyle properties', () {
      final style = FontResolver.resolve(
        'Excalifont',
        baseStyle: const TextStyle(fontSize: 24, color: Color(0xFF0000FF)),
      );
      expect(style.fontFamily, 'Excalifont');
      expect(style.fontSize, 24);
      expect(style.color, const Color(0xFF0000FF));
    });

    test('Nunito is recognized as a Google Font', () {
      // We can't call GoogleFonts.getFont in unit tests without bundled
      // font assets, so verify the classification instead.
      expect(FontResolver.allFonts, contains('Nunito'));
      expect(FontResolver.uiFonts, contains('Nunito'));
    });

    test('resolve system font returns TextStyle with fontFamily', () {
      final style = FontResolver.resolve('Helvetica');
      expect(style.fontFamily, 'Helvetica');
    });

    test('resolve unknown font returns TextStyle with fontFamily', () {
      final style = FontResolver.resolve('SomeRandomFont');
      expect(style.fontFamily, 'SomeRandomFont');
    });

    test('allFonts contains all known font families', () {
      expect(FontResolver.allFonts, contains('Excalifont'));
      expect(FontResolver.allFonts, contains('Virgil'));
      expect(FontResolver.allFonts, contains('Helvetica'));
      expect(FontResolver.allFonts, contains('Nunito'));
      expect(FontResolver.allFonts, contains('Lilita One'));
      expect(FontResolver.allFonts, contains('Assistant'));
    });

    test('uiFonts is curated subset for property panel', () {
      expect(FontResolver.uiFonts, isNotEmpty);
      expect(FontResolver.uiFonts.first, 'Excalifont');
      // All uiFonts should be in allFonts
      for (final font in FontResolver.uiFonts) {
        expect(FontResolver.allFonts, contains(font));
      }
    });
  });
}
