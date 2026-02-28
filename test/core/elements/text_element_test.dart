import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('TextElement', () {
    TextElement createText({
      String text = 'Hello',
      double fontSize = 20.0,
      String fontFamily = 'Excalifont',
      TextAlign textAlign = TextAlign.left,
      String? containerId,
      double lineHeight = 1.25,
      bool autoResize = true,
    }) {
      return TextElement(
        id: const ElementId('txt-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 25.0,
        text: text,
        fontSize: fontSize,
        fontFamily: fontFamily,
        textAlign: textAlign,
        containerId: containerId,
        lineHeight: lineHeight,
        autoResize: autoResize,
      );
    }

    test('constructs with type text and text properties', () {
      final t = createText(text: 'Hello World');
      expect(t.type, 'text');
      expect(t.text, 'Hello World');
      expect(t.fontSize, 20.0);
      expect(t.fontFamily, 'Excalifont');
      expect(t.textAlign, TextAlign.left);
      expect(t.lineHeight, 1.25);
      expect(t.autoResize, true);
    });

    test('supports containerId for bound text', () {
      final t = createText(containerId: 'rect-1');
      expect(t.containerId, 'rect-1');
    });

    test('copyWith preserves text-specific properties', () {
      final t = createText(text: 'Original');
      final modified = t.copyWith(x: 50.0);
      expect(modified.text, 'Original');
      expect(modified.fontSize, 20.0);
      expect(modified.x, 50.0);
    });

    test('copyWithText changes text properties', () {
      final t = createText(text: 'Before');
      final modified = t.copyWithText(text: 'After', fontSize: 30.0);
      expect(modified.text, 'After');
      expect(modified.fontSize, 30.0);
    });

    test('bumpVersion returns TextElement', () {
      final t = createText();
      final bumped = t.bumpVersion();
      expect(bumped, isA<TextElement>());
      expect((bumped as TextElement).text, 'Hello');
    });
  });
}
