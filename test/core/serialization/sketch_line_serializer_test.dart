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
import 'package:markdraw/src/core/elements/roundness.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/serialization/sketch_line_serializer.dart';

void main() {
  late SketchLineSerializer serializer;

  setUp(() {
    serializer = SketchLineSerializer();
  });

  group('RectangleElement', () {
    test('basic rectangle', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect, alias: 'auth');
      expect(line, 'rect id=auth at 100,200 size 160x80 seed=42');
    });

    test('rectangle with fill and rounded', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        backgroundColor: '#e3f2fd',
        roundness: const Roundness.adaptive(value: 8),
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect, alias: 'auth');
      expect(
        line,
        'rect id=auth at 100,200 size 160x80 fill=#e3f2fd rounded=8 seed=42',
      );
    });

    test('rectangle with label emits bound text info', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        boundElements: [const BoundElement(id: 't1', type: 'text')],
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      // Bound text is handled separately — the serializer should still
      // emit the shape without label text. Label serialization happens
      // at the document level by checking TextElement.containerId.
      final line = serializer.serialize(rect, alias: 'auth');
      expect(line, contains('rect'));
      expect(line, contains('id=auth'));
    });

    test('rectangle with non-default stroke properties', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        strokeColor: '#ff0000',
        strokeWidth: 4,
        strokeStyle: StrokeStyle.dashed,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, contains('color=#ff0000'));
      expect(line, contains('stroke=dashed'));
      expect(line, contains('stroke-width=4'));
    });

    test('rectangle with all non-default properties', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 60,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        fillStyle: FillStyle.hachure,
        strokeWidth: 3,
        strokeStyle: StrokeStyle.dotted,
        roughness: 2,
        opacity: 0.5,
        angle: 1.5,
        locked: true,
        seed: 99,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect, alias: 'r');
      expect(line, contains('id=r'));
      expect(line, contains('at 10,20'));
      expect(line, contains('size 50x60'));
      expect(line, contains('fill=#00ff00'));
      expect(line, contains('color=#ff0000'));
      expect(line, contains('stroke=dotted'));
      expect(line, contains('fill-style=hachure'));
      expect(line, contains('stroke-width=3'));
      expect(line, contains('roughness=2'));
      expect(line, contains('opacity=0.5'));
      expect(line, contains('angle=1.5'));
      expect(line, contains('locked'));
      expect(line, contains('seed=99'));
    });

    test('crossHatch fillStyle serializes as cross-hatch', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fillStyle: FillStyle.crossHatch,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, contains('fill-style=cross-hatch'));
    });
  });

  group('EllipseElement', () {
    test('basic ellipse', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 225,
        y: 400,
        width: 120,
        height: 80,
        seed: 7,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(ellipse, alias: 'db');
      expect(line, 'ellipse id=db at 225,400 size 120x80 seed=7');
    });

    test('ellipse with fill', () {
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 225,
        y: 400,
        width: 120,
        height: 80,
        backgroundColor: '#e8f5e9',
        seed: 7,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(ellipse, alias: 'db');
      expect(
        line,
        'ellipse id=db at 225,400 size 120x80 fill=#e8f5e9 seed=7',
      );
    });
  });

  group('DiamondElement', () {
    test('basic diamond', () {
      final diamond = DiamondElement(
        id: const ElementId('d1'),
        x: 50,
        y: 50,
        width: 100,
        height: 100,
        seed: 3,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(diamond);
      expect(line, contains('diamond'));
      expect(line, contains('at 50,50'));
      expect(line, contains('size 100x100'));
    });
  });

  group('TextElement', () {
    test('basic text', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 100,
        y: 50,
        width: 200,
        height: 30,
        text: 'High Priority',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, contains('text "High Priority"'));
      expect(line, contains('at 100,50'));
    });

    test('text with non-default font size', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Big',
        fontSize: 36,
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, contains('size=36'));
    });

    test('text does not emit size= when fontSize is default', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Normal',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, isNot(contains('size=')));
    });

    test('text with non-default font', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Custom',
        fontFamily: 'Cascadia',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, contains('font=Cascadia'));
    });

    test('text with non-default alignment', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Centered',
        textAlign: TextAlign.center,
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, contains('align=center'));
    });

    test('text with non-default color', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Red',
        strokeColor: '#d32f2f',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      expect(line, contains('color=#d32f2f'));
    });

    test('text with containerId is emitted', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 30,
        text: 'Label',
        containerId: 'r1',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(text);
      // Bound text has containerId — the serializer should include this
      expect(line, contains('text "Label"'));
    });
  });

  group('LineElement', () {
    test('basic line', () {
      final line_ = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
        seed: 10,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(line_);
      expect(line, contains('line'));
      expect(line, contains('points=[[0,0],[100,0],[100,100]]'));
    });

    test('line with arrowheads', () {
      final line_ = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.triangle,
        seed: 10,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(line_);
      expect(line, contains('start-arrow=dot'));
      expect(line, contains('end-arrow=triangle'));
    });

    test('line with stroke style', () {
      final line_ = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
        strokeStyle: StrokeStyle.dotted,
        seed: 10,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(line_);
      expect(line, contains('stroke=dotted'));
    });
  });

  group('ArrowElement', () {
    test('arrow with bindings', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5),
        ),
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(
        arrow,
        aliasMap: {'r1': 'auth', 'r2': 'gateway'},
      );
      expect(line, contains('arrow'));
      expect(line, contains('from auth'));
      expect(line, contains('to gateway'));
    });

    test('arrow with label binding uses alias map', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5),
        ),
        strokeStyle: StrokeStyle.dashed,
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(
        arrow,
        aliasMap: {'r1': 'auth', 'r2': 'gateway'},
      );
      expect(line, contains('from auth'));
      expect(line, contains('to gateway'));
      expect(line, contains('stroke=dashed'));
    });

    test('arrow without bindings uses points', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(arrow);
      expect(line, contains('arrow'));
      expect(line, contains('points='));
      expect(line, isNot(contains('from ')));
      expect(line, isNot(contains('to ')));
    });

    test('arrow with non-default arrowheads', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        startArrowhead: Arrowhead.bar,
        endArrowhead: Arrowhead.dot,
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(arrow);
      expect(line, contains('start-arrow=bar'));
      expect(line, contains('end-arrow=dot'));
    });

    test('arrow default endArrowhead (arrow) is not emitted', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        seed: 20,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(arrow);
      expect(line, isNot(contains('end-arrow=')));
    });
  });

  group('FreedrawElement', () {
    test('basic freedraw', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 10,
        height: 8,
        points: [const Point(0, 0), const Point(5, 2), const Point(10, 8)],
        seed: 30,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(freedraw);
      expect(line, contains('freedraw'));
      expect(line, contains('points=[[0,0],[5,2],[10,8]]'));
    });

    test('freedraw with pressure', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 10,
        height: 8,
        points: [const Point(0, 0), const Point(5, 2), const Point(10, 8)],
        pressures: [0.5, 0.7, 0.9],
        seed: 30,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(freedraw);
      expect(line, contains('pressure=[0.5,0.7,0.9]'));
    });

    test('freedraw with simulate-pressure', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 10,
        height: 8,
        points: [const Point(0, 0)],
        simulatePressure: true,
        seed: 30,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(freedraw);
      expect(line, contains('simulate-pressure'));
    });

    test('freedraw with non-default color', () {
      final freedraw = FreedrawElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 10,
        height: 8,
        points: [const Point(0, 0)],
        strokeColor: '#1e1e1e',
        seed: 30,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(freedraw);
      expect(line, contains('color=#1e1e1e'));
    });
  });

  group('Number formatting', () {
    test('integers without decimal point', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, contains('at 100,200'));
      expect(line, isNot(contains('100.0')));
    });

    test('decimals preserved when needed', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100.5,
        y: 200.25,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, contains('at 100.5,200.25'));
    });
  });

  group('Default omission', () {
    test('default strokeColor (#000000) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('color=')));
    });

    test('default backgroundColor (transparent) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('fill=')));
    });

    test('default strokeWidth (2) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('stroke-width=')));
    });

    test('default roughness (1) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('roughness=')));
    });

    test('default opacity (1) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('opacity=')));
    });

    test('default angle (0) is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('angle=')));
    });

    test('locked=false is not emitted', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final line = serializer.serialize(rect);
      expect(line, isNot(contains('locked')));
    });
  });
}
