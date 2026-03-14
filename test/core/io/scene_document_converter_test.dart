import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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
        sections: [
          SketchSection([rect]),
        ],
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

    test('auto-generates type-based aliases for all elements', () {
      final rect1 = RectangleElement(
        id: const ElementId('uuid-1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );
      final rect2 = RectangleElement(
        id: const ElementId('uuid-2'),
        x: 200,
        y: 0,
        width: 100,
        height: 50,
      );
      final ellipse = EllipseElement(
        id: const ElementId('uuid-3'),
        x: 0,
        y: 100,
        width: 80,
        height: 80,
      );
      final arrow = ArrowElement(
        id: const ElementId('uuid-4'),
        x: 0,
        y: 200,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
      );
      final text = TextElement(
        id: const ElementId('uuid-5'),
        x: 0,
        y: 300,
        width: 80,
        height: 20,
        text: 'Hello',
      );
      final diamond = DiamondElement(
        id: const ElementId('uuid-6'),
        x: 0,
        y: 400,
        width: 60,
        height: 60,
      );
      final line = LineElement(
        id: const ElementId('uuid-7'),
        x: 0,
        y: 500,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
      );
      final freedraw = FreedrawElement(
        id: const ElementId('uuid-8'),
        x: 0,
        y: 600,
        width: 50,
        height: 50,
        points: [const Point(0, 0), const Point(50, 50)],
      );

      final scene = Scene()
          .addElement(rect1)
          .addElement(rect2)
          .addElement(ellipse)
          .addElement(arrow)
          .addElement(text)
          .addElement(diamond)
          .addElement(line)
          .addElement(freedraw);

      final doc = SceneDocumentConverter.sceneToDocument(scene);

      expect(doc.aliases['rect1'], 'uuid-1');
      expect(doc.aliases['rect2'], 'uuid-2');
      expect(doc.aliases['ellipse1'], 'uuid-3');
      expect(doc.aliases['arrow1'], 'uuid-4');
      expect(doc.aliases['text1'], 'uuid-5');
      expect(doc.aliases['diamond1'], 'uuid-6');
      expect(doc.aliases['line1'], 'uuid-7');
      expect(doc.aliases['freedraw1'], 'uuid-8');
    });

    test('auto-aliases produce human-readable serialization', () {
      final rect = RectangleElement(
        id: const ElementId('550e8400-e29b-41d4-a716-446655440000'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
      );
      final scene = Scene().addElement(rect);
      final doc = SceneDocumentConverter.sceneToDocument(scene);
      final output = DocumentSerializer.serialize(doc);

      expect(output, contains('id=rect1'));
      expect(output, isNot(contains('550e8400')));
      expect(output, isNot(contains('eid=')));
    });

    test('bound arrows get endpoints computed from targets', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 100,
        height: 50,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 400,
        y: 200,
        width: 100,
        height: 50,
      );
      // Arrow with placeholder points and bindings
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        points: [const Point(0, 0), const Point(0, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5), // right-center
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5), // left-center
        ),
      );

      final doc = MarkdrawDocument(
        sections: [
          SketchSection([rect1, rect2, arrow]),
        ],
      );
      final scene = SceneDocumentConverter.documentToScene(doc);

      final loadedArrow =
          scene.getElementById(const ElementId('a1'))! as ArrowElement;
      // Arrow should span from right-center of rect1 (200, 125)
      // to left-center of rect2 (400, 225)
      expect(loadedArrow.x, 200);
      expect(loadedArrow.y, 125);
      expect(loadedArrow.width, 200);
      expect(loadedArrow.height, 100);
    });

    test(
      'bound arrows preserve non-default fixedPoints through full round-trip',
      () {
        final rect1 = RectangleElement(
          id: const ElementId('uuid-r1'),
          x: 100,
          y: 100,
          width: 200,
          height: 100,
        );
        final rect2 = RectangleElement(
          id: const ElementId('uuid-r2'),
          x: 500,
          y: 300,
          width: 200,
          height: 100,
        );
        final arrow = ArrowElement(
          id: const ElementId('uuid-a1'),
          x: 0,
          y: 0,
          width: 0,
          height: 0,
          points: [const Point(0, 0), const Point(0, 0)],
          startBinding: const PointBinding(
            elementId: 'uuid-r1',
            fixedPoint: Point(0.5, 1), // bottom-center
          ),
          endBinding: const PointBinding(
            elementId: 'uuid-r2',
            fixedPoint: Point(0.5, 0), // top-center
          ),
        );

        // Scene → Document → serialize → parse → Scene
        final scene = Scene()
            .addElement(rect1)
            .addElement(rect2)
            .addElement(arrow);
        final doc = SceneDocumentConverter.sceneToDocument(scene);
        final output = DocumentSerializer.serialize(doc);

        // Verify pixel @x,y syntax is emitted (200*0.5=100, 100*1=100, 100*0=0)
        expect(output, contains('@100,100'));
        expect(output, contains('@100,0'));

        final parsed = DocumentParser.parse(output);
        final restoredScene = SceneDocumentConverter.documentToScene(
          parsed.value,
        );
        final loadedArrow = restoredScene.activeElements
            .whereType<ArrowElement>()
            .first;

        // fixedPoints must survive the full round-trip
        expect(loadedArrow.startBinding!.fixedPoint.x, 0.5);
        expect(loadedArrow.startBinding!.fixedPoint.y, 1.0);
        expect(loadedArrow.endBinding!.fixedPoint.x, 0.5);
        expect(loadedArrow.endBinding!.fixedPoint.y, 0.0);

        // Endpoints should be computed from targets:
        // bottom-center of rect1 (100+200*0.5, 100+100*1) = (200, 200)
        // top-center of rect2 (500+200*0.5, 300+100*0) = (600, 300)
        expect(loadedArrow.x, 200);
        expect(loadedArrow.y, 200);
        expect(loadedArrow.width, 400);
        expect(loadedArrow.height, 100);
      },
    );

    test(
      'bound text with non-default properties round-trips through full pipeline',
      () {
        final rect = RectangleElement(
          id: const ElementId('uuid-rect'),
          x: 100,
          y: 200,
          width: 160,
          height: 80,
          seed: 42,
        );
        final label = TextElement(
          id: const ElementId('uuid-text'),
          x: 100,
          y: 200,
          width: 160,
          height: 20,
          text: 'My Label',
          fontSize: 28,
          fontFamily: 'Nunito',
          textAlign: TextAlign.right,
          verticalAlign: VerticalAlign.bottom,
          containerId: 'uuid-rect',
          seed: 43,
        );

        // Scene → Document → serialize → parse → Scene
        final scene = Scene().addElement(rect).addElement(label);
        final doc = SceneDocumentConverter.sceneToDocument(scene);
        final serialized = DocumentSerializer.serialize(doc);
        final parsed = DocumentParser.parse(serialized);
        final restored = SceneDocumentConverter.documentToScene(parsed.value);

        final restoredTexts = restored.activeElements
            .whereType<TextElement>()
            .toList();
        expect(restoredTexts, hasLength(1));
        expect(restoredTexts.first.text, 'My Label');
        expect(restoredTexts.first.fontSize, 28);
        expect(restoredTexts.first.fontFamily, 'Nunito');
        expect(restoredTexts.first.textAlign, TextAlign.right);
        expect(restoredTexts.first.verticalAlign, VerticalAlign.bottom);
        expect(restoredTexts.first.containerId, isNotNull);
      },
    );

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
