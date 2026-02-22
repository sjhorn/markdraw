import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/rendering/export/svg_path_converter.dart';
import 'package:rough_flutter/rough_flutter.dart';

void main() {
  group('SvgPathConverter.opSetToPathData', () {
    test('move op produces M command', () {
      final opSet = OpSet(type: OpSetType.path, ops: [
        Op.move(PointD(10, 20)),
      ]);
      final d = SvgPathConverter.opSetToPathData(opSet);
      expect(d, contains('M'));
      expect(d, contains('10'));
      expect(d, contains('20'));
    });

    test('lineTo op produces L command', () {
      final opSet = OpSet(type: OpSetType.path, ops: [
        Op.move(PointD(0, 0)),
        Op.lineTo(PointD(100, 50)),
      ]);
      final d = SvgPathConverter.opSetToPathData(opSet);
      expect(d, contains('M'));
      expect(d, contains('L'));
      expect(d, contains('100'));
      expect(d, contains('50'));
    });

    test('curveTo op produces C command', () {
      final opSet = OpSet(type: OpSetType.path, ops: [
        Op.move(PointD(0, 0)),
        Op.curveTo(PointD(10, 20), PointD(30, 40), PointD(50, 60)),
      ]);
      final d = SvgPathConverter.opSetToPathData(opSet);
      expect(d, contains('C'));
      expect(d, contains('50'));
      expect(d, contains('60'));
    });

    test('chained ops produce correct sequence', () {
      final opSet = OpSet(type: OpSetType.path, ops: [
        Op.move(PointD(0, 0)),
        Op.lineTo(PointD(10, 10)),
        Op.lineTo(PointD(20, 20)),
        Op.lineTo(PointD(30, 30)),
      ]);
      final d = SvgPathConverter.opSetToPathData(opSet);
      // Should have M then 3 L commands
      expect('M'.allMatches(d).length, 1);
      expect('L'.allMatches(d).length, 3);
    });

    test('empty opset produces empty string', () {
      final opSet = OpSet(type: OpSetType.path, ops: const []);
      final d = SvgPathConverter.opSetToPathData(opSet);
      expect(d, isEmpty);
    });
  });

  group('SvgPathConverter.arrowheadToPathData', () {
    test('arrow type produces path with M and L', () {
      final d = SvgPathConverter.arrowheadToPathData(
        Arrowhead.arrow,
        const Point(100, 50),
        0.0,
        2.0,
      );
      expect(d, contains('M'));
      expect(d, contains('L'));
    });

    test('triangle type produces closed path', () {
      final d = SvgPathConverter.arrowheadToPathData(
        Arrowhead.triangle,
        const Point(100, 50),
        math.pi / 4,
        2.0,
      );
      expect(d, contains('M'));
      expect(d, contains('L'));
      expect(d, contains('Z'));
    });

    test('bar type produces path with M and L', () {
      final d = SvgPathConverter.arrowheadToPathData(
        Arrowhead.bar,
        const Point(50, 50),
        0.0,
        2.0,
      );
      expect(d, contains('M'));
      expect(d, contains('L'));
    });

    test('dot type produces circle-like path', () {
      final d = SvgPathConverter.arrowheadToPathData(
        Arrowhead.dot,
        const Point(50, 50),
        0.0,
        2.0,
      );
      // Dot produces an arc-based path
      expect(d, isNotEmpty);
    });
  });

  group('SvgPathConverter.freedrawToPathData', () {
    test('empty points returns empty string', () {
      final d = SvgPathConverter.freedrawToPathData(const [], 2.0);
      expect(d, isEmpty);
    });

    test('single point produces circle', () {
      final d = SvgPathConverter.freedrawToPathData(
        [const Point(10, 20)],
        4.0,
      );
      // Should produce an arc/circle at the point
      expect(d, isNotEmpty);
      expect(d, contains('M'));
    });

    test('two points produces line', () {
      final d = SvgPathConverter.freedrawToPathData(
        [const Point(0, 0), const Point(100, 50)],
        2.0,
      );
      expect(d, contains('M'));
      expect(d, contains('L'));
    });

    test('three+ points produces cubic curves', () {
      final d = SvgPathConverter.freedrawToPathData(
        [
          const Point(0, 0),
          const Point(50, 30),
          const Point(100, 10),
          const Point(150, 40),
        ],
        2.0,
      );
      expect(d, contains('M'));
      expect(d, contains('C'));
    });
  });

  group('coordinate precision', () {
    test('coordinates are reasonably precise', () {
      final opSet = OpSet(type: OpSetType.path, ops: [
        Op.move(PointD(1.123456789, 2.987654321)),
      ]);
      final d = SvgPathConverter.opSetToPathData(opSet);
      // Should not have excessive decimal places
      expect(d, isNotEmpty);
      // Verify the numbers are present (may be rounded)
      expect(d, contains('1.12'));
      expect(d, contains('2.99'));
    });
  });
}
