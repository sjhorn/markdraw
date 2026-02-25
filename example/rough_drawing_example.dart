/// Example demonstrating the RoughCanvasAdapter rendering all element types.
///
/// This is a Flutter app that uses a CustomPainter to render shapes with
/// the hand-drawn rough_flutter aesthetic.
///
/// Usage:
///   cd example && flutter run rough_drawing_example.dart
library;

import 'package:flutter/material.dart' hide Element;

import 'package:markdraw/markdraw.dart';

void main() {
  runApp(const RoughDrawingExampleApp());
}

class RoughDrawingExampleApp extends StatelessWidget {
  const RoughDrawingExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rough Drawing Example',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            height: 600,
            child: CustomPaint(painter: RoughDemoPainter()),
          ),
        ),
      ),
    );
  }
}

class RoughDemoPainter extends CustomPainter {
  const RoughDemoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final adapter = RoughCanvasAdapter();

    // 1. Rectangle (solid fill)
    adapter.drawRectangle(
      canvas,
      Bounds.fromLTWH(30, 30, 160, 100),
      DrawStyle.fromElement(Element(
        id: const ElementId('rect'),
        type: 'rectangle',
        x: 30,
        y: 30,
        width: 160,
        height: 100,
        strokeColor: '#1e1e1e',
        backgroundColor: '#a5d8ff',
        fillStyle: FillStyle.solid,
        seed: 1,
      )),
    );

    // 2. Ellipse (hachure fill)
    adapter.drawEllipse(
      canvas,
      Bounds.fromLTWH(230, 30, 140, 100),
      DrawStyle.fromElement(Element(
        id: const ElementId('ellipse'),
        type: 'ellipse',
        x: 230,
        y: 30,
        width: 140,
        height: 100,
        strokeColor: '#1e1e1e',
        backgroundColor: '#b2f2bb',
        fillStyle: FillStyle.hachure,
        seed: 2,
      )),
    );

    // 3. Diamond (cross-hatch fill)
    adapter.drawDiamond(
      canvas,
      Bounds.fromLTWH(420, 20, 120, 120),
      DrawStyle.fromElement(Element(
        id: const ElementId('diamond'),
        type: 'diamond',
        x: 420,
        y: 20,
        width: 120,
        height: 120,
        strokeColor: '#1e1e1e',
        backgroundColor: '#ffec99',
        fillStyle: FillStyle.crossHatch,
        seed: 3,
      )),
    );

    // 4. Line (multi-segment, dashed)
    adapter.drawLine(
      canvas,
      [const Point(30, 200), const Point(150, 250), const Point(270, 200)],
      DrawStyle.fromElement(Element(
        id: const ElementId('line'),
        type: 'line',
        x: 30,
        y: 200,
        width: 240,
        height: 50,
        strokeColor: '#e03131',
        strokeStyle: StrokeStyle.dashed,
        strokeWidth: 2.0,
        seed: 4,
      )),
    );

    // 5. Arrow (with arrowheads)
    adapter.drawArrow(
      canvas,
      [const Point(320, 200), const Point(520, 200)],
      null,
      Arrowhead.arrow,
      DrawStyle.fromElement(Element(
        id: const ElementId('arrow'),
        type: 'arrow',
        x: 320,
        y: 200,
        width: 200,
        height: 0,
        strokeColor: '#1971c2',
        strokeWidth: 2.0,
        seed: 5,
      )),
    );

    // 6. Arrow with triangle arrowhead
    adapter.drawArrow(
      canvas,
      [const Point(320, 250), const Point(520, 250)],
      Arrowhead.dot,
      Arrowhead.triangle,
      DrawStyle.fromElement(Element(
        id: const ElementId('arrow2'),
        type: 'arrow',
        x: 320,
        y: 250,
        width: 200,
        height: 0,
        strokeColor: '#2f9e44',
        strokeWidth: 2.0,
        seed: 6,
      )),
    );

    // 7. Freedraw
    FreedrawRenderer.draw(
      canvas,
      [
        const Point(30, 350),
        const Point(50, 330),
        const Point(80, 360),
        const Point(110, 320),
        const Point(140, 370),
        const Point(170, 340),
        const Point(200, 360),
        const Point(230, 310),
        const Point(260, 350),
      ],
      DrawStyle.fromElement(Element(
        id: const ElementId('freedraw'),
        type: 'freedraw',
        x: 30,
        y: 310,
        width: 230,
        height: 60,
        strokeColor: '#862e9c',
        strokeWidth: 2.0,
        seed: 7,
      )),
    );

    // 8. Rectangle with zigzag fill and dotted stroke
    adapter.drawRectangle(
      canvas,
      Bounds.fromLTWH(320, 310, 160, 100),
      DrawStyle.fromElement(Element(
        id: const ElementId('rect2'),
        type: 'rectangle',
        x: 320,
        y: 310,
        width: 160,
        height: 100,
        strokeColor: '#1e1e1e',
        backgroundColor: '#ffc9c9',
        fillStyle: FillStyle.zigzag,
        strokeStyle: StrokeStyle.dotted,
        seed: 8,
      )),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
