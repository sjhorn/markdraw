import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// A mock clipboard service for testing.
class MockClipboardService implements ClipboardService {
  String? _content;

  @override
  Future<void> copyText(String text) async {
    _content = text;
  }

  @override
  Future<String?> readText() async {
    return _content;
  }
}

void main() {
  group('ClipboardService', () {
    test('mock service stores and retrieves text', () async {
      final service = MockClipboardService();
      await service.copyText('hello');
      final result = await service.readText();
      expect(result, 'hello');
    });

    test('copy elements to system clipboard', () async {
      final service = MockClipboardService();
      final elements = <Element>[
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
      await service.copyText(text);
      final stored = await service.readText();
      expect(stored, isNotNull);
      expect(ClipboardCodec.isMarkdrawText(stored!), isTrue);
    });

    test('paste markdraw text from system clipboard', () async {
      final service = MockClipboardService();
      final elements = <Element>[
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
      await service.copyText(text);

      final stored = await service.readText();
      expect(stored, isNotNull);
      if (ClipboardCodec.isMarkdrawText(stored!)) {
        final parsed = ClipboardCodec.parse(stored);
        expect(parsed, isNotNull);
        expect(parsed!.length, 1);
        expect(parsed[0].type, 'rectangle');
      }
    });

    test('paste non-markdraw falls back to internal', () async {
      final service = MockClipboardService();
      await service.copyText('Just some plain text');

      final stored = await service.readText();
      expect(stored, isNotNull);
      expect(ClipboardCodec.isMarkdrawText(stored!), isFalse);
      // Caller should fall back to internal clipboard
    });

    test('empty clipboard returns null', () async {
      final service = MockClipboardService();
      final result = await service.readText();
      expect(result, isNull);
    });

    test('cut writes to system clipboard', () async {
      final service = MockClipboardService();
      final elements = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          seed: 42,
        ),
      ];
      // Simulate cut: serialize and copy
      final text = ClipboardCodec.serialize(elements);
      await service.copyText(text);

      // Verify it's there
      final stored = await service.readText();
      expect(stored, isNotNull);
      expect(ClipboardCodec.isMarkdrawText(stored!), isTrue);
    });

    test('includes bound text in clipboard', () async {
      final service = MockClipboardService();
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
      await service.copyText(text);

      final stored = await service.readText();
      expect(stored, isNotNull);
      expect(stored!, contains('Label'));
    });

    test('round-trip through clipboard produces valid elements', () async {
      final service = MockClipboardService();
      final original = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          strokeColor: '#ff0000',
          backgroundColor: '#00ff00',
          seed: 42,
        ),
      ];

      // Copy
      await service.copyText(ClipboardCodec.serialize(original));

      // Paste
      final stored = await service.readText();
      final parsed = ClipboardCodec.parse(stored!);
      expect(parsed, isNotNull);
      expect(parsed![0].strokeColor, '#ff0000');
      expect(parsed[0].backgroundColor, '#00ff00');
    });

    test('new IDs should be generated on paste by caller', () async {
      final service = MockClipboardService();
      final original = <Element>[
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          seed: 42,
        ),
      ];

      await service.copyText(ClipboardCodec.serialize(original));
      final stored = await service.readText();
      final parsed = ClipboardCodec.parse(stored!);
      expect(parsed, isNotNull);
      // The parser generates fresh IDs during parsing
      // (no stable ID preservation in .markdraw text format)
      expect(parsed![0].id, isNotNull);
      expect(parsed[0].type, 'rectangle');
    });

    test('graceful handling when clipboard unavailable', () async {
      // Simulate unavailable clipboard by using empty mock
      final service = MockClipboardService();
      final result = await service.readText();
      expect(result, isNull);
      // Caller falls back to internal clipboard
    });
  });
}
