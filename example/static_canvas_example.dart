/// Example demonstrating StaticCanvasPainter with interactive pan/zoom.
///
/// Renders a scene with all 7 element types using the rough drawing adapter.
/// Drag to pan, scroll/pinch to zoom, use toolbar buttons to zoom in/out/fit.
///
/// Usage:
///   cd example && flutter run static_canvas_example.dart
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element;

import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart' as core
    show TextElement;
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/rough/rough_canvas_adapter.dart';
import 'package:markdraw/src/rendering/static_canvas_painter.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  runApp(const StaticCanvasExampleApp());
}

class StaticCanvasExampleApp extends StatelessWidget {
  const StaticCanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Static Canvas Example',
      theme: ThemeData(useMaterial3: true),
      home: const _CanvasPage(),
    );
  }
}

class _CanvasPage extends StatefulWidget {
  const _CanvasPage();

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<_CanvasPage> {
  final _adapter = RoughCanvasAdapter();
  var _viewport = const ViewportState();
  Offset? _panStart;
  ViewportState? _viewportAtPanStart;

  late final Scene _scene = _buildDemoScene();

  Scene _buildDemoScene() {
    var scene = Scene();

    scene = scene.addElement(RectangleElement(
      id: const ElementId('rect1'),
      x: 50, y: 50, width: 160, height: 100,
      strokeColor: '#1e1e1e',
      backgroundColor: '#a5d8ff',
      fillStyle: FillStyle.solid,
      seed: 1,
      index: 'a0',
    ));

    scene = scene.addElement(EllipseElement(
      id: const ElementId('ell1'),
      x: 280, y: 50, width: 140, height: 100,
      strokeColor: '#1e1e1e',
      backgroundColor: '#b2f2bb',
      fillStyle: FillStyle.hachure,
      seed: 2,
      index: 'a1',
    ));

    scene = scene.addElement(DiamondElement(
      id: const ElementId('dia1'),
      x: 500, y: 40, width: 120, height: 120,
      strokeColor: '#1e1e1e',
      backgroundColor: '#ffec99',
      fillStyle: FillStyle.crossHatch,
      seed: 3,
      index: 'a2',
    ));

    scene = scene.addElement(LineElement(
      id: const ElementId('line1'),
      x: 50, y: 220, width: 200, height: 50,
      points: [const Point(50, 220), const Point(150, 270), const Point(250, 220)],
      strokeColor: '#e03131',
      strokeStyle: StrokeStyle.dashed,
      seed: 4,
      index: 'a3',
    ));

    scene = scene.addElement(ArrowElement(
      id: const ElementId('arr1'),
      x: 300, y: 240, width: 200, height: 0,
      points: [const Point(300, 240), const Point(500, 240)],
      endArrowhead: Arrowhead.arrow,
      strokeColor: '#1971c2',
      seed: 5,
      index: 'a4',
    ));

    scene = scene.addElement(FreedrawElement(
      id: const ElementId('free1'),
      x: 50, y: 330, width: 230, height: 60,
      points: [
        const Point(50, 370), const Point(80, 340), const Point(110, 380),
        const Point(140, 340), const Point(170, 370), const Point(200, 330),
        const Point(230, 360), const Point(260, 350), const Point(280, 370),
      ],
      strokeColor: '#862e9c',
      seed: 7,
      index: 'a5',
    ));

    scene = scene.addElement(core.TextElement(
      id: const ElementId('txt1'),
      x: 350, y: 330, width: 200, height: 40,
      text: 'Markdraw Canvas',
      fontSize: 24,
      strokeColor: '#1e1e1e',
      index: 'a6',
    ));

    return scene;
  }

  void _zoomAtCenter(double factor) {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    setState(() {
      _viewport = _viewport.zoomAt(factor, center);
    });
  }

  void _fitToContent() {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null) return;
    setState(() {
      _viewport = _viewport.fitToBounds(
        _scene.sceneBounds(),
        size,
        padding: 40,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Static Canvas Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom In',
            onPressed: () => _zoomAtCenter(1.3),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom Out',
            onPressed: () => _zoomAtCenter(1 / 1.3),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Fit to Content',
            onPressed: _fitToContent,
          ),
        ],
      ),
      body: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final factor = event.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15;
            setState(() {
              _viewport = _viewport.zoomAt(factor, event.localPosition);
            });
          }
        },
        child: GestureDetector(
          onPanStart: (details) {
            _panStart = details.localPosition;
            _viewportAtPanStart = _viewport;
          },
          onPanUpdate: (details) {
            if (_panStart == null || _viewportAtPanStart == null) return;
            final delta = details.localPosition - _panStart!;
            setState(() {
              _viewport = _viewportAtPanStart!.pan(delta);
            });
          },
          child: ClipRect(
            child: CustomPaint(
              painter: StaticCanvasPainter(
                scene: _scene,
                adapter: _adapter,
                viewport: _viewport,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}
