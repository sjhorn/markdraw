import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

void main() {
  group('Excalidraw round-trip', () {
    MarkdrawDocument _makeDoc(List<Element> elements) {
      return MarkdrawDocument(sections: [SketchSection(elements)]);
    }

    test('simple shapes round-trip', () {
      final doc = _makeDoc([
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          seed: 42,
        ),
        EllipseElement(
          id: const ElementId('e1'),
          x: 200,
          y: 30,
          width: 60,
          height: 60,
          seed: 43,
        ),
        DiamondElement(
          id: const ElementId('d1'),
          x: 300,
          y: 50,
          width: 80,
          height: 80,
          seed: 44,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 3);
      expect(parsed.value.allElements[0].type, 'rectangle');
      expect(parsed.value.allElements[1].type, 'ellipse');
      expect(parsed.value.allElements[2].type, 'diamond');
      expect(parsed.value.allElements[0].x, 10);
      expect(parsed.value.allElements[0].y, 20);
      expect(parsed.value.allElements[0].width, 100);
      expect(parsed.value.allElements[0].height, 80);
    });

    test('text round-trip', () {
      final doc = _makeDoc([
        TextElement(
          id: const ElementId('t1'),
          x: 50,
          y: 100,
          width: 200,
          height: 24,
          text: 'Hello World',
          fontSize: 28,
          fontFamily: 'Helvetica',
          textAlign: TextAlign.center,
          seed: 42,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 1);
      final text = parsed.value.allElements[0] as TextElement;
      expect(text.text, 'Hello World');
      expect(text.fontSize, 28);
      expect(text.fontFamily, 'Helvetica');
      expect(text.textAlign, TextAlign.center);
    });

    test('arrow with bindings round-trip', () {
      final doc = _makeDoc([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 80,
          seed: 42,
          boundElements: [const BoundElement(id: 'a1', type: 'arrow')],
        ),
        RectangleElement(
          id: const ElementId('r2'),
          x: 300,
          y: 0,
          width: 100,
          height: 80,
          seed: 43,
          boundElements: [const BoundElement(id: 'a1', type: 'arrow')],
        ),
        ArrowElement(
          id: const ElementId('a1'),
          x: 100,
          y: 40,
          width: 200,
          height: 0,
          points: [const Point(0, 0), const Point(200, 0)],
          endArrowhead: Arrowhead.arrow,
          startBinding: const PointBinding(
            elementId: 'r1',
            fixedPoint: Point(1.0, 0.5),
          ),
          endBinding: const PointBinding(
            elementId: 'r2',
            fixedPoint: Point(0.0, 0.5),
          ),
          seed: 44,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 3);
      final arrow = parsed.value.allElements[2] as ArrowElement;
      expect(arrow.startBinding, isNotNull);
      expect(arrow.startBinding!.elementId, 'r1');
      expect(arrow.endBinding, isNotNull);
      expect(arrow.endBinding!.elementId, 'r2');
      expect(arrow.endArrowhead, Arrowhead.arrow);
    });

    test('line with points round-trip', () {
      final doc = _makeDoc([
        LineElement(
          id: const ElementId('l1'),
          x: 10,
          y: 20,
          width: 200,
          height: 100,
          points: [
            const Point(0, 0),
            const Point(100, 50),
            const Point(200, 100),
          ],
          seed: 42,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 1);
      final line = parsed.value.allElements[0] as LineElement;
      expect(line.points.length, 3);
      expect(line.points[0], const Point(0, 0));
      expect(line.points[1], const Point(100, 50));
      expect(line.points[2], const Point(200, 100));
    });

    test('freedraw round-trip', () {
      final doc = _makeDoc([
        FreedrawElement(
          id: const ElementId('f1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          points: [
            const Point(0, 0),
            const Point(30, 20),
            const Point(60, 10),
            const Point(100, 50),
          ],
          pressures: [0.5, 0.7, 0.8, 0.6],
          simulatePressure: true,
          seed: 42,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 1);
      final freedraw = parsed.value.allElements[0] as FreedrawElement;
      expect(freedraw.points.length, 4);
      expect(freedraw.pressures.length, 4);
      expect(freedraw.simulatePressure, isTrue);
    });

    test('mixed scene with all 7 types', () {
      final doc = _makeDoc([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 80,
          seed: 42,
        ),
        EllipseElement(
          id: const ElementId('e1'),
          x: 150,
          y: 0,
          width: 80,
          height: 80,
          seed: 43,
        ),
        DiamondElement(
          id: const ElementId('d1'),
          x: 300,
          y: 0,
          width: 80,
          height: 80,
          seed: 44,
        ),
        TextElement(
          id: const ElementId('t1'),
          x: 0,
          y: 150,
          width: 100,
          height: 24,
          text: 'Label',
          seed: 45,
        ),
        LineElement(
          id: const ElementId('l1'),
          x: 150,
          y: 150,
          width: 100,
          height: 0,
          points: [const Point(0, 0), const Point(100, 0)],
          seed: 46,
        ),
        ArrowElement(
          id: const ElementId('a1'),
          x: 300,
          y: 150,
          width: 100,
          height: 0,
          points: [const Point(0, 0), const Point(100, 0)],
          endArrowhead: Arrowhead.arrow,
          seed: 47,
        ),
        FreedrawElement(
          id: const ElementId('f1'),
          x: 0,
          y: 300,
          width: 100,
          height: 50,
          points: [const Point(0, 0), const Point(50, 25), const Point(100, 50)],
          seed: 48,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 7);
      final types = parsed.value.allElements.map((e) => e.type).toSet();
      expect(types, containsAll([
        'rectangle',
        'ellipse',
        'diamond',
        'text',
        'line',
        'arrow',
        'freedraw',
      ]));
    });

    test('non-default styles preserved', () {
      final doc = _makeDoc([
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 20,
          width: 100,
          height: 80,
          strokeColor: '#ff0000',
          backgroundColor: '#00ff00',
          fillStyle: FillStyle.crossHatch,
          strokeWidth: 4.0,
          strokeStyle: StrokeStyle.dashed,
          roughness: 2.5,
          opacity: 0.7,
          seed: 42,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      final el = parsed.value.allElements[0];
      expect(el.strokeColor, '#ff0000');
      expect(el.backgroundColor, '#00ff00');
      expect(el.fillStyle, FillStyle.crossHatch);
      expect(el.strokeWidth, 4.0);
      expect(el.strokeStyle, StrokeStyle.dashed);
      expect(el.roughness, 2.5);
      expect(el.opacity, closeTo(0.7, 0.01));
    });

    test('bound text containerId preserved', () {
      final doc = _makeDoc([
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
          y: 30,
          width: 80,
          height: 20,
          text: 'Inside',
          containerId: 'r1',
          seed: 43,
        ),
      ]);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 2);
      final textEl = parsed.value.allElements
          .whereType<TextElement>()
          .first;
      expect(textEl.containerId, 'r1');
      expect(textEl.text, 'Inside');
    });

    test('warnings for lossy conversions', () {
      // Create JSON with a lossy arrowhead type
      const jsonStr = '{"type":"excalidraw","version":2,"elements":[{'
          '"id":"a1","type":"arrow","x":0,"y":0,"width":100,"height":0,'
          '"points":[[0,0],[100,0]],"endArrowhead":"circle_outline",'
          '"angle":0,"strokeColor":"#000000","backgroundColor":"transparent",'
          '"fillStyle":"solid","strokeWidth":2,"strokeStyle":"solid",'
          '"roughness":1,"opacity":100,"seed":42,"version":1,'
          '"versionNonce":1,"isDeleted":false,"groupIds":[]'
          '}]}';

      final parsed = ExcalidrawJsonCodec.parse(jsonStr);
      expect(parsed.warnings, isNotEmpty);
      expect(
        parsed.warnings.any((w) => w.message.contains('circle_outline')),
        isTrue,
      );
    });

    test('large scene with 50+ elements', () {
      final elements = List.generate(
        60,
        (i) => RectangleElement(
          id: ElementId('r$i'),
          x: (i % 10) * 120.0,
          y: (i ~/ 10) * 100.0,
          width: 100,
          height: 80,
          seed: 42 + i,
        ),
      );
      final doc = _makeDoc(elements);

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements.length, 60);
      for (var i = 0; i < 60; i++) {
        expect(parsed.value.allElements[i].type, 'rectangle');
        expect(parsed.value.allElements[i].x, (i % 10) * 120.0);
      }
    });
  });
}
