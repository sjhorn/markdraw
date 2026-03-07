/// Split-pane widget for live bidirectional sync between canvas and .markdraw text.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide Element, SelectionOverlay;

import '../../markdraw.dart' hide TextAlign;

/// A split pane that shows the editor canvas on the left and a live
/// `.markdraw` text editor on the right, with bidirectional sync.
///
/// Canvas changes are reflected in the text pane immediately.
/// Text edits are parsed and applied to the canvas after a 150ms debounce.
class MarkdrawSplitPane extends StatefulWidget {
  const MarkdrawSplitPane({
    super.key,
    required this.controller,
    required this.child,
  });

  /// The editor controller to sync with.
  final MarkdrawController controller;

  /// The editor content (typically the Stack from MarkdrawEditor._buildBody).
  final Widget child;

  @override
  State<MarkdrawSplitPane> createState() => _MarkdrawSplitPaneState();
}

class _MarkdrawSplitPaneState extends State<MarkdrawSplitPane>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();

  bool _isSyncing = false;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDraggingDivider = false;
  String _lastSyncedText = '';

  // Flash animations
  late final AnimationController _canvasFlash;
  late final AnimationController _textFlash;

  static const _minPaneWidth = 280.0;
  static const _dividerWidth = 8.0;
  static const _debounceMs = 150;

  @override
  void initState() {
    super.initState();

    _canvasFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _textController.addListener(_onTextChanged);

    // Wire up scene change listener.
    _previousOnSceneChanged = widget.controller.onSceneChanged;
    widget.controller.onSceneChanged = _onSceneChanged;

    // Seed the text pane with the current scene.
    _syncCanvasToText();
  }

  // Store the previous callback so we can chain it.
  void Function(Scene)? _previousOnSceneChanged;

  @override
  void didUpdateWidget(MarkdrawSplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      // Restore old controller's callback.
      oldWidget.controller.onSceneChanged = _previousOnSceneChanged;
      // Re-wire to new controller.
      _previousOnSceneChanged = widget.controller.onSceneChanged;
      widget.controller.onSceneChanged = _onSceneChanged;
      _syncCanvasToText();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    _canvasFlash.dispose();
    _textFlash.dispose();
    // Restore the previous callback.
    widget.controller.onSceneChanged = _previousOnSceneChanged;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sync: canvas → text (immediate)
  // ---------------------------------------------------------------------------

  void _onSceneChanged(Scene scene) {
    _previousOnSceneChanged?.call(scene);
    if (_isSyncing) return;
    _syncCanvasToText();
    _textFlash.forward(from: 0);
  }

  void _syncCanvasToText() {
    _isSyncing = true;
    final text = widget.controller.serializeScene();
    _textController.text = text;
    _lastSyncedText = text;
    _isSyncing = false;
  }

  // ---------------------------------------------------------------------------
  // Sync: text → canvas (debounced 150ms)
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    if (_isSyncing) return;
    final currentText = _textController.text;
    if (currentText == _lastSyncedText) return;
    _lastSyncedText = currentText;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      _syncTextToCanvas();
    });
  }

  void _syncTextToCanvas() {
    final text = _textController.text;
    _isSyncing = true;
    try {
      if (text.trim().isEmpty) {
        widget.controller.loadScene(Scene());
      } else {
        final parseResult = DocumentParser.parse(text);
        final doc = parseResult.value;
        final scene = SceneDocumentConverter.documentToScene(doc);
        widget.controller
            .loadScene(scene, background: doc.settings.background);
      }
      _canvasFlash.forward(from: 0);
    } catch (_) {
      // Parse errors silently ignored — user may be mid-edit.
    }
    _isSyncing = false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - _dividerWidth;

        // Clamp split ratio so each pane has at least _minPaneWidth.
        final minRatio = _minPaneWidth / usableWidth;
        final maxRatio = 1.0 - minRatio;
        final clampedRatio = _splitRatio.clamp(minRatio, maxRatio);

        final leftWidth = usableWidth * clampedRatio;

        return Row(
          children: [
            // --- Canvas pane ---
            ClipRect(
              child: SizedBox(
                width: leftWidth,
                child: Stack(
                  children: [
                    widget.child,
                    _FlashOverlay(animation: _canvasFlash),
                  ],
                ),
              ),
            ),

            // --- Draggable divider ---
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) {
                  setState(() => _isDraggingDivider = true);
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    final newLeft = (leftWidth + details.delta.dx)
                        .clamp(_minPaneWidth, usableWidth - _minPaneWidth);
                    _splitRatio = newLeft / usableWidth;
                  });
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isDraggingDivider = false);
                },
                child: Container(
                  width: _dividerWidth,
                  color: _isDraggingDivider
                      ? Theme.of(context).colorScheme.primary.withAlpha(80)
                      : Theme.of(context).dividerColor,
                ),
              ),
            ),

            // --- Text pane ---
            Expanded(
              child: Stack(
                children: [
                  _TextPane(
                    controller: _textController,
                    focusNode: _textFocusNode,
                  ),
                  _FlashOverlay(animation: _textFlash),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Text pane with header
// -----------------------------------------------------------------------------

class _TextPane extends StatelessWidget {
  const _TextPane({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Header bar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.code,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '.markdraw',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        // Text editor
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Flash overlay — fades primary color over 300ms
// -----------------------------------------------------------------------------

class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final alpha = (1.0 - animation.value) * 0.12;
        if (alpha <= 0) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: color.withValues(alpha: alpha)),
          ),
        );
      },
    );
  }
}
