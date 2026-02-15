import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';

void main() {
  group('ProseSection', () {
    test('stores content', () {
      final section = ProseSection('Hello world');
      expect(section.content, 'Hello world');
    });

    test('equality based on content', () {
      final a = ProseSection('abc');
      final b = ProseSection('abc');
      final c = ProseSection('xyz');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('is a DocumentSection', () {
      final section = ProseSection('text');
      expect(section, isA<DocumentSection>());
    });
  });

  group('SketchSection', () {
    test('stores elements', () {
      final rect = RectangleElement(
        id: ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final section = SketchSection([rect]);
      expect(section.elements, hasLength(1));
      expect(section.elements.first, rect);
    });

    test('elements list is unmodifiable', () {
      final section = SketchSection([]);
      expect(
        () => section.elements.add(
          RectangleElement(
            id: ElementId('r1'),
            x: 0,
            y: 0,
            width: 100,
            height: 50,
            seed: 1,
            versionNonce: 1,
            updated: 0,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('equality based on elements', () {
      final rect = RectangleElement(
        id: ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final a = SketchSection([rect]);
      final b = SketchSection([rect]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('is a DocumentSection', () {
      final section = SketchSection([]);
      expect(section, isA<DocumentSection>());
    });
  });

  group('DocumentSection pattern matching', () {
    test('switch exhaustive on sealed class', () {
      final sections = <DocumentSection>[
        ProseSection('intro'),
        SketchSection([]),
      ];

      final types = sections.map((s) {
        return switch (s) {
          ProseSection() => 'prose',
          SketchSection() => 'sketch',
        };
      }).toList();

      expect(types, ['prose', 'sketch']);
    });
  });
}
