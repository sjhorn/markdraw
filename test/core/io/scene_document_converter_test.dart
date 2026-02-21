import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/io/scene_document_converter.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

void main() {
  group('SceneDocumentConverter', () {
    test('empty scene produces document with empty sketch section', () {
      final scene = Scene();
      final doc = SceneDocumentConverter.sceneToDocument(scene);

      expect(doc.sections, hasLength(1));
      expect(doc.sections.first, isA<SketchSection>());
      expect((doc.sections.first as SketchSection).elements, isEmpty);
    });

    test('scene with elements produces document with those elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final text = TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 60,
        width: 80,
        height: 20,
        text: 'Hello',
      );
      final scene = Scene().addElement(rect).addElement(text);
      final doc = SceneDocumentConverter.sceneToDocument(scene);

      final sketch = doc.sections.first as SketchSection;
      expect(sketch.elements, hasLength(2));
      expect(sketch.elements[0].id, const ElementId('r1'));
      expect(sketch.elements[1].id, const ElementId('t1'));
    });

    test('document with elements produces scene containing those elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final doc = MarkdrawDocument(
        sections: [SketchSection([rect])],
      );
      final scene = SceneDocumentConverter.documentToScene(doc);

      expect(scene.activeElements, hasLength(1));
      expect(scene.activeElements.first.id, const ElementId('r1'));
    });

    test('round-trip preserves all elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final text = TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 60,
        width: 80,
        height: 20,
        text: 'Hello',
      );
      final original = Scene().addElement(rect).addElement(text);

      final doc = SceneDocumentConverter.sceneToDocument(original);
      final restored = SceneDocumentConverter.documentToScene(doc);

      expect(restored.activeElements, hasLength(2));
      expect(
        restored.activeElements.map((e) => e.id),
        original.activeElements.map((e) => e.id),
      );
    });

    test('only active elements included in document', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final deleted = RectangleElement(
        id: const ElementId('r2'),
        x: 30,
        y: 40,
        width: 60,
        height: 30,
      );
      final scene = Scene()
          .addElement(rect)
          .addElement(deleted)
          .softDeleteElement(const ElementId('r2'));
      final doc = SceneDocumentConverter.sceneToDocument(scene);

      final sketch = doc.sections.first as SketchSection;
      expect(sketch.elements, hasLength(1));
      expect(sketch.elements.first.id, const ElementId('r1'));
    });
  });
}
