/// Example demonstrating InteractiveCanvasPainter on top of StaticCanvasPainter.
///
/// Click an element to select it (shows selection box + handles). Drag handles
/// to resize. Drag a selected element to move it. Drag on empty space for
/// marquee selection. Scroll to zoom. Toolbar buttons for zoom in/out/reset.
///
/// Usage:
///   cd example && flutter run interactive_canvas_example.dart
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element, SelectionOverlay;

import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/interactive/handle.dart';
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

/// What the current drag gesture is doing.
enum _DragMode { none, resizeHandle, moveElement, marquee }

class _CanvasPage extends StatefulWidget {
  const _CanvasPage();

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<_CanvasPage> {
  final _adapter = RoughCanvasAdapter();
  var _viewport = const ViewportState();

  // Scene is mutable so we can move/resize elements
  late Scene _scene = _buildDemoScene();

  // Selection state
  Element? _selectedElement;
  Element? _hoveredElement;

  // Drag state
  _DragMode _dragMode = _DragMode.none;
  HandleType? _activeHandle;
  Point? _dragStartScene;
  Bounds? _elementStartBounds;

  // Marquee state
  Rect? _marqueeRect;
  Offset? _marqueeStartScreen;

  /// Hit-test radius for handles (in scene units).
  double get _handleHitRadius => 8 / _viewport.zoom;

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

  // -- Coordinate conversion --

  Point _screenToScene(Offset screenPos) {
    return Point(
      screenPos.dx / _viewport.zoom + _viewport.offset.dx,
      screenPos.dy / _viewport.zoom + _viewport.offset.dy,
    );
  }

  // -- Hit testing --

  Element? _hitTestElement(Point scenePoint) {
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

  /// Returns the handle type if [scenePoint] is near a handle of the
  /// currently selected element, or null.
  HandleType? _hitTestHandle(Point scenePoint) {
    if (_selectedElement == null) return null;
    final overlay = SelectionOverlay.fromElements([_selectedElement!]);
    if (overlay == null) return null;

    for (final handle in overlay.handles) {
      if (handle.position.distanceTo(scenePoint) <= _handleHitRadius) {
        return handle.type;
      }
    }
    return null;
  }

  // -- Zoom --

  void _zoomAtCenter(double factor) {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null) return;
    _zoomAt(factor, Offset(size.width / 2, size.height / 2));
  }

  void _zoomAt(double factor, Offset screenPoint) {
    final oldZoom = _viewport.zoom;
    final newZoom = (oldZoom * factor).clamp(0.1, 10.0);
    final sceneX = screenPoint.dx / oldZoom + _viewport.offset.dx;
    final sceneY = screenPoint.dy / oldZoom + _viewport.offset.dy;
    setState(() {
      _viewport = ViewportState(
        offset: Offset(sceneX - screenPoint.dx / newZoom,
            sceneY - screenPoint.dy / newZoom),
        zoom: newZoom,
      );
    });
  }

  // -- Gesture handlers --

  void _onPointerDown(PointerDownEvent event) {
    final scenePoint = _screenToScene(event.localPosition);

    // Priority 1: handle on selected element
    final handleType = _hitTestHandle(scenePoint);
    if (handleType != null) {
      _dragMode = _DragMode.resizeHandle;
      _activeHandle = handleType;
      _dragStartScene = scenePoint;
      _elementStartBounds = Bounds.fromLTWH(
        _selectedElement!.x,
        _selectedElement!.y,
        _selectedElement!.width,
        _selectedElement!.height,
      );
      return;
    }

    // Priority 2: element body
    final hit = _hitTestElement(scenePoint);
    if (hit != null) {
      setState(() => _selectedElement = hit);
      _dragMode = _DragMode.moveElement;
      _dragStartScene = scenePoint;
      _elementStartBounds = Bounds.fromLTWH(
        hit.x, hit.y, hit.width, hit.height,
      );
      return;
    }

    // Priority 3: empty space → marquee
    _dragMode = _DragMode.marquee;
    _marqueeStartScreen = event.localPosition;
    setState(() => _selectedElement = null);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragMode == _DragMode.none) {
      // Hover only
      final scenePoint = _screenToScene(event.localPosition);
      final hit = _hitTestElement(scenePoint);
      if (hit != _hoveredElement) setState(() => _hoveredElement = hit);
      return;
    }

    final scenePoint = _screenToScene(event.localPosition);

    switch (_dragMode) {
      case _DragMode.resizeHandle:
        _applyResize(scenePoint);
      case _DragMode.moveElement:
        _applyMove(scenePoint);
      case _DragMode.marquee:
        _applyMarquee(event.localPosition);
      case _DragMode.none:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _dragMode = _DragMode.none;
    _activeHandle = null;
    _dragStartScene = null;
    _elementStartBounds = null;
    _marqueeStartScreen = null;
    setState(() => _marqueeRect = null);
  }

  // -- Move --

  void _applyMove(Point currentScene) {
    if (_selectedElement == null ||
        _dragStartScene == null ||
        _elementStartBounds == null) {
      return;
    }

    final dx = currentScene.x - _dragStartScene!.x;
    final dy = currentScene.y - _dragStartScene!.y;
    final updated = _selectedElement!.copyWith(
      x: _elementStartBounds!.left + dx,
      y: _elementStartBounds!.top + dy,
    );

    setState(() {
      _scene = _scene.updateElement(updated);
      // Re-fetch updated element from scene (version bumped)
      _selectedElement = _scene.getElementById(_selectedElement!.id);
    });
  }

  // -- Resize --

  void _applyResize(Point currentScene) {
    if (_selectedElement == null ||
        _dragStartScene == null ||
        _elementStartBounds == null ||
        _activeHandle == null) {
      return;
    }

    final dx = currentScene.x - _dragStartScene!.x;
    final dy = currentScene.y - _dragStartScene!.y;
    final b = _elementStartBounds!;

    var newLeft = b.left;
    var newTop = b.top;
    var newRight = b.right;
    var newBottom = b.bottom;

    // Adjust edges based on which handle is being dragged
    switch (_activeHandle!) {
      case HandleType.topLeft:
        newLeft += dx;
        newTop += dy;
      case HandleType.topCenter:
        newTop += dy;
      case HandleType.topRight:
        newRight += dx;
        newTop += dy;
      case HandleType.middleLeft:
        newLeft += dx;
      case HandleType.middleRight:
        newRight += dx;
      case HandleType.bottomLeft:
        newLeft += dx;
        newBottom += dy;
      case HandleType.bottomCenter:
        newBottom += dy;
      case HandleType.bottomRight:
        newRight += dx;
        newBottom += dy;
      case HandleType.rotation:
        // Rotation not implemented in this example
        return;
    }

    // Enforce minimum size
    const minSize = 10.0;
    final width = math.max(minSize, newRight - newLeft);
    final height = math.max(minSize, newBottom - newTop);

    final updated = _selectedElement!.copyWith(
      x: newLeft,
      y: newTop,
      width: width,
      height: height,
    );

    setState(() {
      _scene = _scene.updateElement(updated);
      _selectedElement = _scene.getElementById(_selectedElement!.id);
    });
  }

  // -- Marquee --

  void _applyMarquee(Offset screenPos) {
    if (_marqueeStartScreen == null) return;
    final startScene = _screenToScene(_marqueeStartScreen!);
    final endScene = _screenToScene(screenPos);
    setState(() {
      _marqueeRect = Rect.fromPoints(
        Offset(startScene.x, startScene.y),
        Offset(endScene.x, endScene.y),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectionOverlay = _selectedElement != null
        ? SelectionOverlay.fromElements([_selectedElement!])
        : null;

    final hoveredBounds =
        _hoveredElement != null && _hoveredElement != _selectedElement
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
            tooltip: 'Reset View',
            onPressed: () => setState(() {
              _viewport = const ViewportState();
              _selectedElement = null;
            }),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final factor = event.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15;
            _zoomAt(factor, event.localPosition);
          }
        },
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
    );
  }
}
