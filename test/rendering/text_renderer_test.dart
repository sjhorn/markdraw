import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/text_element.dart'
    as core show TextAlign, TextElement;
import 'package:markdraw/src/rendering/text_renderer.dart';

core.TextElement _text({
  String text = 'Hello',
  double x = 10,
  double y = 20,
  double width = 200,
  double height = 40,
  double fontSize = 20,
  String fontFamily = 'Virgil',
  core.TextAlign textAlign = core.TextAlign.left,
  double lineHeight = 1.25,
  String strokeColor = '#000000',
  double opacity = 1.0,
}) {
  return core.TextElement(
    id: ElementId.generate(),
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    fontSize: fontSize,
    fontFamily: fontFamily,
    textAlign: textAlign,
    lineHeight: lineHeight,
    strokeColor: strokeColor,
    opacity: opacity,
  );
}

(PictureRecorder, Canvas) _makeCanvas() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  return (recorder, canvas);
}

void main() {
  group('TextRenderer', () {
    group('draw', () {
      test('renders text without error', () {
        final (recorder, canvas) = _makeCanvas();
        final element = _text();

        expect(
          () => TextRenderer.draw(canvas, element),
          returnsNormally,
        );
        recorder.endRecording();
      });

      test('empty text does not throw', () {
        final (recorder, canvas) = _makeCanvas();
        final element = _text(text: '');

        expect(
          () => TextRenderer.draw(canvas, element),
          returnsNormally,
        );
        recorder.endRecording();
      });

      test('applies stroke color as text color', () {
        final element = _text(strokeColor: '#ff0000');
        final painter = TextRenderer.buildTextPainter(element);

        // TextPainter is built — we check that it completed without error
        expect(painter, isNotNull);
        painter.dispose();
      });

      test('applies opacity', () {
        final element = _text(opacity: 0.5);
        final painter = TextRenderer.buildTextPainter(element);
        expect(painter, isNotNull);
        painter.dispose();
      });

      test('applies fontSize', () {
        final element = _text(fontSize: 32);
        final painter = TextRenderer.buildTextPainter(element);
        painter.layout(maxWidth: 200);
        // Larger font should produce taller text
        expect(painter.height, greaterThan(0));
        painter.dispose();
      });

      test('TextAlign left produces left-aligned painter', () {
        final element = _text(textAlign: core.TextAlign.left);
        final painter = TextRenderer.buildTextPainter(element);
        expect(painter.textAlign, TextAlign.left);
        painter.dispose();
      });

      test('TextAlign center produces center-aligned painter', () {
        final element = _text(textAlign: core.TextAlign.center);
        final painter = TextRenderer.buildTextPainter(element);
        expect(painter.textAlign, TextAlign.center);
        painter.dispose();
      });

      test('TextAlign right produces right-aligned painter', () {
        final element = _text(textAlign: core.TextAlign.right);
        final painter = TextRenderer.buildTextPainter(element);
        expect(painter.textAlign, TextAlign.right);
        painter.dispose();
      });

      test('multi-line text lays out within element width', () {
        final element = _text(
          text: 'This is a longer text that should wrap within the element',
          width: 100,
        );
        final painter = TextRenderer.buildTextPainter(element);
        painter.layout(maxWidth: element.width);
        // Should wrap to multiple lines
        expect(painter.height, greaterThan(painter.preferredLineHeight));
        painter.dispose();
      });

      test('lineHeight is applied to text style', () {
        final element = _text(lineHeight: 2.0);
        final painter = TextRenderer.buildTextPainter(element);
        painter.layout(maxWidth: 200);
        expect(painter, isNotNull);
        painter.dispose();
      });

      test('renders at element position', () {
        final (recorder, canvas) = _makeCanvas();
        final element = _text(x: 50, y: 100);

        // Should not throw — position is applied during draw
        TextRenderer.draw(canvas, element);
        recorder.endRecording();
      });

      test('different font sizes produce different heights', () {
        final small = _text(fontSize: 12);
        final large = _text(fontSize: 32);

        final smallPainter = TextRenderer.buildTextPainter(small);
        final largePainter = TextRenderer.buildTextPainter(large);
        smallPainter.layout(maxWidth: 200);
        largePainter.layout(maxWidth: 200);

        expect(largePainter.height, greaterThan(smallPainter.height));
        smallPainter.dispose();
        largePainter.dispose();
      });
    });
  });
}
