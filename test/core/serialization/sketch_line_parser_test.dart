import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  late SketchLineParser parser;

  setUp(() {
    parser = SketchLineParser();
  });

  group('Rectangle parsing', () {
    test('basic rectangle', () {
      final result = parser.parseLine('rect id=auth at 100,200 size 160x80', 1);
      expect(result.value, isNotNull);
      final elem = result.value!;
      expect(elem, isA<RectangleElement>());
      expect(elem.x, 100);
      expect(elem.y, 200);
      expect(elem.width, 160);
      expect(elem.height, 80);
      expect(result.warnings, isEmpty);
    });

    test('rectangle with fill and rounded', () {
      final result = parser.parseLine(
        'rect id=auth at 100,200 size 160x80 fill=#e3f2fd rounded=8',
        1,
      );
      final elem = result.value! as RectangleElement;
      expect(elem.backgroundColor, '#e3f2fd');
      expect(elem.roundness, isNotNull);
      expect(elem.roundness!.value, 8);
    });

    test('rectangle with all properties', () {
      final result = parser.parseLine(
        'rect id=r at 10,20 size 50x60 fill=#00ff00 color=#ff0000 stroke=dotted fill-style=hachure stroke-width=3 roughness=2 opacity=0.5 angle=86 locked',
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
      expect(elem.angle, closeTo(86 * 3.14159265358979 / 180, 0.001));
      expect(elem.locked, isTrue);
    });

    test('cross-hatch fill style parses', () {
      final result = parser.parseLine(
        'rect at 0,0 size 100x100 fill-style=cross-hatch',
        1,
      );
      expect(result.value!.fillStyle, FillStyle.crossHatch);
    });
  });

  group('Ellipse parsing', () {
    test('basic ellipse', () {
      final result = parser.parseLine(
        'ellipse id=db at 225,400 size 120x80',
        1,
      );
      expect(result.value, isA<EllipseElement>());
      expect(result.value!.x, 225);
      expect(result.value!.y, 400);
    });

    test('ellipse with fill', () {
      final result = parser.parseLine(
        'ellipse id=db at 225,400 size 120x80 fill=#e8f5e9',
        1,
      );
      expect(result.value!.backgroundColor, '#e8f5e9');
    });
  });

  group('Diamond parsing', () {
    test('basic diamond', () {
      final result = parser.parseLine('diamond at 50,50 size 100x100', 1);
      expect(result.value, isA<DiamondElement>());
      expect(result.value!.x, 50);
      expect(result.value!.y, 50);
    });
  });

  group('Text parsing', () {
    test('basic text', () {
      final result = parser.parseLine('text "High Priority" at 100,50', 1);
      expect(result.value, isA<TextElement>());
      final text = result.value! as TextElement;
      expect(text.text, 'High Priority');
      expect(text.x, 100);
      expect(text.y, 50);
    });

    test('text with font size', () {
      final result = parser.parseLine('text "Big" at 0,0 size=36', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 36);
    });

    test('text with font family', () {
      final result = parser.parseLine('text "Custom" at 0,0 font=Cascadia', 1);
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Cascadia');
    });

    test('text with alignment', () {
      final result = parser.parseLine('text "Centered" at 0,0 align=center', 1);
      final text = result.value! as TextElement;
      expect(text.textAlign, TextAlign.center);
    });

    test('text with color', () {
      final result = parser.parseLine('text "Red" at 100,50 color=#d32f2f', 1);
      expect(result.value!.strokeColor, '#d32f2f');
    });

    test('text defaults to Excalifont font and 20 size', () {
      final result = parser.parseLine('text "Hello" at 0,0', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 20);
      expect(text.fontFamily, 'Excalifont');
      expect(text.textAlign, TextAlign.left);
      expect(text.verticalAlign, VerticalAlign.middle);
    });

    test('text with valign=top', () {
      final result = parser.parseLine('text "Top" at 0,0 valign=top', 1);
      final text = result.value! as TextElement;
      expect(text.verticalAlign, VerticalAlign.top);
    });

    test('text with valign=bottom', () {
      final result = parser.parseLine('text "Bottom" at 0,0 valign=bottom', 1);
      final text = result.value! as TextElement;
      expect(text.verticalAlign, VerticalAlign.bottom);
    });

    test('text with quoted font name containing spaces', () {
      final result = parser.parseLine(
        'text "Hello" at 0,0 font="Lilita One"',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Lilita One');
    });

    test('font=hand-drawn resolves to Excalifont', () {
      final result = parser.parseLine('text "Hello" at 0,0 font=hand-drawn', 1);
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Excalifont');
    });

    test('font=normal resolves to Nunito', () {
      final result = parser.parseLine('text "Hello" at 0,0 font=normal', 1);
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Nunito');
    });

    test('font=code resolves to Source Code Pro', () {
      final result = parser.parseLine('text "Hello" at 0,0 font=code', 1);
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Source Code Pro');
    });

    test('font=Nunito passes through unchanged', () {
      final result = parser.parseLine('text "Hello" at 0,0 font=Nunito', 1);
      final text = result.value! as TextElement;
      expect(text.fontFamily, 'Nunito');
    });

    test('font-size=small resolves to 16', () {
      final result = parser.parseLine('text "Hello" at 0,0 font-size=small', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 16.0);
    });

    test('font-size=xl resolves to 36', () {
      final result = parser.parseLine('text "Hello" at 0,0 font-size=xl', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 36.0);
    });

    test('font-size=medium resolves to 20', () {
      final result = parser.parseLine(
        'text "Hello" at 0,0 font-size=medium',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.fontSize, 20.0);
    });

    test('font-size=large resolves to 28', () {
      final result = parser.parseLine('text "Hello" at 0,0 font-size=large', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 28.0);
    });

    test('font-size short aliases work (s, m, l)', () {
      for (final entry in {'s': 16.0, 'm': 20.0, 'l': 28.0}.entries) {
        final result = parser.parseLine(
          'text "Hello" at 0,0 font-size=${entry.key}',
          1,
        );
        final text = result.value! as TextElement;
        expect(text.fontSize, entry.value, reason: 'font-size=${entry.key}');
      }
    });

    test('numeric size= still works as before', () {
      final result = parser.parseLine('text "Hello" at 0,0 size=24', 1);
      final text = result.value! as TextElement;
      expect(text.fontSize, 24.0);
    });

    test('font-size takes precedence over size', () {
      final result = parser.parseLine(
        'text "Hello" at 0,0 font-size=large size=12',
        1,
      );
      final text = result.value! as TextElement;
      expect(text.fontSize, 28.0);
    });
  });

  group('Line parsing', () {
    test('basic line', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,0],[100,100]]',
        1,
      );
      expect(result.value, isA<LineElement>());
      final line = result.value! as LineElement;
      expect(line.points, hasLength(3));
      expect(line.points[0], const Point(0, 0));
      expect(line.points[1], const Point(100, 0));
      expect(line.points[2], const Point(100, 100));
    });

    test('line with arrowheads', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,0]] start-arrow=dot end-arrow=triangle',
        1,
      );
      final line = result.value! as LineElement;
      expect(line.startArrowhead, Arrowhead.dot);
      expect(line.endArrowhead, Arrowhead.triangle);
    });

    test('line with stroke style', () {
      final result = parser.parseLine(
        'line points=[[0,0],[100,100]] stroke=dotted',
        1,
      );
      expect(result.value!.strokeStyle, StrokeStyle.dotted);
    });
  });

  group('Arrow parsing', () {
    test('arrow with from/to bindings', () {
      final result = parser.parseLine('arrow from auth to gateway', 1);
      expect(result.value, isA<ArrowElement>());
      // Bindings are stored as deferred references
      expect(result.warnings, isEmpty);
    });

    test('arrow with points (no bindings)', () {
      final result = parser.parseLine('arrow points=[[0,0],[200,0]]', 1);
      final arrow = result.value! as ArrowElement;
      expect(arrow.points, hasLength(2));
      expect(arrow.points[0], const Point(0, 0));
      expect(arrow.points[1], const Point(200, 0));
    });

    test('arrow with non-default arrowheads', () {
      final result = parser.parseLine(
        'arrow points=[[0,0],[200,0]] start-arrow=bar end-arrow=dot',
        1,
      );
      final arrow = result.value! as ArrowElement;
      expect(arrow.startArrowhead, Arrowhead.bar);
      expect(arrow.endArrowhead, Arrowhead.dot);
    });

    test('arrow default endArrowhead is arrow', () {
      final result = parser.parseLine('arrow points=[[0,0],[200,0]]', 1);
      final arrow = result.value! as ArrowElement;
      expect(arrow.endArrowhead, Arrowhead.arrow);
    });

    test('arrow with stroke style', () {
      final result = parser.parseLine(
        'arrow from auth to gateway stroke=dashed',
        1,
      );
      expect(result.value!.strokeStyle, StrokeStyle.dashed);
    });

    test('arrow from/to stored as binding aliases', () {
      parser.parseLine('arrow from auth to gateway', 1);
      expect(parser.pendingBindings, isNotEmpty);
    });

    test('parses all new arrowhead types on line', () {
      final cases = <String, Arrowhead>{
        'triangleOutline': Arrowhead.triangleOutline,
        'circle': Arrowhead.circle,
        'circleOutline': Arrowhead.circleOutline,
        'diamond': Arrowhead.diamond,
        'diamondOutline': Arrowhead.diamondOutline,
        'crowfootOne': Arrowhead.crowfootOne,
        'crowfootMany': Arrowhead.crowfootMany,
        'crowfootOneOrMany': Arrowhead.crowfootOneOrMany,
      };
      for (final entry in cases.entries) {
        final result = parser.parseLine(
          'line points=[[0,0],[100,0]] end-arrow=${entry.key}',
          1,
        );
        final line = result.value! as LineElement;
        expect(
          line.endArrowhead,
          entry.value,
          reason: '${entry.key} should parse to ${entry.value}',
        );
      }
    });

    test('parses new arrowhead types as start-arrow on arrow', () {
      final result = parser.parseLine(
        'arrow points=[[0,0],[100,0]] start-arrow=crowfootMany end-arrow=crowfootOne',
        1,
      );
      final arrow = result.value! as ArrowElement;
      expect(arrow.startArrowhead, Arrowhead.crowfootMany);
      expect(arrow.endArrowhead, Arrowhead.crowfootOne);
    });

    test('arrow with coordinate endpoint (partial binding)', () {
      final result = parser.parseLine('arrow from auth to 500,300', 1);
      expect(result.value, isA<ArrowElement>());
      // 'from auth' creates a pending binding, 'to 500,300' is a coordinate
      expect(parser.pendingBindings, hasLength(1));
      expect(parser.pendingBindings.first.fromAlias, 'auth');
      expect(parser.pendingBindings.first.toAlias, isNull);
    });

    test('arrow with coordinate start (partial binding)', () {
      final result = parser.parseLine('arrow from 100,50 to dest', 1);
      expect(result.value, isA<ArrowElement>());
      expect(parser.pendingBindings, hasLength(1));
      expect(parser.pendingBindings.first.fromAlias, isNull);
      expect(parser.pendingBindings.first.toAlias, 'dest');
    });
  });

  group('Freedraw parsing', () {
    test('basic freedraw', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0],[5,2],[10,8]]',
        1,
      );
      expect(result.value, isA<FreedrawElement>());
      final fd = result.value! as FreedrawElement;
      expect(fd.points, hasLength(3));
      expect(fd.points[0], const Point(0, 0));
      expect(fd.points[1], const Point(5, 2));
      expect(fd.points[2], const Point(10, 8));
    });

    test('freedraw with pressure', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0],[5,2],[10,8]] pressure=[0.5,0.7,0.9]',
        1,
      );
      final fd = result.value! as FreedrawElement;
      expect(fd.pressures, [0.5, 0.7, 0.9]);
    });

    test('freedraw with simulate-pressure', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0]] simulate-pressure',
        1,
      );
      final fd = result.value! as FreedrawElement;
      expect(fd.simulatePressure, isTrue);
    });

    test('freedraw with color', () {
      final result = parser.parseLine(
        'freedraw points=[[0,0]] color=#1e1e1e',
        1,
      );
      expect(result.value!.strokeColor, '#1e1e1e');
    });
  });

  group('Alias registration', () {
    test('id= registers alias', () {
      parser.parseLine('rect id=auth at 100,200 size 160x80', 1);
      expect(parser.aliases, containsPair('auth', isNotNull));
    });

    test('element without id does not register alias', () {
      parser.parseLine('rect at 100,200 size 160x80', 1);
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

  group('Named colors and short hex', () {
    test('CSS named color parses to hex', () {
      final result = parser.parseLine('rect at 0,0 100x100 color=red', 1);
      expect(result.value!.strokeColor, '#ff0000');
    });

    test('CSS named fill parses to hex', () {
      final result = parser.parseLine(
        'rect at 0,0 100x100 fill=cornflowerblue',
        1,
      );
      expect(result.value!.backgroundColor, '#6495ed');
    });

    test('named color is case-insensitive', () {
      final result = parser.parseLine('rect at 0,0 100x100 color=Red', 1);
      expect(result.value!.strokeColor, '#ff0000');
    });

    test('short hex expands to full hex', () {
      final result = parser.parseLine('rect at 0,0 100x100 fill=#ccc', 1);
      expect(result.value!.backgroundColor, '#cccccc');
    });

    test('full hex passes through', () {
      final result = parser.parseLine('rect at 0,0 100x100 fill=#e3f2fd', 1);
      expect(result.value!.backgroundColor, '#e3f2fd');
    });

    test('legacy full hex still works (backward compat)', () {
      final result = parser.parseLine('rect at 0,0 100x100 color=#ff0000', 1);
      expect(result.value!.strokeColor, '#ff0000');
    });
  });

  group('Number parsing', () {
    test('decimal positions parsed correctly', () {
      final result = parser.parseLine('rect at 100.5,200.25 size 160x80', 1);
      expect(result.value!.x, 100.5);
      expect(result.value!.y, 200.25);
    });
  });

  // Verifies the autocomplete-generated format: keyword id=keywordN ...
  group('id= immediately after keyword', () {
    test('rect id=rect1 parses correctly', () {
      final result = parser.parseLine('rect id=rect1 at 10,20 size 100x50', 1);
      final elem = result.value!;
      expect(elem, isA<RectangleElement>());
      expect(elem.x, 10);
      expect(elem.y, 20);
      expect(elem.width, 100);
      expect(elem.height, 50);
    });

    test('ellipse id=ellipse1 parses correctly', () {
      final result = parser.parseLine(
        'ellipse id=ellipse1 at 30,40 size 80x60',
        1,
      );
      final elem = result.value!;
      expect(elem, isA<EllipseElement>());
      expect(elem.x, 30);
      expect(elem.y, 40);
      expect(elem.width, 80);
      expect(elem.height, 60);
    });

    test('diamond id=diamond1 parses correctly', () {
      final result = parser.parseLine(
        'diamond id=diamond1 at 50,60 size 90x70',
        1,
      );
      final elem = result.value!;
      expect(elem, isA<DiamondElement>());
      expect(elem.x, 50);
      expect(elem.y, 60);
      expect(elem.width, 90);
      expect(elem.height, 70);
    });

    test('text id=text1 with quoted string after id parses correctly', () {
      final result = parser.parseLine('text id=text1 "Hello world" at 5,15', 1);
      final elem = result.value! as TextElement;
      expect(elem.text, 'Hello world');
      expect(elem.x, 5);
      expect(elem.y, 15);
    });

    test('line id=line1 parses correctly', () {
      final result = parser.parseLine(
        'line id=line1 points=[[0,0],[100,200]]',
        1,
      );
      final elem = result.value! as LineElement;
      expect(elem.points.length, 2);
      expect(elem.points[0].x, 0);
      expect(elem.points[1].x, 100);
    });

    test('arrow id=arrow1 with points parses correctly', () {
      final result = parser.parseLine(
        'arrow id=arrow1 points=[[0,0],[200,100]]',
        1,
      );
      final elem = result.value! as ArrowElement;
      expect(elem.points.length, 2);
      expect(elem.endArrowhead, Arrowhead.arrow);
    });

    test('arrow id=arrow1 with from/to parses correctly', () {
      // First create targets to bind to.
      parser.parseLine('rect id=src at 0,0 size 50x50', 1);
      parser.parseLine('rect id=dst at 200,200 size 50x50', 2);

      final result = parser.parseLine('arrow id=arrow1 from src to dst', 3);
      expect(result.value, isNotNull);
      expect(result.value, isA<ArrowElement>());
    });

    test('freedraw id=freedraw1 parses correctly', () {
      final result = parser.parseLine(
        'freedraw id=freedraw1 points=[[0,0],[5,2],[10,8]]',
        1,
      );
      final elem = result.value! as FreedrawElement;
      expect(elem.points.length, 3);
    });

    test('frame id=frame1 parses correctly', () {
      final result = parser.parseLine('frame id=frame1 at 0,0 size 400x300', 1);
      final elem = result.value! as FrameElement;
      expect(elem.x, 0);
      expect(elem.y, 0);
      expect(elem.width, 400);
      expect(elem.height, 300);
      expect(elem.label, 'Frame'); // default label
    });

    test('frame id=frame1 with label parses correctly', () {
      final result = parser.parseLine(
        'frame id=frame1 "My Frame" at 10,20 size 300x200',
        1,
      );
      final elem = result.value! as FrameElement;
      expect(elem.label, 'My Frame');
      expect(elem.x, 10);
      expect(elem.y, 20);
    });

    test('image id=image1 parses correctly', () {
      final result = parser.parseLine(
        'image id=image1 at 100,200 size 400x300 file=abc12345',
        1,
      );
      final elem = result.value! as ImageElement;
      expect(elem.x, 100);
      expect(elem.y, 200);
      expect(elem.width, 400);
      expect(elem.height, 300);
      expect(elem.fileId, 'abc12345');
    });

    test('id alias is registered and usable for bindings', () {
      parser.parseLine('rect id=rect1 at 0,0 size 50x50', 1);
      final result = parser.parseLine(
        'arrow id=arrow1 from rect1 to 200,200',
        2,
      );
      expect(result.value, isNotNull);
    });
  });
}
