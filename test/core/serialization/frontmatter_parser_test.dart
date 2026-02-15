import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/serialization/canvas_settings.dart';
import 'package:markdraw/src/core/serialization/frontmatter_parser.dart';

void main() {
  group('FrontmatterParser', () {
    test('parses basic frontmatter', () {
      const input = '''---
markdraw: 1
background: "#ffffff"
---

# Hello''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.formatVersion, 1);
      expect(result.value.settings.background, '#ffffff');
      expect(result.value.remaining.trim(), '# Hello');
      expect(result.warnings, isEmpty);
    });

    test('parses frontmatter with grid', () {
      const input = '''---
markdraw: 1
background: "#000000"
grid: 20
---

Content''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.background, '#000000');
      expect(result.value.settings.grid, 20);
    });

    test('handles no frontmatter', () {
      const input = '# Just markdown\n\nSome content';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings, equals(CanvasSettings()));
      expect(result.value.remaining, input);
    });

    test('handles empty input', () {
      final result = FrontmatterParser.parse('');
      expect(result.value.settings, equals(CanvasSettings()));
      expect(result.value.remaining, '');
    });

    test('handles frontmatter with quotes stripped', () {
      const input = '''---
markdraw: 1
background: "#e0e0e0"
---
rest''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.background, '#e0e0e0');
    });

    test('handles frontmatter without quotes on background', () {
      const input = '''---
markdraw: 1
background: #e0e0e0
---
rest''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.background, '#e0e0e0');
    });

    test('handles frontmatter with only markdraw version', () {
      const input = '''---
markdraw: 1
---
content''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.formatVersion, 1);
      expect(result.value.settings.background, '#ffffff');
      expect(result.value.settings.grid, isNull);
    });

    test('unknown keys produce warnings', () {
      const input = '''---
markdraw: 1
unknown_key: value
---
rest''';
      final result = FrontmatterParser.parse(input);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('unknown_key'));
    });

    test('preserves remaining content exactly', () {
      const input = '''---
markdraw: 1
---
Line 1
Line 2

Line 4''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.remaining, 'Line 1\nLine 2\n\nLine 4');
    });

    test('handles unclosed frontmatter gracefully', () {
      const input = '''---
markdraw: 1
background: "#fff"
no closing delimiter''';
      final result = FrontmatterParser.parse(input);
      // Treat entire input as content (no valid frontmatter)
      expect(result.value.settings, equals(CanvasSettings()));
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('unclosed'));
    });

    test('handles version 2', () {
      const input = '''---
markdraw: 2
---
content''';
      final result = FrontmatterParser.parse(input);
      expect(result.value.settings.formatVersion, 2);
    });
  });
}
