/// Split-pane example: live bidirectional sync between canvas and .markdraw text.
///
/// Demonstrates the human-readable `.markdraw` format — draw on the left,
/// see markdown on the right; edit the markdown, see updates on the canvas.
///
/// Usage:
///   cd example && flutter run -t split_pane_example.dart
library;

import 'dart:async';

import 'package:flutter/material.dart' hide Element, SelectionOverlay;

import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  runApp(MarkdrawApp(
    title: 'Markdraw — Split Pane',
    home: (context, themeMode, onThemeModeChanged) => _SplitPanePage(
      themeMode: themeMode,
      onThemeModeChanged: onThemeModeChanged,
    ),
  ));
}

class _SplitPanePage extends StatefulWidget {
  const _SplitPanePage({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeModeChanged;

  @override
  State<_SplitPanePage> createState() => _SplitPanePageState();
}

class _SplitPanePageState extends State<_SplitPanePage>
    with TickerProviderStateMixin {
  final _controller = MarkdrawController();
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();

  bool _isSyncing = false;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDraggingDivider = false;

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

    // Seed the text pane with the initial (empty) scene.
    _syncCanvasToText();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    _canvasFlash.dispose();
    _textFlash.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sync: canvas → text (immediate)
  // ---------------------------------------------------------------------------

  void _onSceneChanged(Scene scene) {
    if (_isSyncing) return;
    _syncCanvasToText();
    _triggerTextFlash();
  }

  void _syncCanvasToText() {
    _isSyncing = true;
    _textController.text = _controller.serializeScene();
    _isSyncing = false;
  }

  // ---------------------------------------------------------------------------
  // Sync: text → canvas (debounced 150ms)
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    if (_isSyncing) return;
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
        _controller.loadScene(Scene());
      } else {
        final parseResult = DocumentParser.parse(text);
        final doc = parseResult.value;
        final scene = SceneDocumentConverter.documentToScene(doc);
        _controller.loadScene(scene, background: doc.settings.background);
      }
      _triggerCanvasFlash();
    } catch (_) {
      // Parse errors silently ignored — user may be mid-edit.
    }
    _isSyncing = false;
  }

  // ---------------------------------------------------------------------------
  // Flash overlays
  // ---------------------------------------------------------------------------

  void _triggerCanvasFlash() {
    _canvasFlash.forward(from: 0);
  }

  void _triggerTextFlash() {
    _textFlash.forward(from: 0);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
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
                    MarkdrawEditor(
                      controller: _controller,
                      onSceneChanged: _onSceneChanged,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      currentThemeMode: widget.themeMode,
                      config: const MarkdrawEditorConfig(
                        showMenu: false,
                        showHelpButton: false,
                      ),
                    ),
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
      ),
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
              Icon(Icons.code, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
