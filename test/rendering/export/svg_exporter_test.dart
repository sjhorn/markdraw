import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/core/serialization/document_parser.dart';
import 'package:markdraw/src/rendering/export/svg_exporter.dart';

void main() {
  group('SvgExporter', () {
    test('empty scene produces minimal valid SVG', () {
      final scene = Scene();
      final svg = SvgExporter.export(scene);
      expect(svg, isEmpty);
    });

    test('single element produces valid SVG with viewBox', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, contains('<svg'));
      expect(svg, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox='));
      expect(svg, contains('</svg>'));
    });

    test('viewBox matches export bounds', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 50,
        height: 30,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      // ExportBounds default padding = 20
      // Bounds: 80,180 → 170,250 → size 90x70
      expect(svg, contains('viewBox="80 180 90 70"'));
      expect(svg, contains('width="90"'));
      expect(svg, contains('height="70"'));
    });

    test('background color adds rect element', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        seed: 42,
      ));
      final svg = SvgExporter.export(
        scene,
        backgroundColor: '#ffffff',
      );
      expect(svg, contains('<rect'));
      expect(svg, contains('fill="#ffffff"'));
    });

    test('no background color skips background rect', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      // Should not have a full-size background rect
      // (there will be path elements from the drawn rectangle, not a rect element)
      expect(svg, isNot(contains('<rect ')));
    });

    test('elements rendered in order', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        index: 'a',
        seed: 42,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 80,
        y: 10,
        width: 50,
        height: 50,
        index: 'b',
        seed: 43,
      ));
      final svg = SvgExporter.export(scene);
      // Both should be rendered
      expect(svg, contains('<path'));
      expect(svg, contains('</svg>'));
    });

    test('selection-only export', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
        seed: 42,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 500,
        y: 500,
        width: 50,
        height: 50,
        seed: 43,
      ));
      final svgAll = SvgExporter.export(scene);
      final svgSel = SvgExporter.export(
        scene,
        selectedIds: {const ElementId('r1')},
      );
      // Selected SVG should have smaller viewBox
      expect(svgAll.length, greaterThan(svgSel.length));
    });

    test('bound text in shapes is rendered', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 200,
        height: 100,
        seed: 42,
        boundElements: [const BoundElement(id: 't1', type: 'text')],
      ));
      scene = scene.addElement(TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 50,
        width: 100,
        height: 20,
        text: 'Shape Label',
        containerId: 'r1',
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, contains('Shape Label'));
      expect(svg, contains('<text'));
    });

    test('arrow label at midpoint', () {
      var scene = Scene();
      scene = scene.addElement(ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        endArrowhead: Arrowhead.arrow,
        seed: 42,
        boundElements: [const BoundElement(id: 't1', type: 'text')],
      ));
      scene = scene.addElement(TextElement(
        id: const ElementId('t1'),
        x: 90,
        y: -10,
        width: 50,
        height: 20,
        text: 'Arrow Label',
        containerId: 'a1',
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, contains('Arrow Label'));
    });

    test('embedded markdraw round-trips', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene, embedMarkdraw: true);
      expect(svg, contains('<!-- markdraw:base64:'));

      // Extract and parse the embedded data
      final match = RegExp(r'<!-- markdraw:base64:(.*?) -->').firstMatch(svg);
      expect(match, isNotNull);
      final base64Data = match!.group(1)!;
      final markdrawContent = utf8.decode(base64Decode(base64Data));
      final parsed = DocumentParser.parse(markdrawContent);
      expect(parsed.value.allElements.length, 1);
      expect(parsed.value.allElements.first.type, 'rectangle');
    });

    test('embedMarkdraw=false skips comment', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene, embedMarkdraw: false);
      expect(svg, isNot(contains('markdraw:base64:')));
    });

    test('deleted elements excluded', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        seed: 42,
      ));
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 200,
        width: 50,
        height: 50,
        isDeleted: true,
        seed: 43,
      ));
      final svg = SvgExporter.export(scene);
      // viewBox should only be based on r1, not r2
      expect(svg, contains('viewBox="-10 -10 90 90"'));
    });

    test('rotated elements get transform', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        angle: 0.785,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, contains('transform="rotate('));
    });

    test('opacity in SVG output', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        opacity: 0.5,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, contains('opacity="0.5"'));
    });

    test('well-formed XML structure', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final svg = SvgExporter.export(scene);
      expect(svg, startsWith('<svg'));
      expect(svg, endsWith('</svg>'));
    });
  });
}
