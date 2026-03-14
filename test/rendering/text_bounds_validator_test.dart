import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' as core show TextAlign, TextElement;
import 'package:markdraw/markdraw.dart' hide TextAlign, TextElement;

core.TextElement _text({
  String text = 'Hello World',
  double x = 10,
  double y = 20,
  double width = 200,
  double height = 40,
  double fontSize = 20,
  String fontFamily = 'Excalifont',
  core.TextAlign textAlign = core.TextAlign.left,
  double lineHeight = 1.25,
  bool autoResize = true,
  String? containerId,
  bool isDeleted = false,
  ElementId? id,
}) {
  return core.TextElement(
    id: id ?? ElementId.generate(),
    x: x,
    y: y,
    width: width,
    height: height,
    text: text,
    fontSize: fontSize,
    fontFamily: fontFamily,
    textAlign: textAlign,
    lineHeight: lineHeight,
    autoResize: autoResize,
    containerId: containerId,
    isDeleted: isDeleted,
  );
}

void main() {
  group('TextBoundsValidator', () {
    group('validateElement', () {
      test('expands width when text is wider than stored bounds', () {
        // Create a text element with very small width
        final element = _text(
          text: 'A very long text string',
          width: 5,
          height: 5,
        );

        final result = TextBoundsValidator.validateElement(element);

        expect(result.width, greaterThan(5));
      });

      test('expands height when text is taller than stored bounds', () {
        final element = _text(text: 'Hello', width: 200, height: 1);

        final result = TextBoundsValidator.validateElement(element);

        expect(result.height, greaterThan(1));
      });

      test('returns same instance when bounds are already large enough', () {
        // Measure the text first to get its actual size
        final element = _text(text: 'Hi', width: 500, height: 500);

        final result = TextBoundsValidator.validateElement(element);

        expect(identical(result, element), isTrue);
      });

      test('returns same instance for empty text', () {
        final element = _text(text: '', width: 10, height: 10);

        final result = TextBoundsValidator.validateElement(element);

        expect(identical(result, element), isTrue);
      });

      test('autoResize=false only expands height, keeps width fixed', () {
        final element = _text(
          text: 'This is text that might wrap within a narrow width',
          width: 50,
          height: 1,
          autoResize: false,
        );

        final result = TextBoundsValidator.validateElement(element);

        // Width must stay at 50 (fixed)
        expect(result.width, equals(50));
        // Height should expand to fit wrapped text
        expect(result.height, greaterThan(1));
      });

      test(
        'autoResize=false returns same instance when height is sufficient',
        () {
          final element = _text(
            text: 'Hi',
            width: 200,
            height: 500,
            autoResize: false,
          );

          final result = TextBoundsValidator.validateElement(element);

          expect(identical(result, element), isTrue);
        },
      );

      test('preserves element id after validation', () {
        final elementId = ElementId.generate();
        final element = _text(
          id: elementId,
          text: 'Hello',
          width: 1,
          height: 1,
        );

        final result = TextBoundsValidator.validateElement(element);

        expect(result.id, equals(elementId));
      });

      test('preserves position after validation', () {
        final element = _text(text: 'Hello', x: 42, y: 99, width: 1, height: 1);

        final result = TextBoundsValidator.validateElement(element);

        expect(result.x, equals(42));
        expect(result.y, equals(99));
      });
    });

    group('validateScene', () {
      test('expands bounds of text element with small bounds', () {
        final textEl = _text(text: 'Hello World', width: 1, height: 1);
        final scene = Scene().addElement(textEl);

        final result = TextBoundsValidator.validateScene(scene);

        final updated = result.getElementById(textEl.id) as core.TextElement;
        expect(updated.width, greaterThan(1));
        expect(updated.height, greaterThan(1));
      });

      test('returns same scene when no changes needed', () {
        final textEl = _text(text: 'Hi', width: 500, height: 500);
        final scene = Scene().addElement(textEl);

        final result = TextBoundsValidator.validateScene(scene);

        expect(identical(result, scene), isTrue);
      });

      test('skips bound text elements (containerId != null)', () {
        final textEl = _text(
          text: 'Bound text',
          width: 1,
          height: 1,
          containerId: 'parent-shape-id',
        );
        final scene = Scene().addElement(textEl);

        final result = TextBoundsValidator.validateScene(scene);

        // Should be unchanged — bound text is skipped
        expect(identical(result, scene), isTrue);
      });

      test('skips non-text elements', () {
        final rect = RectangleElement(
          id: ElementId.generate(),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        );
        final scene = Scene().addElement(rect);

        final result = TextBoundsValidator.validateScene(scene);

        expect(identical(result, scene), isTrue);
      });

      test('handles empty scene', () {
        final scene = Scene();

        final result = TextBoundsValidator.validateScene(scene);

        expect(identical(result, scene), isTrue);
      });

      test('skips deleted text elements', () {
        final textEl = _text(
          text: 'Deleted text',
          width: 1,
          height: 1,
          isDeleted: true,
        );
        final scene = Scene().addElement(textEl);

        final result = TextBoundsValidator.validateScene(scene);

        expect(identical(result, scene), isTrue);
      });

      test('validates multiple text elements', () {
        final text1 = _text(text: 'First', width: 1, height: 1);
        final text2 = _text(text: 'Second', width: 1, height: 1);
        final scene = Scene().addElement(text1).addElement(text2);

        final result = TextBoundsValidator.validateScene(scene);

        final updated1 = result.getElementById(text1.id) as core.TextElement;
        final updated2 = result.getElementById(text2.id) as core.TextElement;
        expect(updated1.width, greaterThan(1));
        expect(updated2.width, greaterThan(1));
      });

      test('only modifies elements that need it', () {
        final smallText = _text(text: 'Hello', width: 1, height: 1);
        final largeText = _text(text: 'Hi', width: 500, height: 500);
        final scene = Scene().addElement(smallText).addElement(largeText);

        final result = TextBoundsValidator.validateScene(scene);

        final updatedSmall =
            result.getElementById(smallText.id) as core.TextElement;
        final updatedLarge =
            result.getElementById(largeText.id) as core.TextElement;
        // Small text bounds should be expanded
        expect(updatedSmall.width, greaterThan(1));
        // Large text bounds should stay the same
        expect(updatedLarge.width, equals(500));
        expect(updatedLarge.height, equals(500));
      });

      test('round-trip: small bounds corrected after parse', () {
        // Create a scene, serialize, parse back, validate
        final textEl = _text(text: 'Test text', width: 200, height: 40);
        final scene = Scene().addElement(textEl);

        // Serialize to .markdraw
        final doc = SceneDocumentConverter.sceneToDocument(scene);
        final content = DocumentSerializer.serialize(doc);

        // Parse back — this may produce different bounds
        final parsed = DocumentParser.parse(content);
        final parsedScene = SceneDocumentConverter.documentToScene(
          parsed.value,
        );

        // Validate should ensure bounds are correct
        final validated = TextBoundsValidator.validateScene(parsedScene);

        // Find the text element
        final validatedElements = validated.activeElements
            .whereType<core.TextElement>()
            .where((e) => e.containerId == null)
            .toList();
        expect(validatedElements, hasLength(1));

        // Measure what the actual rendered size would be
        final (measuredW, measuredH) = TextRenderer.measure(
          validatedElements.first,
        );
        // Validated bounds should be >= measured size
        expect(validatedElements.first.width, greaterThanOrEqualTo(measuredW));
        expect(validatedElements.first.height, greaterThanOrEqualTo(measuredH));
      });
    });
  });
}
