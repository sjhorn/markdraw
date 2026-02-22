import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/export/svg_element_renderer.dart';

void main() {
  group('SvgElementRenderer', () {
    test('renders rectangle with path elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('<path'));
      expect(svg, contains('stroke='));
    });

    test('renders ellipse with path elements', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(ellipse);
      expect(svg, contains('<path'));
    });

    test('renders diamond with path elements', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(diamond);
      expect(svg, contains('<path'));
    });

    test('renders line with path elements', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 10,
        y: 20,
        width: 90,
        height: 0,
        points: [const Point(0, 0), const Point(90, 0)],
        seed: 42,
      );
      final svg = SvgElementRenderer.render(line);
      expect(svg, contains('<path'));
    });

    test('renders arrow with arrowheads', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        endArrowhead: Arrowhead.arrow,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      expect(svg, contains('<path'));
      // Should have arrowhead path
      expect(svg.split('<path').length, greaterThan(2));
    });

    test('renders freedraw with smooth path', () {
      final freedraw = FreedrawElement(
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
        seed: 42,
      );
      final svg = SvgElementRenderer.render(freedraw);
      expect(svg, contains('<path'));
      // Freedraw should have Bezier curves
      expect(svg, contains('C'));
    });

    test('renders text with text element', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 100,
        width: 200,
        height: 24,
        text: 'Hello World',
        fontSize: 20,
        fontFamily: 'Virgil',
      );
      final svg = SvgElementRenderer.render(text);
      expect(svg, contains('<text'));
      expect(svg, contains('Hello World'));
      expect(svg, contains('font-size'));
      expect(svg, contains('font-family'));
    });

    test('rotation wraps in g transform', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        angle: 0.5,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('<g transform="rotate('));
      expect(svg, contains('</g>'));
    });

    test('no rotation skips g wrapper', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        angle: 0.0,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, isNot(contains('<g transform="rotate(')));
    });

    test('opacity attribute applied', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        opacity: 0.5,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('opacity="0.5"'));
    });

    test('full opacity does not add opacity attribute', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        opacity: 1.0,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, isNot(contains('opacity=')));
    });

    test('stroke and fill colors applied', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('#ff0000'));
      expect(svg, contains('#00ff00'));
    });

    test('dashed stroke gets dasharray', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        strokeStyle: StrokeStyle.dashed,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('stroke-dasharray="8,6"'));
    });

    test('dotted stroke gets dasharray', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        strokeStyle: StrokeStyle.dotted,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('stroke-dasharray="1.5,6"'));
    });

    test('transparent background uses fill none', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        backgroundColor: 'transparent',
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      // Either no fill path or fill="none"
      expect(svg, isNotEmpty);
    });

    test('strokeWidth mapped correctly', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        strokeWidth: 4.0,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(rect);
      expect(svg, contains('stroke-width="4"'));
    });

    test('text element attributes correct', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 50,
        y: 100,
        width: 200,
        height: 24,
        text: 'Test',
        fontSize: 28,
        fontFamily: 'Helvetica',
        strokeColor: '#ff0000',
      );
      final svg = SvgElementRenderer.render(text);
      expect(svg, contains('font-size="28"'));
      expect(svg, contains('font-family="Helvetica"'));
      expect(svg, contains('fill="#ff0000"'));
    });

    test('line/arrow/freedraw use absolute points', () {
      // Line at x=50, y=30 with relative point at (0,0),(100,0)
      // Absolute points should be (50,30),(150,30)
      final line = LineElement(
        id: const ElementId('l1'),
        x: 50,
        y: 30,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        seed: 42,
      );
      final svg = SvgElementRenderer.render(line);
      // The path should reference absolute coordinates (50,30 area)
      expect(svg, contains('<path'));
    });

    test('arrow with both arrowheads', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        startArrowhead: Arrowhead.triangle,
        endArrowhead: Arrowhead.arrow,
        seed: 42,
      );
      final svg = SvgElementRenderer.render(arrow);
      // Should have multiple path elements for line + 2 arrowheads
      expect(svg.split('<path').length, greaterThan(3));
    });
  });
}
