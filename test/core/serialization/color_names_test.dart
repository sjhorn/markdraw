import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/serialization/color_names.dart';

void main() {
  group('colorNameToHex', () {
    test('contains 148 CSS named colors', () {
      expect(colorNameToHex.length, 148);
    });

    test('known colors map correctly', () {
      expect(colorNameToHex['red'], '#ff0000');
      expect(colorNameToHex['blue'], '#0000ff');
      expect(colorNameToHex['lime'], '#00ff00');
      expect(colorNameToHex['cornflowerblue'], '#6495ed');
      expect(colorNameToHex['white'], '#ffffff');
      expect(colorNameToHex['black'], '#000000');
    });

    test('does not contain transparent', () {
      expect(colorNameToHex.containsKey('transparent'), isFalse);
    });

    test('all keys are lowercase', () {
      for (final key in colorNameToHex.keys) {
        expect(key, key.toLowerCase(), reason: '$key should be lowercase');
      }
    });

    test('all values are #rrggbb format', () {
      final hexPattern = RegExp(r'^#[0-9a-f]{6}$');
      for (final entry in colorNameToHex.entries) {
        expect(
          hexPattern.hasMatch(entry.value),
          isTrue,
          reason: '${entry.key}: ${entry.value} should be #rrggbb',
        );
      }
    });
  });

  group('hexToColorName', () {
    test('reverse lookup works', () {
      expect(hexToColorName['#ff0000'], 'red');
      expect(hexToColorName['#0000ff'], 'blue');
      expect(hexToColorName['#00ff00'], 'lime');
      expect(hexToColorName['#6495ed'], 'cornflowerblue');
    });

    test('duplicates resolve to preferred name', () {
      // aqua and cyan both map to #00ffff — prefer cyan (CMYK standard)
      expect(hexToColorName['#00ffff'], 'cyan');
      // fuchsia and magenta both map to #ff00ff — prefer magenta
      expect(hexToColorName['#ff00ff'], 'magenta');
    });
  });

  group('normalizeColor', () {
    test('CSS named color to hex', () {
      expect(normalizeColor('red'), '#ff0000');
      expect(normalizeColor('blue'), '#0000ff');
      expect(normalizeColor('cornflowerblue'), '#6495ed');
    });

    test('case-insensitive lookup', () {
      expect(normalizeColor('Red'), '#ff0000');
      expect(normalizeColor('RED'), '#ff0000');
      expect(normalizeColor('CornflowerBlue'), '#6495ed');
    });

    test('short hex expands to full hex', () {
      expect(normalizeColor('#ccc'), '#cccccc');
      expect(normalizeColor('#abc'), '#aabbcc');
      expect(normalizeColor('#f00'), '#ff0000');
    });

    test('full hex passes through', () {
      expect(normalizeColor('#e3f2fd'), '#e3f2fd');
      expect(normalizeColor('#ff0000'), '#ff0000');
    });

    test('full hex lowercased', () {
      expect(normalizeColor('#FF0000'), '#ff0000');
      expect(normalizeColor('#E3F2FD'), '#e3f2fd');
    });

    test('transparent passes through', () {
      expect(normalizeColor('transparent'), 'transparent');
    });

    test('unknown value passes through', () {
      expect(normalizeColor('notacolor'), 'notacolor');
    });
  });

  group('formatColor', () {
    test('known CSS color uses name', () {
      expect(formatColor('#ff0000'), 'red');
      expect(formatColor('#0000ff'), 'blue');
      expect(formatColor('#00ff00'), 'lime');
    });

    test('shortenable hex uses short form', () {
      expect(formatColor('#cccccc'), '#ccc');
      expect(formatColor('#aabbcc'), '#abc');
      expect(formatColor('#112233'), '#123');
    });

    test('non-shortenable hex passes through', () {
      expect(formatColor('#e3f2fd'), '#e3f2fd');
      expect(formatColor('#1e1e1e'), '#1e1e1e');
      expect(formatColor('#d32f2f'), '#d32f2f');
    });

    test('named color takes priority over short hex', () {
      // #ff0000 could shorten to #f00, but 'red' is shorter
      expect(formatColor('#ff0000'), 'red');
    });

    test('magenta round-trips as magenta (not fuchsia)', () {
      expect(formatColor('#ff00ff'), 'magenta');
      expect(normalizeColor('magenta'), '#ff00ff');
    });

    test('cyan round-trips as cyan (not aqua)', () {
      expect(formatColor('#00ffff'), 'cyan');
      expect(normalizeColor('cyan'), '#00ffff');
    });

    test('round-trip: formatColor output normalizes back', () {
      const testColors = [
        '#ff0000',
        '#0000ff',
        '#cccccc',
        '#e3f2fd',
        '#1e1e1e',
      ];
      for (final color in testColors) {
        final formatted = formatColor(color);
        final normalized = normalizeColor(formatted);
        expect(
          normalized,
          color,
          reason: '$color → $formatted → $normalized should round-trip',
        );
      }
    });

    test(
      'every named color round-trips through normalize → format → normalize',
      () {
        for (final entry in colorNameToHex.entries) {
          final name = entry.key;
          final hex = entry.value;

          // name → hex → formatted name → hex again
          final normalized = normalizeColor(name);
          expect(normalized, hex, reason: '$name should normalize to $hex');

          final formatted = formatColor(normalized);
          final renormalized = normalizeColor(formatted);
          expect(
            renormalized,
            hex,
            reason:
                '$name → $hex → $formatted → $renormalized should round-trip to $hex',
          );
        }
      },
    );

    test('every named color hex round-trips through format → normalize', () {
      // Collect unique hex values (some names share the same hex)
      final uniqueHexValues = colorNameToHex.values.toSet();
      for (final hex in uniqueHexValues) {
        final formatted = formatColor(hex);
        final normalized = normalizeColor(formatted);
        expect(
          normalized,
          hex,
          reason: '$hex → $formatted → $normalized should round-trip',
        );
      }
    });
  });
}
