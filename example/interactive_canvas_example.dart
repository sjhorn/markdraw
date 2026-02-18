/// Example demonstrating InteractiveCanvasPainter on top of StaticCanvasPainter.
///
/// Renders a scene with several elements. Click an element to select it
/// (shows selection box + handles), hover to see highlight, drag on empty
/// space for a marquee selection rectangle. Zoom buttons in the app bar.
///
/// Usage:
///   cd example && flutter run interactive_canvas_example.dart
library;

import 'package:flutter/material.dart' hide Element, SelectionOverlay;

import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/interactive/interactive_canvas_painter.dart';
import 'package:markdraw/src/rendering/interactive/selection_overlay.dart';
import 'package:markdraw/src/rendering/rough/rough_canvas_adapter.dart';
import 'package:markdraw/src/rendering/static_canvas_painter.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  runApp(const InteractiveCanvasExampleApp());
}

class InteractiveCanvasExampleApp extends StatelessWidget {
  const InteractiveCanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interactive Canvas Example',
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
  Offset? _viewportStart;

  // Interactive state
  Element? _selectedElement;
  Element? _hoveredElement;
  Rect? _marqueeRect;
  Offset? _marqueeStart;
  bool _isDraggingMarquee = false;

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

    scene = scene.addElement(ArrowElement(
      id: const ElementId('arr1'),
      x: 210, y: 100, width: 70, height: 0,
      points: [const Point(210, 100), const Point(280, 100)],
      endArrowhead: Arrowhead.arrow,
      strokeColor: '#1971c2',
      seed: 5,
      index: 'a3',
    ));

    scene = scene.addElement(RectangleElement(
      id: const ElementId('rect2'),
      x: 100, y: 250, width: 200, height: 120,
      strokeColor: '#1e1e1e',
      backgroundColor: '#ffc9c9',
      fillStyle: FillStyle.solid,
      seed: 6,
      index: 'a4',
    ));

    return scene;
  }

  /// Convert screen position to scene coordinates.
  Point _screenToScene(Offset screenPos) {
    return Point(
      screenPos.dx / _viewport.zoom + _viewport.offset.dx,
      screenPos.dy / _viewport.zoom + _viewport.offset.dy,
    );
  }

  /// Hit test: find the topmost element at the given scene point.
  Element? _hitTest(Point scenePoint) {
    final elements = _scene.orderedElements.reversed;
    for (final element in elements) {
      if (element.isDeleted) continue;
      final bounds = Bounds.fromLTWH(
        element.x, element.y, element.width, element.height,
      );
      if (bounds.containsPoint(scenePoint)) return element;
    }
    return null;
  }

  void _onTapDown(TapDownDetails details) {
    final scenePoint = _screenToScene(details.localPosition);
    final hit = _hitTest(scenePoint);
    setState(() {
      _selectedElement = hit;
    });
  }

  void _onPanStart(DragStartDetails details) {
    final scenePoint = _screenToScene(details.localPosition);
    final hit = _hitTest(scenePoint);

    if (hit != null) {
      // Panning the viewport
      _panStart = details.localPosition;
      _viewportStart = _viewport.offset;
      _isDraggingMarquee = false;
    } else {
      // Marquee selection
      _marqueeStart = details.localPosition;
      _isDraggingMarquee = true;
      setState(() {
        _selectedElement = null;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDraggingMarquee && _marqueeStart != null) {
      final current = details.localPosition;
      setState(() {
        _marqueeRect = Rect.fromPoints(
          Offset(
            _marqueeStart!.dx / _viewport.zoom + _viewport.offset.dx,
            _marqueeStart!.dy / _viewport.zoom + _viewport.offset.dy,
          ),
          Offset(
            current.dx / _viewport.zoom + _viewport.offset.dx,
            current.dy / _viewport.zoom + _viewport.offset.dy,
          ),
        );
      });
    } else if (_panStart != null && _viewportStart != null) {
      final delta = details.localPosition - _panStart!;
      setState(() {
        _viewport = ViewportState(
          offset: _viewportStart! - delta / _viewport.zoom,
          zoom: _viewport.zoom,
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _panStart = null;
    _viewportStart = null;
    _marqueeStart = null;
    _isDraggingMarquee = false;
    setState(() {
      _marqueeRect = null;
    });
  }

  void _onHover(PointerEvent details) {
    final scenePoint = _screenToScene(details.localPosition);
    final hit = _hitTest(scenePoint);
    if (hit != _hoveredElement) {
      setState(() {
        _hoveredElement = hit;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionOverlay = _selectedElement != null
        ? SelectionOverlay.fromElements([_selectedElement!])
        : null;

    final hoveredBounds = _hoveredElement != null &&
            _hoveredElement != _selectedElement
        ? Bounds.fromLTWH(
            _hoveredElement!.x,
            _hoveredElement!.y,
            _hoveredElement!.width,
            _hoveredElement!.height,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Canvas Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => setState(() {
              _viewport = ViewportState(
                offset: _viewport.offset,
                zoom: (_viewport.zoom * 1.2).clamp(0.1, 10.0),
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => setState(() {
              _viewport = ViewportState(
                offset: _viewport.offset,
                zoom: (_viewport.zoom / 1.2).clamp(0.1, 10.0),
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: () => setState(() {
              _viewport = const ViewportState();
              _selectedElement = null;
            }),
          ),
        ],
      ),
      body: MouseRegion(
        onHover: _onHover,
        onExit: (_) => setState(() => _hoveredElement = null),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: ClipRect(
            child: CustomPaint(
              painter: StaticCanvasPainter(
                scene: _scene,
                adapter: _adapter,
                viewport: _viewport,
              ),
              foregroundPainter: InteractiveCanvasPainter(
                viewport: _viewport,
                selection: selectionOverlay,
                hoveredBounds: hoveredBounds,
                marqueeRect: _marqueeRect,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}
