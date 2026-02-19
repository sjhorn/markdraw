/// Example demonstrating InteractiveCanvasPainter on top of StaticCanvasPainter.
///
/// Click an element to select it (shows selection box + handles). Drag handles
/// to resize shapes or drag point handles to edit line/arrow vertices. Drag the
/// rotation handle to rotate shapes. Drag a selected element to move it. Drag
/// on empty space for marquee selection. Scroll to zoom.
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
enum _DragMode { none, resizeHandle, moveElement, marquee, dragPoint, rotate }

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
  int? _activePointIndex;
  Point? _dragStartScene;
  Bounds? _elementStartBounds;
  double _elementStartAngle = 0;
  List<Point>? _elementStartPoints;

  // Marquee state
  Rect? _marqueeRect;
  Offset? _marqueeStartScreen;

  /// Hit-test radius for handles (in scene units).
  double get _handleHitRadius => 8 / _viewport.zoom;

  bool get _isLinear => _selectedElement is LineElement;

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

    scene = scene.addElement(LineElement(
      id: const ElementId('line1'),
      x: 350, y: 250, width: 200, height: 80,
      points: [const Point(350, 250), const Point(450, 330), const Point(550, 270)],
      strokeColor: '#e03131',
      seed: 7,
      index: 'a5',
    ));

    return scene;
  }

  // -- Coordinate conversion --

  Point _screenToScene(Offset screenPos) {
    final scene = _viewport.screenToScene(screenPos);
    return Point(scene.dx, scene.dy);
  }

  // -- Hit testing --

  Element? _hitTestElement(Point scenePoint) {
    final elements = _scene.orderedElements.reversed;
    for (final element in elements) {
      if (element.isDeleted) continue;
      // For lines/arrows, hit test along the path segments
      if (element is LineElement) {
        if (_hitTestLine(element.points, scenePoint, _handleHitRadius)) {
          return element;
        }
        continue;
      }
      final bounds = Bounds.fromLTWH(
        element.x, element.y, element.width, element.height,
      );
      if (bounds.containsPoint(scenePoint)) return element;
    }
    return null;
  }

  /// Hit-test a polyline: check distance from point to each segment.
  bool _hitTestLine(List<Point> points, Point target, double threshold) {
    for (var i = 0; i < points.length - 1; i++) {
      if (_distToSegment(target, points[i], points[i + 1]) <= threshold) {
        return true;
      }
    }
    return false;
  }

  /// Distance from point P to line segment AB.
  double _distToSegment(Point p, Point a, Point b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return p.distanceTo(a);
    var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return p.distanceTo(Point(a.x + t * dx, a.y + t * dy));
  }

  /// Returns the index of the closest point handle on the selected line/arrow,
  /// or null if none is close enough.
  int? _hitTestPointHandle(Point scenePoint) {
    if (_selectedElement is! LineElement) return null;
    final line = _selectedElement! as LineElement;
    for (var i = 0; i < line.points.length; i++) {
      if (line.points[i].distanceTo(scenePoint) <= _handleHitRadius) {
        return i;
      }
    }
    return null;
  }

  /// Returns the handle type if [scenePoint] is near a resize/rotation handle
  /// of the currently selected shape (non-linear) element, or null.
  ///
  /// Accounts for element rotation by transforming [scenePoint] into the
  /// element's local (unrotated) coordinate space before testing.
  HandleType? _hitTestHandle(Point scenePoint) {
    if (_selectedElement == null || _isLinear) return null;
    final overlay = SelectionOverlay.fromElements([_selectedElement!]);
    if (overlay == null) return null;

    // Transform scene point into the element's local space (undo rotation)
    final localPoint = _unrotatePoint(
      scenePoint,
      overlay.bounds.center,
      overlay.angle,
    );

    for (final handle in overlay.handles) {
      if (handle.position.distanceTo(localPoint) <= _handleHitRadius) {
        return handle.type;
      }
    }
    return null;
  }

  /// Rotates [point] around [center] by -[angle] (inverse rotation).
  Point _unrotatePoint(Point point, Point center, double angle) {
    if (angle == 0) return point;
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    return Point(
      center.x + dx * cos - dy * sin,
      center.y + dx * sin + dy * cos,
    );
  }

  // -- Zoom --

  void _zoomAtCenter(double factor) {
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null) return;
    setState(() {
      _viewport = _viewport.zoomAt(
        factor,
        Offset(size.width / 2, size.height / 2),
      );
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
      _selectedElement = null;
    });
  }

  // -- Gesture handlers --

  void _onPointerDown(PointerDownEvent event) {
    final scenePoint = _screenToScene(event.localPosition);

    // Priority 1: point handle on selected line/arrow
    final pointIdx = _hitTestPointHandle(scenePoint);
    if (pointIdx != null) {
      final line = _selectedElement! as LineElement;
      _dragMode = _DragMode.dragPoint;
      _activePointIndex = pointIdx;
      _dragStartScene = scenePoint;
      _elementStartPoints = List.of(line.points);
      return;
    }

    // Priority 2: resize/rotation handle on selected shape
    final handleType = _hitTestHandle(scenePoint);
    if (handleType != null) {
      if (handleType == HandleType.rotation) {
        _dragMode = _DragMode.rotate;
        _dragStartScene = scenePoint;
        _elementStartAngle = _selectedElement!.angle;
        _elementStartBounds = Bounds.fromLTWH(
          _selectedElement!.x,
          _selectedElement!.y,
          _selectedElement!.width,
          _selectedElement!.height,
        );
        return;
      }
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

    // Priority 3: element body
    final hit = _hitTestElement(scenePoint);
    if (hit != null) {
      setState(() => _selectedElement = hit);
      _dragMode = _DragMode.moveElement;
      _dragStartScene = scenePoint;
      _elementStartBounds = Bounds.fromLTWH(
        hit.x, hit.y, hit.width, hit.height,
      );
      if (hit is LineElement) {
        _elementStartPoints = List.of(hit.points);
      }
      return;
    }

    // Priority 4: empty space → marquee
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
      case _DragMode.dragPoint:
        _applyDragPoint(scenePoint);
      case _DragMode.rotate:
        _applyRotation(scenePoint);
      case _DragMode.none:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _dragMode = _DragMode.none;
    _activeHandle = null;
    _activePointIndex = null;
    _dragStartScene = null;
    _elementStartBounds = null;
    _elementStartPoints = null;
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

    Element updated;
    if (_selectedElement is LineElement && _elementStartPoints != null) {
      // Move all points for linear elements
      final movedPoints = _elementStartPoints!
          .map((p) => Point(p.x + dx, p.y + dy))
          .toList();
      final line = _selectedElement! as LineElement;
      updated = line.copyWithLine(points: movedPoints).copyWith(
            x: _elementStartBounds!.left + dx,
            y: _elementStartBounds!.top + dy,
          );
    } else {
      updated = _selectedElement!.copyWith(
        x: _elementStartBounds!.left + dx,
        y: _elementStartBounds!.top + dy,
      );
    }

    setState(() {
      _scene = _scene.updateElement(updated);
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
        return;
    }

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

  // -- Drag point (line/arrow vertex) --

  void _applyDragPoint(Point currentScene) {
    if (_selectedElement is! LineElement ||
        _activePointIndex == null ||
        _elementStartPoints == null) {
      return;
    }

    final dx = currentScene.x - _dragStartScene!.x;
    final dy = currentScene.y - _dragStartScene!.y;
    final oldPt = _elementStartPoints![_activePointIndex!];
    final newPoints = List<Point>.of(_elementStartPoints!);
    newPoints[_activePointIndex!] = Point(oldPt.x + dx, oldPt.y + dy);

    final line = _selectedElement! as LineElement;
    final updated = line.copyWithLine(points: newPoints);

    setState(() {
      _scene = _scene.updateElement(updated);
      _selectedElement = _scene.getElementById(_selectedElement!.id);
    });
  }

  // -- Rotation --

  void _applyRotation(Point currentScene) {
    if (_selectedElement == null || _elementStartBounds == null) {
      return;
    }

    final center = _elementStartBounds!.center;
    final startAngle = math.atan2(
      _dragStartScene!.y - center.y,
      _dragStartScene!.x - center.x,
    );
    final currentAngle = math.atan2(
      currentScene.y - center.y,
      currentScene.x - center.x,
    );
    final delta = currentAngle - startAngle;

    final updated = _selectedElement!.copyWith(
      angle: _elementStartAngle + delta,
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
    // For shapes: bounding-box overlay with resize + rotation handles
    // For lines/arrows: bounding-box overlay (no resize handles) + point handles
    SelectionOverlay? selectionOverlay;
    List<Point>? pointHandles;

    if (_selectedElement != null) {
      if (_isLinear) {
        final line = _selectedElement! as LineElement;
        pointHandles = line.points;
        // Compute bounds from actual points for a tighter selection box
        var minX = double.infinity, minY = double.infinity;
        var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
        for (final p in line.points) {
          minX = math.min(minX, p.x);
          minY = math.min(minY, p.y);
          maxX = math.max(maxX, p.x);
          maxY = math.max(maxY, p.y);
        }
        final bounds = Bounds.fromLTWH(minX, minY, maxX - minX, maxY - minY);
        // Only show the bounding box outline, no resize handles
        selectionOverlay = SelectionOverlay(
          bounds: bounds,
          handles: const [],
        );
      } else {
        selectionOverlay = SelectionOverlay.fromElements([_selectedElement!]);
      }
    }

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
            tooltip: 'Fit to Content',
            onPressed: _fitToContent,
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
            setState(() {
              _viewport = _viewport.zoomAt(factor, event.localPosition);
            });
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
              pointHandles: pointHandles,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}
