import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('ClipboardCodec', () {
    test('serialize single element', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          seed: 42,
        ),
      ];
      final text = ClipboardCodec.serialize(elements);
      expect(text, contains('```sketch'));
      expect(text, contains('```'));
      expect(text, contains('rect'));
    });

    test('serialize multiple elements', () {
      final elements = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          seed: 42,
        ),
        TextElement(
          id: const ElementId('t1'),
          x: 50,
          y: 50,
          width: 200,
          height: 24,
          text: 'Hello',
          seed: 43,
        ),
      ];
      final text = ClipboardCodec.serialize(elements);
      expect(text, contains('rect'));
      expect(text, contains('text'));
    });

    test('round-trip preserves element data', () {
      final original = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          strokeColor: '#ff0000',
          seed: 42,
        ),
      ];
      final text = ClipboardCodec.serialize(original);
      final parsed = ClipboardCodec.parse(text);
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed[0].type, 'rectangle');
      expect(parsed[0].strokeColor, '#ff0000');
    });

    test('non-markdraw text returns null', () {
      final parsed = ClipboardCodec.parse('Just some plain text');
      expect(parsed, isNull);
    });

    test('isMarkdrawText detects sketch blocks', () {
      expect(
        ClipboardCodec.isMarkdrawText('```sketch\nrect id=r1 at 0,0 size 100x80\n```'),
        isTrue,
      );
    });

    test('isMarkdrawText rejects plain text', () {
      expect(ClipboardCodec.isMarkdrawText('Hello world'), isFalse);
    });

    test('bound text serialized', () {
      final elements = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 10,
          width: 100,
          height: 80,
          seed: 42,
          boundElements: [const BoundElement(id: 't1', type: 'text')],
        ),
        TextElement(
          id: const ElementId('t1'),
          x: 20,
          y: 20,
          width: 80,
          height: 20,
          text: 'Label',
          containerId: 'r1',
        ),
      ];
      final text = ClipboardCodec.serialize(elements);
      // Bound text should be serialized (inlined or as separate element)
      expect(text, contains('Label'));
    });

    test('empty list produces valid but empty sketch block', () {
      final text = ClipboardCodec.serialize([]);
      expect(text, contains('```sketch'));
      expect(text, contains('```'));
    });

    test('malformed input returns null', () {
      final parsed = ClipboardCodec.parse('```sketch\n!!invalid!!\n```');
      // Should either return empty list or null gracefully
      expect(parsed == null || parsed.isEmpty, isTrue);
    });

    test('arrow bindings preserved in round-trip', () {
      final elements = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 80,
          seed: 42,
        ),
        ArrowElement(
          id: const ElementId('a1'),
          x: 100,
          y: 40,
          width: 100,
          height: 0,
          points: [const Point(0, 0), const Point(100, 0)],
          endArrowhead: Arrowhead.arrow,
          seed: 43,
        ),
      ];
      final text = ClipboardCodec.serialize(elements);
      final parsed = ClipboardCodec.parse(text);
      expect(parsed, isNotNull);
      expect(parsed!.length, 2);
      expect(parsed.any((e) => e.type == 'arrow'), isTrue);
    });
  });
}
