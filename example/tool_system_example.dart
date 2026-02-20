/// Example demonstrating the Phase 3.2 Tool System with transforms.
///
/// Uses EditorState + Tool abstractions to handle pointer events. A toolbar
/// lets the user switch between tools. The active tool produces ToolResults
/// that are applied to EditorState, driving scene and viewport changes.
///
/// Supports resize via handles, rotation, point editing, multi-element
/// transforms, and keyboard shortcuts (delete, duplicate, copy/paste,
/// nudge, select-all).
///
/// Usage:
///   cd example && flutter run tool_system_example.dart
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/editor/editor_state.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/arrow_tool.dart';
import 'package:markdraw/src/editor/tools/line_tool.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/editor/tools/tool.dart';
import 'package:markdraw/src/editor/tools/tool_factory.dart';
import 'package:markdraw/src/rendering/interactive/interactive_canvas_painter.dart';
import 'package:markdraw/src/rendering/interactive/selection_overlay.dart'
    as markdraw;
import 'package:markdraw/src/rendering/rough/rough_canvas_adapter.dart';
import 'package:markdraw/src/rendering/static_canvas_painter.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';
import 'package:markdraw/src/core/scene/scene.dart';

void main() {
  runApp(const ToolSystemExampleApp());
}

class ToolSystemExampleApp extends StatelessWidget {
  const ToolSystemExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tool System Example',
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
  late EditorState _editorState;
  late Tool _activeTool;
  final _adapter = RoughCanvasAdapter();

  // Double-click detection for line/arrow finalization
  DateTime? _lastPointerUpTime;

  // Inline text editing
  ElementId? _editingTextElementId;
  final _textEditingController = TextEditingController();
  final _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
      activeToolType: ToolType.select,
    );
    _activeTool = createTool(ToolType.select);

    _textFocusNode.addListener(_onTextFocusChanged);
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFocusNode.removeListener(_onTextFocusChanged);
    _textFocusNode.dispose();
    super.dispose();
  }

  void _switchTool(ToolType type) {
    setState(() {
      _activeTool.reset();
      _activeTool = createTool(type);
      _editorState = _editorState.copyWith(activeToolType: type);
      _cancelTextEditing();
    });
  }

  void _applyResult(ToolResult? result) {
    if (result == null) return;
    setState(() {
      final newState = _editorState.applyResult(result);
      // If tool switched, create new tool instance
      if (newState.activeToolType != _editorState.activeToolType) {
        final previousToolType = _editorState.activeToolType;
        _activeTool.reset();
        _activeTool = createTool(newState.activeToolType);

        // If switching FROM text tool, start inline editing on the new element
        if (previousToolType == ToolType.text) {
          _startTextEditing(newState);
        }
      }
      _editorState = newState;
    });
  }

  void _startTextEditing(EditorState state) {
    if (state.selectedIds.length != 1) return;
    final id = state.selectedIds.first;
    final element = state.scene.getElementById(id);
    if (element == null || element.type != 'text') return;

    _editingTextElementId = id;
    _textEditingController.text = '';
    // Schedule focus request after the frame so the TextField is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void _onTextFocusChanged() {
    if (!_textFocusNode.hasFocus && _editingTextElementId != null) {
      _commitTextEditing();
    }
  }

  void _commitTextEditing() {
    final id = _editingTextElementId;
    if (id == null) return;

    final text = _textEditingController.text.trim();
    setState(() {
      if (text.isEmpty) {
        // Remove empty text element
        _editorState = _editorState.applyResult(RemoveElementResult(id));
        _editorState = _editorState.applyResult(SetSelectionResult({}));
      } else {
        // Update element with entered text
        final element = _editorState.scene.getElementById(id);
        if (element is TextElement) {
          final updated = element.copyWithText(text: text).copyWith(
            width: text.length * 10.0, // Approximate width
            height: 24.0,
          );
          _editorState = _editorState.applyResult(UpdateElementResult(updated));
        }
      }
      _editingTextElementId = null;
      _textEditingController.clear();
    });
  }

  void _cancelTextEditing() {
    if (_editingTextElementId != null) {
      setState(() {
        _editorState = _editorState.applyResult(
            RemoveElementResult(_editingTextElementId!));
        _editorState = _editorState.applyResult(SetSelectionResult({}));
        _editingTextElementId = null;
        _textEditingController.clear();
      });
    }
  }

  ToolContext get _toolContext => ToolContext(
        scene: _editorState.scene,
        viewport: _editorState.viewport,
        selectedIds: _editorState.selectedIds,
        clipboard: _editorState.clipboard,
      );

  Point _toScene(Offset screenPos) {
    final scene = _editorState.viewport.screenToScene(screenPos);
    return Point(scene.dx, scene.dy);
  }

  MouseCursor get _cursorForTool {
    return switch (_editorState.activeToolType) {
      ToolType.select || ToolType.hand => SystemMouseCursors.basic,
      _ => SystemMouseCursors.precise,
    };
  }

  @override
  Widget build(BuildContext context) {
    final toolOverlay = _activeTool.overlay;

    // Convert Bounds marqueeRect to Flutter Rect for the painter
    Rect? marqueeRect;
    if (toolOverlay?.marqueeRect != null) {
      final b = toolOverlay!.marqueeRect!;
      marqueeRect = Rect.fromLTWH(b.left, b.top, b.size.width, b.size.height);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tool System Example'),
        actions: [
          for (final type in ToolType.values)
            IconButton(
              icon: Icon(_iconFor(type)),
              color: _editorState.activeToolType == type
                  ? Colors.blue
                  : null,
              onPressed: () => _switchTool(type),
              tooltip: type.name,
            ),
        ],
      ),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: _cursorForTool,
          child: Stack(
            children: [
              Listener(
                onPointerDown: (event) {
                  // If editing text, commit before handling new pointer events
                  if (_editingTextElementId != null) {
                    _commitTextEditing();
                  }
                  final point = _toScene(event.localPosition);
                  final shift = event.buttons == kSecondaryMouseButton;
                  if (_activeTool is SelectTool) {
                    _applyResult((_activeTool as SelectTool)
                        .onPointerDown(point, _toolContext, shift: shift));
                  } else {
                    _applyResult(
                        _activeTool.onPointerDown(point, _toolContext));
                  }
                },
                onPointerMove: (event) {
                  final point = _toScene(event.localPosition);
                  final delta = event.delta;
                  _applyResult(_activeTool.onPointerMove(point, _toolContext,
                      screenDelta: Offset(delta.dx, delta.dy)));
                  setState(() {}); // Refresh overlay
                },
                onPointerUp: (event) {
                  final point = _toScene(event.localPosition);
                  final now = DateTime.now();
                  final isDoubleClick = _lastPointerUpTime != null &&
                      now.difference(_lastPointerUpTime!).inMilliseconds < 300;
                  _lastPointerUpTime = now;

                  if (_activeTool is LineTool) {
                    _applyResult((_activeTool as LineTool)
                        .onPointerUp(point, _toolContext,
                            isDoubleClick: isDoubleClick));
                  } else if (_activeTool is ArrowTool) {
                    _applyResult((_activeTool as ArrowTool)
                        .onPointerUp(point, _toolContext,
                            isDoubleClick: isDoubleClick));
                  } else {
                    _applyResult(
                        _activeTool.onPointerUp(point, _toolContext));
                  }
                },
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final factor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
                    final newViewport = _editorState.viewport
                        .zoomAt(factor, event.localPosition);
                    _applyResult(UpdateViewportResult(newViewport));
                  }
                },
                child: CustomPaint(
                  painter: StaticCanvasPainter(
                    scene: _editorState.scene,
                    adapter: _adapter,
                    viewport: _editorState.viewport,
                    previewElement: _buildPreviewElement(toolOverlay),
                  ),
                  foregroundPainter: InteractiveCanvasPainter(
                    viewport: _editorState.viewport,
                    selection: _buildSelectionOverlay(),
                    marqueeRect: marqueeRect,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              // Inline text editing overlay
              if (_editingTextElementId != null)
                _buildTextEditingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Constructs a temporary preview element from the active tool's overlay
  /// data, so the StaticCanvasPainter renders it with the actual rough style.
  Element? _buildPreviewElement(ToolOverlay? overlay) {
    if (overlay == null) return null;
    final toolType = _editorState.activeToolType;
    const previewId = ElementId('__preview__');

    // Shape tools: preview from creationBounds
    if (overlay.creationBounds != null) {
      final b = overlay.creationBounds!;
      return switch (toolType) {
        ToolType.rectangle => RectangleElement(
            id: previewId, x: b.left, y: b.top,
            width: b.size.width, height: b.size.height,
          ),
        ToolType.ellipse => EllipseElement(
            id: previewId, x: b.left, y: b.top,
            width: b.size.width, height: b.size.height,
          ),
        ToolType.diamond => DiamondElement(
            id: previewId, x: b.left, y: b.top,
            width: b.size.width, height: b.size.height,
          ),
        _ => null,
      };
    }

    // Line/arrow/freedraw tools: preview from creationPoints
    if (overlay.creationPoints != null && overlay.creationPoints!.length >= 2) {
      final pts = overlay.creationPoints!;
      final minX = pts.map((p) => p.x).reduce(math.min);
      final minY = pts.map((p) => p.y).reduce(math.min);
      final maxX = pts.map((p) => p.x).reduce(math.max);
      final maxY = pts.map((p) => p.y).reduce(math.max);
      final relPts = pts.map((p) => Point(p.x - minX, p.y - minY)).toList();

      return switch (toolType) {
        ToolType.line => LineElement(
            id: previewId, x: minX, y: minY,
            width: maxX - minX, height: maxY - minY,
            points: relPts,
          ),
        ToolType.arrow => LineElement(
            id: previewId, x: minX, y: minY,
            width: maxX - minX, height: maxY - minY,
            points: relPts,
          ),
        ToolType.freedraw => FreedrawElement(
            id: previewId, x: minX, y: minY,
            width: maxX - minX, height: maxY - minY,
            points: relPts,
          ),
        _ => null,
      };
    }

    return null;
  }

  void _onTextChanged() {
    // Update the element in real-time as the user types
    final id = _editingTextElementId;
    if (id == null) return;
    final element = _editorState.scene.getElementById(id);
    if (element is! TextElement) return;

    final text = _textEditingController.text;
    setState(() {
      final updated = element.copyWithText(text: text).copyWith(
        width: math.max(text.length * 10.0, 20.0),
        height: element.fontSize * element.lineHeight,
      );
      _editorState = _editorState.applyResult(UpdateElementResult(updated));
    });
  }

  Widget _buildTextEditingOverlay() {
    final element = _editorState.scene.getElementById(_editingTextElementId!);
    if (element == null) return const SizedBox.shrink();

    final screenPos = _editorState.viewport
        .sceneToScreen(Offset(element.x, element.y));
    final zoom = _editorState.viewport.zoom;

    // Match the rendered text's font settings
    final fontSize = (element is TextElement ? element.fontSize : 20.0) * zoom;

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      child: IntrinsicWidth(
        child: EditableText(
          controller: _textEditingController,
          focusNode: _textFocusNode,
          autofocus: true,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'Virgil',
            color: Colors.black,
            height: 1.25,
          ),
          cursorColor: Colors.blue,
          backgroundCursorColor: Colors.grey,
          onChanged: (_) => _onTextChanged(),
          onSubmitted: (_) => _commitTextEditing(),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Don't intercept keys while editing text
    if (_editingTextElementId != null) return;

    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    String? keyName;
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      keyName = key == LogicalKeyboardKey.delete ? 'Delete' : 'Backspace';
    } else if (key == LogicalKeyboardKey.escape) {
      keyName = 'Escape';
    } else if (key == LogicalKeyboardKey.enter) {
      keyName = 'Enter';
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      keyName = 'ArrowLeft';
    } else if (key == LogicalKeyboardKey.arrowRight) {
      keyName = 'ArrowRight';
    } else if (key == LogicalKeyboardKey.arrowUp) {
      keyName = 'ArrowUp';
    } else if (key == LogicalKeyboardKey.arrowDown) {
      keyName = 'ArrowDown';
    } else if (key.keyLabel.length == 1) {
      keyName = key.keyLabel.toLowerCase();
    }

    if (keyName != null) {
      _applyResult(_activeTool.onKeyEvent(
        keyName,
        shift: shift,
        ctrl: ctrl,
        context: _toolContext,
      ));
    }
  }

  markdraw.SelectionOverlay? _buildSelectionOverlay() {
    if (_editorState.selectedIds.isEmpty) return null;
    final selected = _editorState.selectedIds
        .map((id) => _editorState.scene.getElementById(id))
        .whereType<Element>()
        .toList();
    if (selected.isEmpty) return null;
    return markdraw.SelectionOverlay.fromElements(selected);
  }

  IconData _iconFor(ToolType type) {
    return switch (type) {
      ToolType.select => Icons.near_me,
      ToolType.rectangle => Icons.rectangle_outlined,
      ToolType.ellipse => Icons.circle_outlined,
      ToolType.diamond => Icons.diamond_outlined,
      ToolType.line => Icons.show_chart,
      ToolType.arrow => Icons.arrow_forward,
      ToolType.freedraw => Icons.draw,
      ToolType.text => Icons.text_fields,
      ToolType.hand => Icons.pan_tool,
    };
  }
}
