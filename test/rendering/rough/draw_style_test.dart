import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:rough_flutter/rough_flutter.dart' hide FillStyle;

import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/rendering/rough/draw_style.dart';

void main() {
  Element _element({
    String strokeColor = '#000000',
    String backgroundColor = 'transparent',
    FillStyle fillStyle = FillStyle.solid,
    double strokeWidth = 2.0,
    StrokeStyle strokeStyle = StrokeStyle.solid,
    double roughness = 1.0,
    double opacity = 1.0,
    int seed = 42,
  }) {
    return Element(
      id: ElementId.generate(),
      type: 'rectangle',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      strokeColor: strokeColor,
      backgroundColor: backgroundColor,
      fillStyle: fillStyle,
      strokeWidth: strokeWidth,
      strokeStyle: strokeStyle,
      roughness: roughness,
      opacity: opacity,
      seed: seed,
    );
  }

  group('DrawStyle.fromElement', () {
    test('parses hex stroke color', () {
      final style = DrawStyle.fromElement(_element(strokeColor: '#ff0000'));
      expect(style.strokeColor, const Color(0xFFFF0000));
    });

    test('parses 3-digit hex color', () {
      final style = DrawStyle.fromElement(_element(strokeColor: '#f00'));
      expect(style.strokeColor, const Color(0xFFFF0000));
    });

    test('parses hex background color', () {
      final style =
          DrawStyle.fromElement(_element(backgroundColor: '#0000ff'));
      expect(style.backgroundColor, const Color(0xFF0000FF));
    });

    test('parses transparent background', () {
      final style =
          DrawStyle.fromElement(_element(backgroundColor: 'transparent'));
      expect(style.backgroundColor, const Color(0x00000000));
    });

    test('preserves fill style', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.hachure));
      expect(style.fillStyle, FillStyle.hachure);
    });

    test('preserves stroke width', () {
      final style = DrawStyle.fromElement(_element(strokeWidth: 4.0));
      expect(style.strokeWidth, 4.0);
    });

    test('preserves stroke style', () {
      final style =
          DrawStyle.fromElement(_element(strokeStyle: StrokeStyle.dashed));
      expect(style.strokeStyle, StrokeStyle.dashed);
    });

    test('preserves roughness', () {
      final style = DrawStyle.fromElement(_element(roughness: 2.5));
      expect(style.roughness, 2.5);
    });

    test('preserves opacity', () {
      final style = DrawStyle.fromElement(_element(opacity: 0.5));
      expect(style.opacity, 0.5);
    });

    test('preserves seed', () {
      final style = DrawStyle.fromElement(_element(seed: 123));
      expect(style.seed, 123);
    });
  });

  group('toDrawConfig', () {
    test('contains correct roughness', () {
      final style = DrawStyle.fromElement(_element(roughness: 2.0));
      final config = style.toDrawConfig();
      expect(config.roughness, 2.0);
    });

    test('contains correct seed', () {
      final style = DrawStyle.fromElement(_element(seed: 99));
      final config = style.toDrawConfig();
      expect(config.seed, 99);
    });
  });

  group('toFiller', () {
    test('solid fill style returns SolidFiller', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.solid));
      expect(style.toFiller(), isA<SolidFiller>());
    });

    test('hachure fill style returns HachureFiller', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.hachure));
      expect(style.toFiller(), isA<HachureFiller>());
    });

    test('crossHatch fill style returns CrossHatchFiller', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.crossHatch));
      expect(style.toFiller(), isA<CrossHatchFiller>());
    });

    test('zigzag fill style returns ZigZagFiller', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.zigzag));
      expect(style.toFiller(), isA<ZigZagFiller>());
    });
  });

  group('toStrokePaint', () {
    test('uses stroke color', () {
      final style = DrawStyle.fromElement(_element(strokeColor: '#ff0000'));
      final paint = style.toStrokePaint();
      expect(paint.color, const Color(0xFFFF0000));
    });

    test('uses stroke style', () {
      final style = DrawStyle.fromElement(_element());
      final paint = style.toStrokePaint();
      expect(paint.style, PaintingStyle.stroke);
    });

    test('uses stroke width', () {
      final style = DrawStyle.fromElement(_element(strokeWidth: 3.0));
      final paint = style.toStrokePaint();
      expect(paint.strokeWidth, 3.0);
    });

    test('applies opacity', () {
      final style = DrawStyle.fromElement(
          _element(strokeColor: '#ff0000', opacity: 0.5));
      final paint = style.toStrokePaint();
      expect(paint.color.a, closeTo(0.5, 0.01));
    });

    test('opacity 0 produces fully transparent', () {
      final style = DrawStyle.fromElement(_element(opacity: 0.0));
      final paint = style.toStrokePaint();
      expect(paint.color.a, closeTo(0.0, 0.01));
    });

    test('opacity 1 preserves original alpha', () {
      final style = DrawStyle.fromElement(_element(opacity: 1.0));
      final paint = style.toStrokePaint();
      expect(paint.color.a, closeTo(1.0, 0.01));
    });
  });

  group('toFillPaint', () {
    test('uses background color', () {
      final style =
          DrawStyle.fromElement(_element(backgroundColor: '#00ff00'));
      final paint = style.toFillPaint();
      expect(paint.color, const Color(0xFF00FF00));
    });

    test('uses stroke style for sketch fillers', () {
      final style =
          DrawStyle.fromElement(_element(fillStyle: FillStyle.hachure));
      final paint = style.toFillPaint();
      expect(paint.style, PaintingStyle.stroke);
    });

    test('applies opacity to fill', () {
      final style = DrawStyle.fromElement(
          _element(backgroundColor: '#00ff00', opacity: 0.5));
      final paint = style.toFillPaint();
      expect(paint.color.a, closeTo(0.5, 0.01));
    });

    test('transparent background has zero alpha', () {
      final style =
          DrawStyle.fromElement(_element(backgroundColor: 'transparent'));
      final paint = style.toFillPaint();
      expect(paint.color.a, closeTo(0.0, 0.01));
    });
  });

  group('toGenerator', () {
    test('returns a working Generator', () {
      final style = DrawStyle.fromElement(_element());
      final generator = style.toGenerator();
      expect(generator, isA<Generator>());
    });

    test('generator can produce a drawable', () {
      final style = DrawStyle.fromElement(_element());
      final generator = style.toGenerator();
      final drawable = generator.rectangle(0, 0, 100, 100);
      expect(drawable, isA<Drawable>());
    });
  });

  group('edge cases', () {
    test('strokeWidth 0 produces zero-width paint', () {
      final style = DrawStyle.fromElement(_element(strokeWidth: 0.0));
      final paint = style.toStrokePaint();
      expect(paint.strokeWidth, 0.0);
    });
  });
}
