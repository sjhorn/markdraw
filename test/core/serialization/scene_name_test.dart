import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('Scene name', () {
    group('CanvasSettings', () {
      test('with name is not default', () {
        const settings = CanvasSettings(name: 'My Drawing');
        expect(settings.isDefault, isFalse);
      });

      test('without name is default', () {
        const settings = CanvasSettings();
        expect(settings.name, isNull);
        expect(settings.isDefault, isTrue);
      });

      test('copyWith sets name', () {
        const settings = CanvasSettings();
        final updated = settings.copyWith(name: 'Test');
        expect(updated.name, 'Test');
      });

      test('copyWith preserves name when not specified', () {
        const settings = CanvasSettings(name: 'Keep Me');
        final updated = settings.copyWith(background: '#000');
        expect(updated.name, 'Keep Me');
      });

      test('copyWith clearName sets name to null', () {
        const settings = CanvasSettings(name: 'Remove Me');
        final updated = settings.copyWith(clearName: true);
        expect(updated.name, isNull);
      });

      test('equality includes name', () {
        const a = CanvasSettings(name: 'A');
        const b = CanvasSettings(name: 'A');
        const c = CanvasSettings(name: 'B');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(equals(c)));
      });
    });

    group('.markdraw round-trip', () {
      test('name present is serialized as @name directive and parsed back', () {
        final doc = MarkdrawDocument(
          sections: [SketchSection(const [])],
          settings: const CanvasSettings(name: 'My Drawing'),
        );
        final serialized = DocumentSerializer.serialize(doc);
        expect(serialized, contains('@name "My Drawing"'));

        final parsed = DocumentParser.parse(serialized);
        expect(parsed.value.settings.name, 'My Drawing');
      });

      test('name absent produces no @name line in output', () {
        final doc = MarkdrawDocument(
          sections: [SketchSection(const [])],
          settings: const CanvasSettings(background: '#f0f0f0'),
        );
        final serialized = DocumentSerializer.serialize(doc);
        expect(serialized, isNot(contains('@name')));

        final parsed = DocumentParser.parse(serialized);
        expect(parsed.value.settings.name, isNull);
      });

      test('name is inside sketch block not frontmatter', () {
        final doc = MarkdrawDocument(
          sections: [SketchSection(const [])],
          settings: const CanvasSettings(name: 'Test'),
        );
        final serialized = DocumentSerializer.serialize(doc);
        // @name should appear after ```markdraw
        final markdrawIdx = serialized.indexOf('```markdraw');
        final nameIdx = serialized.indexOf('@name');
        expect(markdrawIdx, greaterThanOrEqualTo(0));
        expect(nameIdx, greaterThan(markdrawIdx));
      });

      test('legacy frontmatter name is not parsed', () {
        // Name in frontmatter should be treated as unknown key
        const content =
            '---\nmarkdraw: 1\nname: "Old"\nbackground: "#ffffff"\n---\n'
            '```markdraw\n```';
        final parsed = DocumentParser.parse(content);
        expect(parsed.value.settings.name, isNull);
      });
    });

    group('Excalidraw JSON round-trip', () {
      test('appState.name preserved', () {
        final doc = MarkdrawDocument(
          sections: [SketchSection(const [])],
          settings: const CanvasSettings(name: 'Excalidraw Doc'),
        );
        final json = ExcalidrawJsonCodec.serialize(doc);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['appState']['name'], 'Excalidraw Doc');

        final parsed = ExcalidrawJsonCodec.parse(json);
        expect(parsed.value.settings.name, 'Excalidraw Doc');
      });

      test('without name: no error, name is null', () {
        final json = jsonEncode({
          'type': 'excalidraw',
          'version': 2,
          'elements': <dynamic>[],
          'appState': {'viewBackgroundColor': '#ffffff'},
          'files': <String, dynamic>{},
        });
        final parsed = ExcalidrawJsonCodec.parse(json);
        expect(parsed.value.settings.name, isNull);
        expect(parsed.warnings, isEmpty);
      });

      test('name not serialized when null', () {
        final doc = MarkdrawDocument(
          sections: [SketchSection(const [])],
          settings: const CanvasSettings(),
        );
        final json = ExcalidrawJsonCodec.serialize(doc);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['appState'].containsKey('name'), isFalse);
      });
    });

    group('Controller', () {
      test('renameDocument updates documentName', () {
        final controller = MarkdrawController();
        addTearDown(controller.dispose);

        expect(controller.documentName, isNull);
        controller.renameDocument('New Name');
        expect(controller.documentName, 'New Name');
      });

      test('renameDocument with empty string sets null', () {
        final controller = MarkdrawController();
        addTearDown(controller.dispose);

        controller.renameDocument('Something');
        controller.renameDocument('');
        expect(controller.documentName, isNull);
      });

      test('serializeScene includes @name in output', () {
        final controller = MarkdrawController();
        addTearDown(controller.dispose);

        controller.renameDocument('Test Doc');
        final output = controller.serializeScene();
        expect(output, contains('@name "Test Doc"'));
      });

      test('loadFromContent extracts name from @name directive', () {
        const content = '```markdraw\n@name "Loaded Doc"\n```';
        final controller = MarkdrawController();
        addTearDown(controller.dispose);

        controller.loadFromContent(content, 'test.markdraw');
        expect(controller.documentName, 'Loaded Doc');
      });

      test('resetCanvas clears name', () {
        final controller = MarkdrawController();
        addTearDown(controller.dispose);

        controller.renameDocument('Will Be Cleared');
        expect(controller.documentName, 'Will Be Cleared');
        controller.resetCanvas();
        expect(controller.documentName, isNull);
      });
    });
  });
}
