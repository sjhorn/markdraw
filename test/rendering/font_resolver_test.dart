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

    test('expanded uiFonts includes new fonts', () {
      expect(FontResolver.uiFonts, contains('Roboto'));
      expect(FontResolver.uiFonts, contains('Source Code Pro'));
      expect(FontResolver.uiFonts, contains('Fira Code'));
      expect(FontResolver.uiFonts, contains('Caveat'));
      expect(FontResolver.uiFonts, contains('Pacifico'));
      expect(FontResolver.uiFonts, contains('Dancing Script'));
      expect(FontResolver.uiFonts, contains('Open Sans'));
      expect(FontResolver.uiFonts, contains('Lato'));
      expect(FontResolver.uiFonts, contains('Montserrat'));
      expect(FontResolver.uiFonts, contains('Playfair Display'));
    });
  });

  group('FontCategory', () {
    test('enum has 3 values', () {
      expect(FontCategory.values, hasLength(3));
      expect(FontCategory.values, contains(FontCategory.handDrawn));
      expect(FontCategory.values, contains(FontCategory.normal));
      expect(FontCategory.values, contains(FontCategory.code));
    });

    test('categoryOf returns correct category for known fonts', () {
      expect(FontResolver.categoryOf('Excalifont'), FontCategory.handDrawn);
      expect(FontResolver.categoryOf('Virgil'), FontCategory.handDrawn);
      expect(FontResolver.categoryOf('Caveat'), FontCategory.handDrawn);
      expect(FontResolver.categoryOf('Nunito'), FontCategory.normal);
      expect(FontResolver.categoryOf('Roboto'), FontCategory.normal);
      expect(FontResolver.categoryOf('Source Code Pro'), FontCategory.code);
      expect(FontResolver.categoryOf('Fira Code'), FontCategory.code);
      expect(FontResolver.categoryOf('Cascadia'), FontCategory.code);
    });

    test('categoryOf defaults to normal for unknown fonts', () {
      expect(FontResolver.categoryOf('SomeRandomFont'), FontCategory.normal);
      expect(FontResolver.categoryOf('Arial'), FontCategory.normal);
    });

    test('defaultForCategory maps each category', () {
      expect(
        FontResolver.defaultForCategory[FontCategory.handDrawn],
        'Excalifont',
      );
      expect(
        FontResolver.defaultForCategory[FontCategory.normal],
        'Helvetica',
      );
      expect(
        FontResolver.defaultForCategory[FontCategory.code],
        'Cascadia',
      );
    });

    test('defaultForCategory fonts are all in allFonts', () {
      for (final font in FontResolver.defaultForCategory.values) {
        expect(FontResolver.allFonts, contains(font));
      }
    });

    test('all uiFonts have a fontCategories entry', () {
      for (final font in FontResolver.uiFonts) {
        expect(
          FontResolver.fontCategories.containsKey(font),
          isTrue,
          reason: '$font should have a category entry',
        );
      }
    });
  });
}
