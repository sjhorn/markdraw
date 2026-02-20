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

import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/editor/editor_state.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
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
  }

  void _switchTool(ToolType type) {
    setState(() {
      _activeTool.reset();
      _activeTool = createTool(type);
      _editorState = _editorState.copyWith(activeToolType: type);
    });
  }

  void _applyResult(ToolResult? result) {
    if (result == null) return;
    setState(() {
      final newState = _editorState.applyResult(result);
      // If tool switched, create new tool instance
      if (newState.activeToolType != _editorState.activeToolType) {
        _activeTool.reset();
        _activeTool = createTool(newState.activeToolType);
      }
      _editorState = newState;
    });
  }

  ToolContext get _toolContext => ToolContext(
        scene: _editorState.scene,
        viewport: _editorState.viewport,
        selectedIds: _editorState.selectedIds,
        clipboard: _editorState.clipboard,
      );

  Point _toScene(Offset screenPos) {
    final scene =
        _editorState.viewport.screenToScene(screenPos);
    return Point(scene.dx, scene.dy);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Listener(
        onPointerDown: (event) {
          final point = _toScene(event.localPosition);
          final shift = event.buttons == kSecondaryMouseButton;
          if (_activeTool is SelectTool) {
            _applyResult(
                (_activeTool as SelectTool).onPointerDown(point, _toolContext, shift: shift));
          } else {
            _applyResult(_activeTool.onPointerDown(point, _toolContext));
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
          _applyResult(_activeTool.onPointerUp(point, _toolContext));
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
          ),
          foregroundPainter: InteractiveCanvasPainter(
            viewport: _editorState.viewport,
            selection: _buildSelectionOverlay(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    String? keyName;
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      keyName = key == LogicalKeyboardKey.delete ? 'Delete' : 'Backspace';
    } else if (key == LogicalKeyboardKey.escape) {
      keyName = 'Escape';
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
        .whereType<dynamic>()
        .toList();
    if (selected.isEmpty) return null;
    return markdraw.SelectionOverlay.fromElements(selected.cast());
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
