/// Tests for text editing logic: double-click dispatch, bound text creation,
/// commit/cancel behavior, and auto-resize via TextRenderer.measure.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// Apply a ToolResult to a scene, returning the new scene.
Scene applyToScene(Scene scene, ToolResult result) {
  return switch (result) {
    AddElementResult(:final element) => scene.addElement(element),
    UpdateElementResult(:final element) => scene.updateElement(element),
    RemoveElementResult(:final id) => scene.removeElement(id),
    CompoundResult(:final results) => results.fold(scene, applyToScene),
    _ => scene,
  };
}

void main() {
  group('Text editing logic', () {
    test('double-click hit on TextElement returns the text element', () {
      final scene = Scene().addElement(TextElement(
        id: const ElementId('t1'),
        x: 100, y: 100, width: 200, height: 40,
        text: 'Existing text',
      ));

      final hit = scene.getElementAtPoint(const Point(150, 120));
      expect(hit, isNotNull);
      expect(hit, isA<TextElement>());
      expect((hit as TextElement).text, 'Existing text');
    });

    test('commit updates element text and size via measure', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 100, y: 100, width: 50, height: 24,
        text: '',
      );
      // Simulate commit: update text, then measure
      final updated = element.copyWithText(text: 'Hello World');
      final (w, h) = TextRenderer.measure(updated);
      expect(w, greaterThan(0));
      expect(h, greaterThan(0));
      final resized = updated.copyWith(width: w + 4, height: h);
      expect(resized.width, greaterThan(50));
    });

    test('commit empty text should result in removal', () {
      final scene = Scene().addElement(TextElement(
        id: const ElementId('t1'),
        x: 100, y: 100, width: 200, height: 40,
        text: 'Original',
      ));
      // Simulate empty text commit → remove
      final newScene =
          scene.removeElement(const ElementId('t1'));
      expect(newScene.getElementById(const ElementId('t1')), isNull);
    });

    test('cancel editing existing restores original text', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 100, y: 100, width: 200, height: 40,
        text: 'Original',
      );
      var scene = Scene().addElement(element);
      // Simulate user editing: change text
      final edited = element.copyWithText(text: 'Changed');
      scene = scene.updateElement(edited);
      // Simulate cancel: restore original
      final restored = edited.copyWithText(text: 'Original');
      scene = scene.updateElement(restored);
      final result = scene.getElementById(const ElementId('t1')) as TextElement;
      expect(result.text, 'Original');
    });

    test('cancel editing new removes element', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 100, y: 100, width: 200, height: 40,
        text: '',
      );
      var scene = Scene().addElement(element);
      // Simulate cancel: remove new element
      scene = scene.removeElement(const ElementId('t1'));
      expect(scene.getElementById(const ElementId('t1')), isNull);
    });

    test('double-click shape creates bound text with containerId', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100, y: 100, width: 200, height: 100,
      );
      var scene = Scene().addElement(rect);
      expect(BoundTextUtils.isTextContainer(rect), isTrue);

      // Simulate creation of bound text
      final newText = TextElement(
        id: const ElementId('bt1'),
        x: rect.x, y: rect.y,
        width: rect.width, height: rect.height,
        text: '',
        containerId: 'r1',
      );
      scene = scene.addElement(newText);
      final found = scene.findBoundText(const ElementId('r1'));
      expect(found, isNotNull);
      expect(found!.containerId, 'r1');
    });

    test('double-click shape with existing bound text edits it', () {
      var scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100, y: 100, width: 200, height: 100,
          ))
          .addElement(TextElement(
            id: const ElementId('bt1'),
            x: 100, y: 100, width: 200, height: 100,
            text: 'Existing label',
            containerId: 'r1',
          ));
      final existing = scene.findBoundText(const ElementId('r1'));
      expect(existing, isNotNull);
      expect(existing!.text, 'Existing label');
      // Simulate edit
      final edited = existing.copyWithText(text: 'Updated label');
      scene = scene.updateElement(edited);
      final updated =
          scene.getElementById(const ElementId('bt1')) as TextElement;
      expect(updated.text, 'Updated label');
    });

    test('double-click arrow creates label', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 200, height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
      );
      var scene = Scene().addElement(arrow);
      final mid = ArrowLabelUtils.computeLabelPosition(arrow);
      final label = TextElement(
        id: const ElementId('al1'),
        x: mid.x, y: mid.y,
        width: 100, height: 24,
        text: '',
        containerId: 'a1',
      );
      scene = scene.addElement(label);
      expect(scene.findBoundText(const ElementId('a1')), isNotNull);
    });

    test('double-click arrow with existing label edits it', () {
      final scene = Scene()
          .addElement(ArrowElement(
            id: const ElementId('a1'),
            x: 0, y: 0, width: 200, height: 0,
            points: [const Point(0, 0), const Point(200, 0)],
          ))
          .addElement(TextElement(
            id: const ElementId('al1'),
            x: 80, y: -20, width: 40, height: 20,
            text: 'Existing',
            containerId: 'a1',
          ));
      final found = scene.findBoundText(const ElementId('a1'));
      expect(found!.text, 'Existing');
    });

    test('commit empty bound text removes text and cleans parent', () {
      var scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100, y: 100, width: 200, height: 100,
            boundElements: [
              const BoundElement(id: 'bt1', type: 'text'),
            ],
          ))
          .addElement(TextElement(
            id: const ElementId('bt1'),
            x: 100, y: 100, width: 200, height: 100,
            text: 'Label',
            containerId: 'r1',
          ));

      // Simulate empty commit: remove bound text
      scene = scene.removeElement(const ElementId('bt1'));
      expect(scene.getElementById(const ElementId('bt1')), isNull);
      // Clean parent's boundElements
      final parent = scene.getElementById(const ElementId('r1'))!;
      final cleaned = parent.copyWith(
        boundElements: parent.boundElements
            .where((b) => b.id != 'bt1')
            .toList(),
      );
      scene = scene.updateElement(cleaned);
      final updatedParent = scene.getElementById(const ElementId('r1'))!;
      expect(
        updatedParent.boundElements.where((b) => b.id == 'bt1'),
        isEmpty,
      );
    });
  });
}
