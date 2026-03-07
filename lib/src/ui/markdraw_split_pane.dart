/// Split-pane widget for live bidirectional sync between canvas and .markdraw text.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../markdraw.dart' hide TextAlign;

/// A split pane that shows the editor canvas on the left and a live
/// sketch text editor on the right, with bidirectional sync.
///
/// Canvas changes are reflected in the text pane immediately.
/// Text edits are parsed and applied to the canvas after a 150ms debounce.
///
/// The text pane shows only sketch element lines (no frontmatter, no fences,
/// no files block). A "copy as markdown" button wraps the content in a
/// `` ```markdraw `` fence for pasting into markdown documents.
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
  final _codeController = CodeLineEditingController();
  final _textFocusNode = FocusNode();

  bool _isSyncing = false;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDraggingDivider = false;
  String _lastSyncedText = '';

  // Parse status
  List<ParseWarning> _parseWarnings = [];
  bool _hasParseError = false;
  String _parseErrorMessage = '';

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

    _codeController.addListener(_onTextChanged);

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
    _codeController.dispose();
    _textFocusNode.dispose();
    _canvasFlash.dispose();
    _textFlash.dispose();
    // Restore the previous callback.
    widget.controller.onSceneChanged = _previousOnSceneChanged;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sync: canvas → text (immediate, sketch lines only)
  // ---------------------------------------------------------------------------

  void _onSceneChanged(Scene scene) {
    _previousOnSceneChanged?.call(scene);
    if (_isSyncing) return;
    _syncCanvasToText();
    _textFlash.forward(from: 0);
  }

  void _syncCanvasToText() {
    _isSyncing = true;
    final fullText = widget.controller.serializeScene();
    final sketchLines = _extractSketchLines(fullText);
    _codeController.text = sketchLines;
    _lastSyncedText = sketchLines;
    _isSyncing = false;
  }

  /// Extracts the lines between `` ```markdraw `` and `` ``` `` fences.
  static String _extractSketchLines(String fullText) {
    final lines = fullText.split('\n');
    final buffer = StringBuffer();
    var inSketch = false;
    for (final line in lines) {
      if (line.trim() == '```markdraw') {
        inSketch = true;
        continue;
      }
      if (line.trim() == '```' && inSketch) {
        inSketch = false;
        continue;
      }
      if (inSketch) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Sync: text → canvas (debounced 150ms)
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    if (_isSyncing) return;
    final currentText = _codeController.text;
    if (currentText == _lastSyncedText) return;
    _lastSyncedText = currentText;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      _syncTextToCanvas();
    });
  }

  void _syncTextToCanvas() {
    final text = _codeController.text;
    _isSyncing = true;
    try {
      if (text.trim().isEmpty) {
        widget.controller.loadScene(Scene());
        setState(() {
          _parseWarnings = [];
          _hasParseError = false;
          _parseErrorMessage = '';
        });
      } else {
        final bg = widget.controller.canvasBackgroundColor;
        final wrapped = '---\nmarkdraw: 1\nbackground: "$bg"\n---\n\n'
            '```markdraw\n$text\n```';
        final parseResult = DocumentParser.parse(wrapped);
        final doc = parseResult.value;
        final scene = SceneDocumentConverter.documentToScene(doc);
        widget.controller.loadScene(scene, background: bg);
        setState(() {
          _parseWarnings = parseResult.warnings;
          _hasParseError = false;
          _parseErrorMessage = '';
        });
      }
      _canvasFlash.forward(from: 0);
    } catch (e) {
      // Parse error — canvas keeps last successful state.
      setState(() {
        _hasParseError = true;
        _parseErrorMessage = e.toString();
      });
    }
    _isSyncing = false;
  }

  // ---------------------------------------------------------------------------
  // Copy as markdown
  // ---------------------------------------------------------------------------

  void _onCopyMarkdown() {
    final text = _codeController.text;
    final markdown = '```markdraw\n$text\n```';
    Clipboard.setData(ClipboardData(text: markdown));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied as markdown'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
                    controller: _codeController,
                    focusNode: _textFocusNode,
                    onCopyMarkdown: _onCopyMarkdown,
                    parseWarnings: _parseWarnings,
                    hasParseError: _hasParseError,
                    parseErrorMessage: _parseErrorMessage,
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
    required this.onCopyMarkdown,
    required this.parseWarnings,
    required this.hasParseError,
    required this.parseErrorMessage,
  });

  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCopyMarkdown;
  final List<ParseWarning> parseWarnings;
  final bool hasParseError;
  final String parseErrorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                'markdraw',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Copy as markdown',
                child: IconButton(
                  icon: Icon(
                    Symbols.markdown,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onCopyMarkdown,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Code editor
        Expanded(
          child: CodeAutocomplete(
            viewBuilder: buildAutocompleteView,
            promptsBuilder: ElementIdPromptsBuilder(
              delegate: DefaultCodeAutocompletePromptsBuilder(
                language: langMarkdraw,
                keywordPrompts: markdrawPrompts,
              ),
              controller: controller,
            ),
            child: CodeEditor(
              controller: controller,
              focusNode: focusNode,
              style: CodeEditorStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontHeight: 1.5,
                codeTheme: CodeHighlightTheme(
                  languages: {
                    'markdraw':
                        CodeHighlightThemeMode(mode: langMarkdraw),
                  },
                  theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                ),
              ),
              indicatorBuilder:
                  (context, editingController, chunkController, notifier) {
                return DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  textStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant
                        .withAlpha(120),
                  ),
                );
              },
              sperator: Container(
                width: 1,
                color: theme.dividerColor,
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
        // Parse status bar
        _ParseStatusBar(
          parseWarnings: parseWarnings,
          hasParseError: hasParseError,
          parseErrorMessage: parseErrorMessage,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Parse status bar — shows OK / warnings / error
// -----------------------------------------------------------------------------

class _ParseStatusBar extends StatelessWidget {
  const _ParseStatusBar({
    required this.parseWarnings,
    required this.hasParseError,
    required this.parseErrorMessage,
  });

  final List<ParseWarning> parseWarnings;
  final bool hasParseError;
  final String parseErrorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color dotColor;
    final String label;
    final String? detail;

    if (hasParseError) {
      dotColor = Colors.red;
      label = 'Parse error';
      detail = parseErrorMessage;
    } else if (parseWarnings.isNotEmpty) {
      dotColor = Colors.amber;
      final count = parseWarnings.length;
      label = '$count warning${count == 1 ? '' : 's'}';
      detail = parseWarnings.first.message;
    } else {
      dotColor = Colors.green;
      label = 'OK';
      detail = null;
    }

    return Tooltip(
      message: _tooltipMessage(),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tooltipMessage() {
    if (hasParseError) return parseErrorMessage;
    if (parseWarnings.isEmpty) return 'No issues';
    return parseWarnings.map((w) => 'Line ${w.line}: ${w.message}').join('\n');
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
