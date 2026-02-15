import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/serialization/sketch_line_parser.dart';

void main() {
  late SketchLineParser parser;

  setUp(() {
    parser = SketchLineParser();
  });

  group('Rectangle parsing', () {
    test('basic rectangle', () {
      final result = parser.parseLine('rect id=auth at 100,200 size 160x80 seed=42', 1);
      expect(result.value, isNotNull);
      final elem = result.value!;
      expect(elem, isA<RectangleElement>());
      expect(elem.x, 100);
      expect(elem.y, 200);
      expect(elem.width, 160);
      expect(elem.height, 80);
      expect(elem.seed, 42);
      expect(result.warnings, isEmpty);
    });

    test('rectangle with fill and rounded', () {
      final result = parser.parseLine(
        'rect id=auth at 100,200 size 160x80 fill=#e3f2fd rounded=8 seed=42',
        1,
      );
      final elem = result.value! as RectangleElement;
      expect(elem.backgroundColor, '#e3f2fd');
      expect(elem.roundness, isNotNull);
      expect(elem.roundness!.value, 8);
    });

    test('rectangle with all properties', () {
      final result = parser.parseLine(
        'rect id=r at 10,20 size 50x60 fill=#00ff00 color=#ff0000 stroke=dotted fill-style=hachure stroke-width=3 roughness=2 opacity=0.5 angle=1.5 locked seed=99',
        1,
      );
      final elem = result.value!;
      expect(elem.x, 10);
      expect(elem.y, 20);
      expect(elem.width, 50);
      expect(elem.height, 60);
      expect(elem.backgroundColor, '#00ff00');
      expect(elem.strokeColor, '#ff0000');
      expect(elem.strokeStyle, StrokeStyle.dotted);
      expect(elem.fillStyle, FillStyle.hachure);
      expect(elem.strokeWidth, 3);
      expect(elem.roughness, 2);
      expect(elem.opacity, 0.5);
      expect(elem.angle, 1.5);
      expect(elem.locked, isTrue);
      expect(elem.seed, 99);
    });

    test('cross-hatch fill style parses', () {
      final result = parser.parseLine(
        'rect at 0,0 size 100x100 fill-style=cross-hatch seed=1',
        1,
      );
      expect(result.value!.fillStyle, FillStyle.crossHatch);
    });
  });

  group('Ellipse parsing', () {
    test('basic ellipse', () {
      final result = parser.parseLine(
        'ellipse id=db at 225,400 size 120x80 seed=7',
        1,
      );
      expect(result.value, isA<EllipseElement>());
      expect(result.value!.x, 225);
      expect(result.value!.y, 400);
    });

    test('ellipse with fill', () {
      final result = parser.parseLine(
        'ellipse id=db at 225,400 size 120x80 fill=#e8f5e9 seed=7',
        1,
      );
      expect(result.value!.backgroundColor, '#e8f5e9');
    });
  });

  group('Diamond parsing', () {
    test('basic diamond', () {
      final result = parser.parseLine(
        'diamond at 50,50 size 100x100 seed=3',
        1,
      );
      expect(result.value, isA<DiamondElement>());
      expect(result.value!.x, 50);
      expect(result.value!.y, 50);
    });
  });

  group('Text parsing', () {
    test('basic text', () {
      final result = parser.parseLine(
        'text "High Priority" at 100,50 seed=5',
        1,
      );
      expect(result.value, isA<TextElement>());
      final text = result.value! as TextElement;
      expect(text.text, 'High Priority');
      expect(text.x, 100);
      expect(text.y, 50);
    });

    test('text with font size', () {
      final result = parser.parseLine(
        'text "Big" at 0,0 size=36 seed=5',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.fontSize, 36);
    });

    test('text with font family', () {
      final result = parser.parseLine(
        'text "Custom" at 0,0 font=Cascadia seed=5',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Cascadia');
    });

    test('text with alignment', () {
      final result = parser.parseLine(
        'text "Centered" at 0,0 align=center seed=5',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.textAlign, TextAlign.center);
    });

    test('text with color', () {
      final result = parser.parseLine(
        'text "Red" at 100,50 color=#d32f2f seed=5',
        1,
      );
      expect(result.value!.strokeColor, '#d32f2f');
    });

    test('text defaults to Virgil font and 20 size', () {
      final result = parser.parseLine('text "Hello" at 0,0 seed=1', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 20);
      expect(text.fontFamily, 'Virgil');
      expect(text.textAlign, TextAlign.left);
    });
  });

  group('Line parsing', () {
    test('basic line', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,0],[100,100]] seed=10',
        1,
      );
      expect(result.value, isA<LineElement>());
      final line = result.value! as LineElement;
      expect(line.points, hasLength(3));
      expect(line.points[0], Point(0, 0));
      expect(line.points[1], Point(100, 0));
      expect(line.points[2], Point(100, 100));
    });

    test('line with arrowheads', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,0]] start-arrow=dot end-arrow=triangle seed=10',
        1,
      );
      final line = result.value! as LineElement;
      expect(line.startArrowhead, Arrowhead.dot);
      expect(line.endArrowhead, Arrowhead.triangle);
    });

    test('line with stroke style', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,100]] stroke=dotted seed=10',
        1,
      );
      expect(result.value!.strokeStyle, StrokeStyle.dotted);
    });
  });

  group('Arrow parsing', () {
    test('arrow with from/to bindings', () {
      final result = parser.parseLine(
        'arrow from auth to gateway seed=20',
        1,
      );
      expect(result.value, isA<ArrowElement>());
      final arrow = result.value! as ArrowElement;
      // Bindings are stored as deferred references
      expect(result.warnings, isEmpty);
    });

    test('arrow with points (no bindings)', () {
      final result = parser.parseLine(
        'arrow points=[[0,0],[200,0]] seed=20',
        1,
      );
      final arrow = result.value! as ArrowElement;
      expect(arrow.points, hasLength(2));
      expect(arrow.points[0], Point(0, 0));
      expect(arrow.points[1], Point(200, 0));
    });

    test('arrow with non-default arrowheads', () {
      final result = parser.parseLine(
        'arrow points=[[0,0],[200,0]] start-arrow=bar end-arrow=dot seed=20',
        1,
      );
      final arrow = result.value! as ArrowElement;
      expect(arrow.startArrowhead, Arrowhead.bar);
      expect(arrow.endArrowhead, Arrowhead.dot);
    });

    test('arrow default endArrowhead is arrow', () {
      final result = parser.parseLine(
        'arrow points=[[0,0],[200,0]] seed=20',
        1,
      );
      final arrow = result.value! as ArrowElement;
      expect(arrow.endArrowhead, Arrowhead.arrow);
    });

    test('arrow with stroke style', () {
      final result = parser.parseLine(
        'arrow from auth to gateway stroke=dashed seed=20',
        1,
      );
      expect(result.value!.strokeStyle, StrokeStyle.dashed);
    });

    test('arrow from/to stored as binding aliases', () {
      final result = parser.parseLine(
        'arrow from auth to gateway seed=20',
        1,
      );
      expect(parser.pendingBindings, isNotEmpty);
    });
  });

  group('Freedraw parsing', () {
    test('basic freedraw', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0],[5,2],[10,8]] seed=30',
        1,
      );
      expect(result.value, isA<FreedrawElement>());
      final fd = result.value! as FreedrawElement;
      expect(fd.points, hasLength(3));
      expect(fd.points[0], Point(0, 0));
      expect(fd.points[1], Point(5, 2));
      expect(fd.points[2], Point(10, 8));
    });

    test('freedraw with pressure', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0],[5,2],[10,8]] pressure=[0.5,0.7,0.9] seed=30',
        1,
      );
      final fd = result.value! as FreedrawElement;
      expect(fd.pressures, [0.5, 0.7, 0.9]);
    });

    test('freedraw with simulate-pressure', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0]] simulate-pressure seed=30',
        1,
      );
      final fd = result.value! as FreedrawElement;
      expect(fd.simulatePressure, isTrue);
    });

    test('freedraw with color', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0]] color=#1e1e1e seed=30',
        1,
      );
      expect(result.value!.strokeColor, '#1e1e1e');
    });
  });

  group('Alias registration', () {
    test('id= registers alias', () {
      parser.parseLine('rect id=auth at 100,200 size 160x80 seed=1', 1);
      expect(parser.aliases, containsPair('auth', isNotNull));
    });

    test('element without id does not register alias', () {
      parser.parseLine('rect at 100,200 size 160x80 seed=1', 1);
      expect(parser.aliases, isEmpty);
    });
  });

  group('Lenient parsing', () {
    test('empty line returns null value', () {
      final result = parser.parseLine('', 1);
      expect(result.value, isNull);
      expect(result.warnings, isEmpty);
    });

    test('comment line returns null value', () {
      final result = parser.parseLine('# this is a comment', 1);
      expect(result.value, isNull);
      expect(result.warnings, isEmpty);
    });

    test('unknown keyword returns null with warning', () {
      final result = parser.parseLine('polygon at 0,0 size 100x100', 1);
      expect(result.value, isNull);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, contains('Unknown keyword'));
    });

    test('whitespace-only line returns null', () {
      final result = parser.parseLine('   ', 1);
      expect(result.value, isNull);
      expect(result.warnings, isEmpty);
    });
  });

  group('Number parsing', () {
    test('decimal positions parsed correctly', () {
      final result = parser.parseLine(
        'rect at 100.5,200.25 size 160x80 seed=1',
        1,
      );
      expect(result.value!.x, 100.5);
      expect(result.value!.y, 200.25);
    });
  });
}
