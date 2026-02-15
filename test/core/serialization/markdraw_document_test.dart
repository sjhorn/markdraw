import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/serialization/canvas_settings.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

void main() {
  group('MarkdrawDocument', () {
    late RectangleElement rect;
    late EllipseElement ellipse;
    late TextElement text;

    setUp(() {
      rect = RectangleElement(
        id: const ElementId('rect-uuid'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      ellipse = EllipseElement(
        id: const ElementId('ellipse-uuid'),
        x: 225,
        y: 400,
        width: 120,
        height: 80,
        seed: 2,
        versionNonce: 2,
        updated: 0,
      );
      text = TextElement(
        id: const ElementId('text-uuid'),
        x: 100,
        y: 50,
        width: 200,
        height: 30,
        text: 'Hello',
        seed: 3,
        versionNonce: 3,
        updated: 0,
      );
    });

    test('default settings and empty sections', () {
      final doc = MarkdrawDocument();
      expect(doc.settings, equals(const CanvasSettings()));
      expect(doc.sections, isEmpty);
      expect(doc.aliases, isEmpty);
    });

    test('stores settings, sections, and aliases', () {
      const settings = CanvasSettings(grid: 20);
      final aliases = {'auth': 'rect-uuid', 'db': 'ellipse-uuid'};
      final sections = <DocumentSection>[
        const ProseSection('# Title'),
        SketchSection([rect, ellipse]),
      ];

      final doc = MarkdrawDocument(
        settings: settings,
        sections: sections,
        aliases: aliases,
      );

      expect(doc.settings.grid, 20);
      expect(doc.sections, hasLength(2));
      expect(doc.aliases['auth'], 'rect-uuid');
    });

    test('allElements collects elements from all sketch sections', () {
      final doc = MarkdrawDocument(
        sections: [
          const ProseSection('intro'),
          SketchSection([rect]),
          const ProseSection('middle'),
          SketchSection([ellipse, text]),
        ],
      );

      expect(doc.allElements, hasLength(3));
      expect(doc.allElements[0], rect);
      expect(doc.allElements[1], ellipse);
      expect(doc.allElements[2], text);
    });

    test('allElements returns empty for prose-only document', () {
      final doc = MarkdrawDocument(
        sections: [const ProseSection('just text')],
      );
      expect(doc.allElements, isEmpty);
    });

    test('aliases map is unmodifiable', () {
      final doc = MarkdrawDocument(aliases: {'a': 'b'});
      expect(
        () => doc.aliases['c'] = 'd',
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('sections list is unmodifiable', () {
      final doc = MarkdrawDocument(sections: [const ProseSection('x')]);
      expect(
        () => doc.sections.add(const ProseSection('y')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('copyWith replaces fields', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(grid: 20),
        sections: [const ProseSection('old')],
        aliases: {'a': 'b'},
      );

      final modified = doc.copyWith(
        settings: const CanvasSettings(grid: 40),
        sections: [SketchSection([rect])],
      );

      expect(modified.settings.grid, 40);
      expect(modified.sections.first, isA<SketchSection>());
      expect(modified.aliases['a'], 'b'); // preserved
    });

    test('copyWith preserves unspecified fields', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(grid: 20),
        aliases: {'x': 'y'},
      );
      final modified = doc.copyWith(sections: [const ProseSection('new')]);
      expect(modified.settings.grid, 20);
      expect(modified.aliases['x'], 'y');
    });

    test('resolveAlias looks up element ID from alias', () {
      final doc = MarkdrawDocument(
        aliases: {'auth': 'rect-uuid'},
      );
      expect(doc.resolveAlias('auth'), 'rect-uuid');
      expect(doc.resolveAlias('unknown'), isNull);
    });

    test('aliasFor looks up alias from element ID', () {
      final doc = MarkdrawDocument(
        aliases: {'auth': 'rect-uuid', 'db': 'ellipse-uuid'},
      );
      expect(doc.aliasFor('rect-uuid'), 'auth');
      expect(doc.aliasFor('unknown'), isNull);
    });
  });
}
