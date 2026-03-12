import 'package:flutter/widgets.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('MarkdrawController link methods', () {
    late MarkdrawController controller;

    setUp(() {
      controller = MarkdrawController();
    });

    tearDown(() {
      controller.dispose();
    });

    Scene sceneWith(List<Element> elements) {
      var scene = Scene();
      for (final e in elements) {
        scene = scene.addElement(e);
      }
      return scene;
    }

    test('setElementLink sets link on element', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );
      controller.loadScene(sceneWith([rect]));
      controller.applyResult(SetSelectionResult({rect.id}));

      controller.setElementLink(rect.id, 'https://example.com');

      final updated = controller.editorState.scene.getElementById(rect.id);
      expect(updated!.link, 'https://example.com');
    });

    test('setElementLink clears link when null', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        link: 'https://example.com',
      );
      controller.loadScene(sceneWith([rect]));

      controller.setElementLink(rect.id, null);

      final updated = controller.editorState.scene.getElementById(rect.id);
      expect(updated!.link, isNull);
    });

    test('setElementLink clears link when empty string', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        link: 'https://example.com',
      );
      controller.loadScene(sceneWith([rect]));

      controller.setElementLink(rect.id, '');

      final updated = controller.editorState.scene.getElementById(rect.id);
      expect(updated!.link, isNull);
    });

    test('followLink with element link (#id) selects target', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 500,
        y: 500,
        width: 100,
        height: 50,
      );
      controller.loadScene(sceneWith([rect1, rect2]));

      controller.followLink('#r2', const Size(800, 600));

      expect(controller.editorState.selectedIds, {const ElementId('r2')});
    });

    test('followLink with external URL calls onLinkOpen', () {
      String? openedUrl;
      final ctrl = MarkdrawController(
        config: MarkdrawEditorConfig(
          onLinkOpen: (url) => openedUrl = url,
        ),
      );

      ctrl.followLink('https://flutter.dev', const Size(800, 600));

      expect(openedUrl, 'https://flutter.dev');
      ctrl.dispose();
    });

    test('followLink with nonexistent element id does nothing', () {
      controller.loadScene(sceneWith([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
      ]));

      controller.followLink('#nonexistent', const Size(800, 600));

      expect(controller.editorState.selectedIds, isEmpty);
    });

    test('openLinkEditor sets editor state', () {
      expect(controller.isLinkEditorOpen, isFalse);
      expect(controller.isLinkEditorEditing, isFalse);

      controller.openLinkEditor();

      expect(controller.isLinkEditorOpen, isTrue);
      expect(controller.isLinkEditorEditing, isTrue);
    });

    test('closeLinkEditor resets all link state', () {
      controller.openLinkEditor();
      controller.enterLinkToElementMode();

      controller.closeLinkEditor();

      expect(controller.isLinkEditorOpen, isFalse);
      expect(controller.isLinkEditorEditing, isFalse);
      expect(controller.linkToElementMode, isFalse);
    });

    test('showLinkInfo sets info mode', () {
      controller.showLinkInfo();

      expect(controller.isLinkEditorOpen, isTrue);
      expect(controller.isLinkEditorEditing, isFalse);
    });

    test('hitTestLinkIcon returns element when clicking icon area', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 200,
        height: 100,
        link: 'https://example.com',
      );
      controller.loadScene(sceneWith([rect]));

      // Icon center at (x+width-8, y-18), radius 10
      final hit = controller.hitTestLinkIcon(const Point(292, 82));
      expect(hit, isNotNull);
      expect(hit!.id, const ElementId('r1'));
    });

    test('hitTestLinkIcon returns null for elements without link', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 200,
        height: 100,
      );
      controller.loadScene(sceneWith([rect]));

      final hit = controller.hitTestLinkIcon(const Point(292, 82));
      expect(hit, isNull);
    });

    test('hitTestLinkIcon skips selected elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 200,
        height: 100,
        link: 'https://example.com',
      );
      controller.loadScene(sceneWith([rect]));
      controller.applyResult(SetSelectionResult({rect.id}));

      final hit = controller.hitTestLinkIcon(const Point(292, 82));
      expect(hit, isNull);
    });

    test('enterLinkToElementMode sets flag', () {
      expect(controller.linkToElementMode, isFalse);

      controller.enterLinkToElementMode();

      expect(controller.linkToElementMode, isTrue);
    });
  });
}
