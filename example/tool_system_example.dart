/// Example demonstrating the Tool System with undo/redo support.
///
/// Uses EditorState + Tool abstractions to handle pointer events. A toolbar
/// lets the user switch between tools. The active tool produces ToolResults
/// that are applied to EditorState, driving scene and viewport changes.
///
/// Supports resize via handles, rotation, point editing, multi-element
/// transforms, keyboard shortcuts (delete, duplicate, copy/paste,
/// nudge, select-all), undo/redo (Ctrl+Z / Ctrl+Shift+Z),
/// and file open/save (Ctrl+O / Ctrl+S / Ctrl+Shift+S).
///
/// Usage:
///   cd example && flutter run tool_system_example.dart
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:markdraw/src/core/history/history_manager.dart';
import 'package:markdraw/src/core/io/document_format.dart';
import 'package:markdraw/src/core/io/document_service.dart';
import 'package:markdraw/src/core/io/scene_document_converter.dart';
import 'package:markdraw/src/core/serialization/clipboard_codec.dart';
import 'package:markdraw/src/core/serialization/document_parser.dart';
import 'package:markdraw/src/core/serialization/document_serializer.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';
import 'package:markdraw/src/editor/clipboard_service.dart';
import 'package:markdraw/src/rendering/export/png_exporter.dart';
import 'package:markdraw/src/rendering/export/svg_exporter.dart';

import 'file_io_stub.dart' if (dart.library.io) 'file_io_native.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/image_element.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/rendering/image_cache.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart' hide TextAlign;
import 'package:markdraw/src/core/elements/text_element.dart'
    as core
    show TextAlign;
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/editor/bindings/arrow_label_utils.dart';
import 'package:markdraw/src/editor/bindings/bound_text_utils.dart';
import 'package:markdraw/src/editor/editor_state.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/arrow_tool.dart';
import 'package:markdraw/src/editor/tools/line_tool.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/editor/tools/tool.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/roundness.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/editor/property_panel_state.dart';
import 'package:markdraw/src/editor/tool_shortcuts.dart';
import 'package:markdraw/src/editor/tools/tool_factory.dart';
import 'package:markdraw/src/rendering/text_renderer.dart';
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
      debugShowCheckedModeBanner: false,
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
  final _historyManager = HistoryManager();
  late final DocumentService _documentService;
  final ClipboardService _clipboardService = const FlutterClipboardService();
  final _imageCache = ImageElementCache();
  String? _currentFilePath;

  // Drag coalescing: capture scene before drag, push once on pointer up
  Scene? _sceneBeforeDrag;

  // Double-click detection for line/arrow finalization
  DateTime? _lastPointerUpTime;

  // Focus management
  final _keyboardFocusNode = FocusNode();

  // Inline text editing
  ElementId? _editingTextElementId;
  final _textEditingController = TextEditingController();
  final _textFocusNode = FocusNode();
  final _editableTextKey = GlobalKey<EditableTextState>();

  // Track whether we're editing an existing element vs a newly created one
  bool _isEditingExisting = false;
  String? _originalText;

  @override
  void initState() {
    super.initState();
    _documentService = const DocumentService(
      readFile: readStringFromFile,
      writeFile: writeStringToFile,
    );
    _editorState = EditorState(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
      activeToolType: ToolType.select,
    );
    _activeTool = createTool(ToolType.select);
    _keyboardFocusNode.requestFocus();

    _textFocusNode.addListener(_onTextFocusChanged);

    _imageCache.onImageDecoded = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _imageCache.dispose();
    _keyboardFocusNode.dispose();
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
    _keyboardFocusNode.requestFocus();
  }

  void _applyResult(ToolResult? result) {
    if (result == null) return;

    // Write to system clipboard on copy/cut
    _syncToSystemClipboard(result);

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

  void _syncToSystemClipboard(ToolResult result) {
    if (result is SetClipboardResult && result.elements.isNotEmpty) {
      final text = ClipboardCodec.serialize(result.elements);
      _clipboardService.copyText(text);
    } else if (result is CompoundResult) {
      for (final r in result.results) {
        _syncToSystemClipboard(r);
      }
    }
  }

  /// Start editing a NEW text element (just created by TextTool).
  void _startTextEditing(EditorState state) {
    if (state.selectedIds.length != 1) return;
    final id = state.selectedIds.first;
    final element = state.scene.getElementById(id);
    if (element == null || element.type != 'text') return;

    _editingTextElementId = id;
    _isEditingExisting = false;
    _originalText = null;
    _textEditingController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  /// Start editing an EXISTING text element on double-click.
  void _startTextEditingExisting(TextElement element) {
    _historyManager.push(_editorState.scene);
    _editingTextElementId = element.id;
    _isEditingExisting = true;
    _originalText = element.text;
    _textEditingController.text = element.text;
    _textEditingController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: element.text.length,
    );
    setState(() {
      _editorState = _editorState.applyResult(SetSelectionResult({element.id}));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  /// Double-click a container shape: create or edit bound text.
  void _startBoundTextEditing(Element shape) {
    _historyManager.push(_editorState.scene);
    final existing = _editorState.scene.findBoundText(shape.id);
    if (existing != null) {
      // Edit existing bound text
      _editingTextElementId = existing.id;
      _isEditingExisting = true;
      _originalText = existing.text;
      _textEditingController.text = existing.text;
      _textEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: existing.text.length,
      );
    } else {
      // Create new bound text
      final newTextId = ElementId.generate();
      final textElem = TextElement(
        id: newTextId,
        x: shape.x,
        y: shape.y,
        width: shape.width,
        height: shape.height,
        text: '',
        containerId: shape.id.value,
      );
      setState(() {
        _editorState = _editorState.applyResult(AddElementResult(textElem));
        // Update parent's boundElements
        final newBound = [
          ...shape.boundElements,
          BoundElement(id: newTextId.value, type: 'text'),
        ];
        _editorState = _editorState.applyResult(
          UpdateElementResult(shape.copyWith(boundElements: newBound)),
        );
      });
      _editingTextElementId = newTextId;
      _isEditingExisting = false;
      _originalText = null;
      _textEditingController.text = '';
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  /// Double-click an arrow: create or edit label.
  void _startArrowLabelEditing(ArrowElement arrow) {
    _historyManager.push(_editorState.scene);
    final existing = _editorState.scene.findBoundText(arrow.id);
    if (existing != null) {
      // Edit existing label
      _editingTextElementId = existing.id;
      _isEditingExisting = true;
      _originalText = existing.text;
      _textEditingController.text = existing.text;
      _textEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: existing.text.length,
      );
    } else {
      // Create new label at arrow midpoint
      final mid = ArrowLabelUtils.computeLabelPosition(arrow);
      final newTextId = ElementId.generate();
      final textElem = TextElement(
        id: newTextId,
        x: mid.x,
        y: mid.y,
        width: 100,
        height: 24,
        text: '',
        containerId: arrow.id.value,
      );
      setState(() {
        _editorState = _editorState.applyResult(AddElementResult(textElem));
        final newBound = [
          ...arrow.boundElements,
          BoundElement(id: newTextId.value, type: 'text'),
        ];
        _editorState = _editorState.applyResult(
          UpdateElementResult(arrow.copyWith(boundElements: newBound)),
        );
      });
      _editingTextElementId = newTextId;
      _isEditingExisting = false;
      _originalText = null;
      _textEditingController.text = '';
    }
    setState(() {});
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
        final element = _editorState.scene.getElementById(id);
        // Empty text: remove element
        _editorState = _editorState.applyResult(RemoveElementResult(id));
        // If it's bound text, also clean up parent's boundElements
        if (element is TextElement && element.containerId != null) {
          final parentId = ElementId(element.containerId!);
          final parent = _editorState.scene.getElementById(parentId);
          if (parent != null) {
            final newBound = parent.boundElements
                .where((b) => b.id != id.value)
                .toList();
            _editorState = _editorState.applyResult(
              UpdateElementResult(parent.copyWith(boundElements: newBound)),
            );
          }
        }
        _editorState = _editorState.applyResult(SetSelectionResult({}));
      } else {
        final element = _editorState.scene.getElementById(id);
        if (element is TextElement) {
          // Use TextRenderer.measure for proper sizing
          final measured = element.copyWithText(text: text);
          final isBound = element.containerId != null;
          if (isBound) {
            // Bound text: just update text, keep parent's dimensions
            _editorState = _editorState.applyResult(
              UpdateElementResult(measured),
            );
          } else {
            // Standalone text: auto-resize
            final (w, h) = TextRenderer.measure(measured);
            final updated = measured.copyWith(
              width: math.max(w + 4, 20.0),
              height: math.max(h, element.fontSize * element.lineHeight),
            );
            _editorState = _editorState.applyResult(
              UpdateElementResult(updated),
            );
          }
        }
      }
      _editingTextElementId = null;
      _isEditingExisting = false;
      _originalText = null;
      _textEditingController.clear();
    });
    _keyboardFocusNode.requestFocus();
  }

  void _cancelTextEditing() {
    if (_editingTextElementId != null) {
      setState(() {
        if (_isEditingExisting && _originalText != null) {
          // Restore original text for existing elements
          final element = _editorState.scene.getElementById(
            _editingTextElementId!,
          );
          if (element is TextElement) {
            _editorState = _editorState.applyResult(
              UpdateElementResult(element.copyWithText(text: _originalText!)),
            );
          }
        } else {
          // Remove newly created element
          final element = _editorState.scene.getElementById(
            _editingTextElementId!,
          );
          _editorState = _editorState.applyResult(
            RemoveElementResult(_editingTextElementId!),
          );
          // Clean up parent's boundElements if it was bound text
          if (element is TextElement && element.containerId != null) {
            final parentId = ElementId(element.containerId!);
            final parent = _editorState.scene.getElementById(parentId);
            if (parent != null) {
              final newBound = parent.boundElements
                  .where((b) => b.id != _editingTextElementId!.value)
                  .toList();
              _editorState = _editorState.applyResult(
                UpdateElementResult(parent.copyWith(boundElements: newBound)),
              );
            }
          }
          _editorState = _editorState.applyResult(SetSelectionResult({}));
        }
        _editingTextElementId = null;
        _isEditingExisting = false;
        _originalText = null;
        _textEditingController.clear();
      });
    }
  }

  Future<void> _exportPng() async {
    try {
      final selectedIds = _editorState.selectedIds.isNotEmpty
          ? _editorState.selectedIds
          : null;
      final bytes = await PngExporter.export(
        _editorState.scene,
        _adapter,
        scale: 2,
        backgroundColor: const Color(0xFFFFFFFF),
        selectedIds: selectedIds,
      );
      if (bytes == null) return;

      if (kIsWeb) {
        downloadBytes('drawing.png', bytes, mimeType: 'image/png');
      } else {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export PNG',
          fileName: 'drawing.png',
          type: FileType.any,
          bytes: bytes,
        );
        if (result != null) {
          // On desktop, saveFile may not write bytes — write manually
          await writeBytesToFile(result, bytes);
        }
      }
    } catch (e) {
      debugPrint('PNG export error: $e');
    }
  }

  Future<void> _exportSvg() async {
    try {
      final selectedIds = _editorState.selectedIds.isNotEmpty
          ? _editorState.selectedIds
          : null;
      final svg = SvgExporter.export(
        _editorState.scene,
        backgroundColor: '#ffffff',
        selectedIds: selectedIds,
      );
      if (svg.isEmpty) return;

      if (kIsWeb) {
        downloadFile('drawing.svg', svg);
      } else {
        final svgBytes = Uint8List.fromList(utf8.encode(svg));
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export SVG',
          fileName: 'drawing.svg',
          type: FileType.any,
          bytes: svgBytes,
        );
        if (result != null) {
          // On desktop, saveFile may not write bytes — write manually
          await writeStringToFile(result, svg);
        }
      }
    } catch (e) {
      debugPrint('SVG export error: $e');
    }
  }

  Future<void> _importImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Image',
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      // Determine MIME type from extension
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/png',
      };

      // Compute fileId (SHA-1 first 8 hex chars)
      final digest = sha1.convert(bytes);
      final fileId = digest.toString().substring(0, 8);
      final imageFile = ImageFile(mimeType: mimeType, bytes: bytes);

      // Decode to get natural dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final naturalWidth = frame.image.width.toDouble();
      final naturalHeight = frame.image.height.toDouble();
      frame.image.dispose();

      // Scale to fit within 800px while preserving aspect ratio
      double width = naturalWidth;
      double height = naturalHeight;
      const maxSize = 800.0;
      if (width > maxSize || height > maxSize) {
        final scale = maxSize / (width > height ? width : height);
        width *= scale;
        height *= scale;
      }

      // Place at viewport center
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final screenSize = renderBox?.size ?? const Size(800, 600);
      final centerScene = _editorState.viewport.screenToScene(
        Offset(screenSize.width / 2, screenSize.height / 2),
      );
      final x = centerScene.dx - width / 2;
      final y = centerScene.dy - height / 2;

      final element = ImageElement(
        id: ElementId.generate(),
        x: x,
        y: y,
        width: width,
        height: height,
        fileId: fileId,
        mimeType: mimeType,
      );

      _historyManager.push(_editorState.scene);
      _applyResult(CompoundResult([
        AddFileResult(fileId: fileId, file: imageFile),
        AddElementResult(element),
        SetSelectionResult({element.id}),
      ]));
    } catch (e) {
      debugPrint('Image import error: $e');
    }
  }

  Future<void> _saveFile() async {
    try {
      if (!kIsWeb && _currentFilePath != null) {
        final doc = SceneDocumentConverter.sceneToDocument(_editorState.scene);
        await _documentService.save(doc, _currentFilePath!);
      } else {
        await _saveFileAs();
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _saveFileAs() async {
    try {
      final doc = SceneDocumentConverter.sceneToDocument(_editorState.scene);
      final content = DocumentSerializer.serialize(doc);

      if (kIsWeb) {
        downloadFile('drawing.markdraw', content);
      } else {
        final bytes = Uint8List.fromList(utf8.encode(content));
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save drawing',
          fileName: 'drawing.markdraw',
          type: FileType.custom,
          allowedExtensions: ['markdraw', 'excalidraw'],
          bytes: bytes,
        );
        if (result != null) {
          _currentFilePath = result;
        }
      }
    } catch (e) {
      debugPrint('Save As error: $e');
    }
  }

  Future<void> _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open drawing',
        type: FileType.any,
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      final ext = file.name.split('.').last.toLowerCase();
      if (!{'markdraw', 'excalidraw', 'json'}.contains(ext)) {
        debugPrint('Unsupported file type: .$ext');
        return;
      }

      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (!kIsWeb) {
        content = await readStringFromFile(file.path!);
      } else {
        return;
      }

      final format = DocumentService.detectFormat(file.name);
      final parseResult = switch (format) {
        DocumentFormat.markdraw => DocumentParser.parse(content),
        DocumentFormat.excalidraw => ExcalidrawJsonCodec.parse(content),
      };
      final scene = SceneDocumentConverter.documentToScene(parseResult.value);
      _historyManager.clear();
      setState(() {
        _currentFilePath = kIsWeb ? null : file.path;
        _editorState = _editorState.copyWith(scene: scene, selectedIds: {});
      });
    } catch (e) {
      debugPrint('Open error: $e');
    }
  }

  Map<String, ui.Image>? _resolveImages() {
    final files = _editorState.scene.files;
    if (files.isEmpty) return null;
    final resolved = <String, ui.Image>{};
    for (final entry in files.entries) {
      final image = _imageCache.getImage(entry.key, entry.value);
      if (image != null) {
        resolved[entry.key] = image;
      }
    }
    return resolved.isEmpty ? null : resolved;
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

    return CallbackShortcuts(
      bindings: _shortcutBindings,
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (_, event) {
          _handleKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Markdraw'),
            actions: [
              IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _openFile,
                tooltip: 'Open (Ctrl+O)',
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveFile,
                tooltip: 'Save (Ctrl+S)',
              ),
              IconButton(
                icon: const Icon(Icons.save_as),
                onPressed: _saveFileAs,
                tooltip: 'Save As (Ctrl+Shift+S)',
              ),
              const VerticalDivider(width: 16, indent: 12, endIndent: 12),
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _exportPng,
                tooltip: 'Export PNG (Ctrl+Shift+E)',
              ),
              IconButton(
                icon: const Icon(Icons.code),
                onPressed: _exportSvg,
                tooltip: 'Export SVG',
              ),
              const VerticalDivider(width: 16, indent: 12, endIndent: 12),
              for (final type in ToolType.values) ...[
                // Insert image import button at position 9 (after text)
                if (type == ToolType.frame)
                  IconButton(
                    icon: const Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.add_photo_alternate),
                        Positioned(
                          right: -6,
                          bottom: -4,
                          child: Text(
                            '9',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: _importImage,
                    tooltip: 'Import Image (9)',
                  ),
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _iconFor(type),
                        color: _editorState.activeToolType == type
                            ? Colors.blue
                            : null,
                      ),
                      if (shortcutForToolType(type) != null)
                        Positioned(
                          right: -8,
                          bottom: -4,
                          child: Text(
                            shortcutForToolType(type)!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _editorState.activeToolType == type
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => _switchTool(type),
                  tooltip: '${type.name} (${shortcutForToolType(type)})',
                ),
              ],
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: _cursorForTool,
                  child: Stack(
                    children: [
                      Listener(
                        onPointerHover: (event) {
                          final point = _toScene(event.localPosition);
                          _activeTool.onPointerMove(point, _toolContext);
                          setState(() {});
                        },
                        onPointerDown: (event) {
                          _keyboardFocusNode.requestFocus();
                          if (_editingTextElementId != null) {
                            _commitTextEditing();
                          }
                          _sceneBeforeDrag = _editorState.scene;
                          final point = _toScene(event.localPosition);
                          final shift = event.buttons == kSecondaryMouseButton;
                          if (_activeTool is SelectTool) {
                            _applyResult(
                              (_activeTool as SelectTool).onPointerDown(
                                point,
                                _toolContext,
                                shift: shift,
                              ),
                            );
                          } else {
                            _applyResult(
                              _activeTool.onPointerDown(point, _toolContext),
                            );
                          }
                        },
                        onPointerMove: (event) {
                          final point = _toScene(event.localPosition);
                          final delta = event.delta;
                          _applyResult(
                            _activeTool.onPointerMove(
                              point,
                              _toolContext,
                              screenDelta: Offset(delta.dx, delta.dy),
                            ),
                          );
                          setState(() {});
                        },
                        onPointerUp: (event) {
                          final point = _toScene(event.localPosition);
                          final now = DateTime.now();
                          final isDoubleClick =
                              _lastPointerUpTime != null &&
                              now
                                      .difference(_lastPointerUpTime!)
                                      .inMilliseconds <
                                  300;
                          _lastPointerUpTime = now;

                          if (_activeTool is LineTool) {
                            _applyResult(
                              (_activeTool as LineTool).onPointerUp(
                                point,
                                _toolContext,
                                isDoubleClick: isDoubleClick,
                              ),
                            );
                          } else if (_activeTool is ArrowTool) {
                            _applyResult(
                              (_activeTool as ArrowTool).onPointerUp(
                                point,
                                _toolContext,
                                isDoubleClick: isDoubleClick,
                              ),
                            );
                          } else {
                            _applyResult(
                              _activeTool.onPointerUp(point, _toolContext),
                            );
                          }

                          // Double-click dispatch for text editing
                          if (isDoubleClick &&
                              _activeTool is SelectTool &&
                              _editingTextElementId == null) {
                            final hit = _editorState.scene.getElementAtPoint(
                              point,
                            );
                            if (hit is TextElement) {
                              _startTextEditingExisting(hit);
                            } else if (hit != null &&
                                BoundTextUtils.isTextContainer(hit)) {
                              _startBoundTextEditing(hit);
                            } else if (hit is ArrowElement) {
                              _startArrowLabelEditing(hit);
                            }
                          }

                          if (_sceneBeforeDrag != null &&
                              !identical(
                                _editorState.scene,
                                _sceneBeforeDrag,
                              )) {
                            _historyManager.push(_sceneBeforeDrag!);
                          }
                          _sceneBeforeDrag = null;
                        },
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            final factor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
                            final newViewport = _editorState.viewport.zoomAt(
                              factor,
                              event.localPosition,
                            );
                            _applyResult(UpdateViewportResult(newViewport));
                          }
                        },
                        child: CustomPaint(
                          painter: StaticCanvasPainter(
                            scene: _editorState.scene,
                            adapter: _adapter,
                            viewport: _editorState.viewport,
                            previewElement: _buildPreviewElement(toolOverlay),
                            editingElementId: _editingTextElementId,
                            resolvedImages: _resolveImages(),
                          ),
                          foregroundPainter: InteractiveCanvasPainter(
                            viewport: _editorState.viewport,
                            selection: _buildSelectionOverlay(),
                            marqueeRect: marqueeRect,
                            bindTargetBounds: toolOverlay?.bindTargetBounds,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (_editingTextElementId != null)
                        _buildTextEditingOverlay(),
                    ],
                  ),
                ),
              ),
              if (_selectedElements.isNotEmpty) _buildPropertyPanel(),
            ],
          ),
        ),
      ),
    );
  }

  /// Shortcut bindings for system-level shortcuts (Cmd+S, Cmd+O, etc.)
  /// that macOS intercepts before KeyEvent reaches Flutter.
  Map<ShortcutActivator, VoidCallback> get _shortcutBindings => {
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saveFile,
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
        _saveFileAs,
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _openFile,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
      final undone = _historyManager.undo(_editorState.scene);
      if (undone != null) {
        setState(() {
          _editorState = _editorState.copyWith(scene: undone);
        });
      }
    },
    const SingleActivator(
      LogicalKeyboardKey.keyZ,
      meta: true,
      shift: true,
    ): () {
      final redone = _historyManager.redo(_editorState.scene);
      if (redone != null) {
        setState(() {
          _editorState = _editorState.copyWith(scene: redone);
        });
      }
    },
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        _exportPng,
    // Ctrl variants for non-macOS platforms
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveFile,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
        _saveFileAs,
    const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openFile,
    const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
        _exportPng,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
      final undone = _historyManager.undo(_editorState.scene);
      if (undone != null) {
        setState(() {
          _editorState = _editorState.copyWith(scene: undone);
        });
      }
    },
    const SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      shift: true,
    ): () {
      final redone = _historyManager.redo(_editorState.scene);
      if (redone != null) {
        setState(() {
          _editorState = _editorState.copyWith(scene: redone);
        });
      }
    },
  };

  List<Element> get _selectedElements {
    return _editorState.selectedIds
        .map((id) => _editorState.scene.getElementById(id))
        .whereType<Element>()
        .toList();
  }

  void _applyStyleChange(ElementStyle style) {
    final elements = _selectedElements;
    if (elements.isEmpty) return;

    _historyManager.push(_editorState.scene);
    final result = PropertyPanelState.applyStyle(elements, style);
    _applyResult(result);
  }

  Widget _buildPropertyPanel() {
    final elements = _selectedElements;
    if (elements.isEmpty) return const SizedBox.shrink();

    final style = PropertyPanelState.fromElements(elements);

    return SizedBox(
      width: 240,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.grey.shade300)),
          color: Colors.grey.shade50,
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildSectionLabel('Stroke'),
            _buildColorRow(
              selected: style.strokeColor,
              onSelect: (c) => _applyStyleChange(ElementStyle(strokeColor: c)),
            ),
            const SizedBox(height: 8),
            _buildSectionLabel('Background'),
            _buildColorRow(
              selected: style.backgroundColor,
              includeTransparent: true,
              onSelect: (c) =>
                  _applyStyleChange(ElementStyle(backgroundColor: c)),
            ),
            const SizedBox(height: 8),
            _buildSectionLabel('Stroke width'),
            _buildStrokeWidthRow(style.strokeWidth),
            const SizedBox(height: 8),
            _buildSectionLabel('Stroke style'),
            _buildStrokeStyleRow(style.strokeStyle),
            const SizedBox(height: 8),
            _buildSectionLabel('Fill style'),
            _buildFillStyleRow(style.fillStyle),
            const SizedBox(height: 8),
            _buildSectionLabel('Roughness'),
            _buildRoughnessSlider(style.roughness),
            const SizedBox(height: 8),
            _buildSectionLabel('Opacity'),
            _buildOpacitySlider(style.opacity),
            if (style.hasRoundness) ...[
              const SizedBox(height: 8),
              _buildSectionLabel('Roundness'),
              _buildRoundnessToggle(style.roundness),
            ],
            if (style.hasText) ...[
              const SizedBox(height: 12),
              _buildSectionLabel('Font size'),
              _buildFontSizeRow(style.fontSize),
              const SizedBox(height: 8),
              _buildSectionLabel('Font family'),
              _buildFontFamilyRow(style.fontFamily),
              const SizedBox(height: 8),
              _buildSectionLabel('Text align'),
              _buildTextAlignRow(style.textAlign),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  static const _colorSwatches = [
    '#000000',
    '#e03131',
    '#2f9e44',
    '#1971c2',
    '#f08c00',
    '#6741d9',
  ];

  Widget _buildColorRow({
    required String? selected,
    required ValueChanged<String> onSelect,
    bool includeTransparent = false,
  }) {
    final colors = [if (includeTransparent) 'transparent', ..._colorSwatches];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final c in colors)
          _ColorSwatch(
            color: c,
            isSelected: selected == c,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }

  Widget _buildStrokeWidthRow(double? current) {
    const widths = [1.0, 2.0, 4.0, 6.0];
    const labels = ['Thin', 'Medium', 'Bold', 'Extra'];
    return _buildToggleRow(
      count: 4,
      labels: labels,
      isSelected: (i) => current == widths[i],
      onTap: (i) => _applyStyleChange(ElementStyle(strokeWidth: widths[i])),
    );
  }

  Widget _buildStrokeStyleRow(StrokeStyle? current) {
    const styles = StrokeStyle.values;
    final labels = styles.map((s) => s.name).toList();
    return _buildToggleRow(
      count: styles.length,
      labels: labels,
      isSelected: (i) => current == styles[i],
      onTap: (i) => _applyStyleChange(ElementStyle(strokeStyle: styles[i])),
    );
  }

  Widget _buildFillStyleRow(FillStyle? current) {
    const styles = FillStyle.values;
    final labels = styles.map((s) => s.name).toList();
    return _buildToggleRow(
      count: styles.length,
      labels: labels,
      isSelected: (i) => current == styles[i],
      onTap: (i) => _applyStyleChange(ElementStyle(fillStyle: styles[i])),
    );
  }

  Widget _buildRoughnessSlider(double? current) {
    return Slider(
      value: current ?? 1.0,
      min: 0,
      max: 3,
      divisions: 6,
      label: current != null ? current.toStringAsFixed(1) : 'mixed',
      onChanged: (v) => _applyStyleChange(ElementStyle(roughness: v)),
    );
  }

  Widget _buildOpacitySlider(double? current) {
    return Slider(
      value: current ?? 1.0,
      min: 0,
      max: 1,
      divisions: 20,
      label: current != null ? '${(current * 100).round()}%' : 'mixed',
      onChanged: (v) => _applyStyleChange(ElementStyle(opacity: v)),
    );
  }

  Widget _buildRoundnessToggle(Roundness? current) {
    final hasRoundness = current != null;
    return Row(
      children: [
        const Text('Round corners', style: TextStyle(fontSize: 12)),
        const Spacer(),
        Switch(
          value: hasRoundness,
          onChanged: (on) {
            if (on) {
              _applyStyleChange(
                const ElementStyle(
                  roundness: Roundness.adaptive(value: 8),
                  hasRoundness: true,
                ),
              );
            } else {
              // Clear roundness by applying with hasRoundness but null value
              // We need a special approach — set a zero-value roundness to
              // signal clearing. Use copyWith(clearRoundness: true) directly.
              final elements = _selectedElements;
              if (elements.isEmpty) return;
              _historyManager.push(_editorState.scene);
              final results = <ToolResult>[];
              for (final e in elements) {
                results.add(
                  UpdateElementResult(e.copyWith(clearRoundness: true)),
                );
              }
              _applyResult(
                results.length == 1 ? results.first : CompoundResult(results),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeRow(double? current) {
    const sizes = [16.0, 20.0, 28.0, 36.0];
    const labels = ['S', 'M', 'L', 'XL'];
    return _buildToggleRow(
      count: 4,
      labels: labels,
      isSelected: (i) => current == sizes[i],
      onTap: (i) =>
          _applyStyleChange(ElementStyle(hasText: true, fontSize: sizes[i])),
    );
  }

  Widget _buildFontFamilyRow(String? current) {
    const families = ['Virgil', 'Helvetica', 'Cascadia'];
    return _buildToggleRow(
      count: families.length,
      labels: families,
      isSelected: (i) => current == families[i],
      onTap: (i) => _applyStyleChange(
        ElementStyle(hasText: true, fontFamily: families[i]),
      ),
    );
  }

  Widget _buildTextAlignRow(core.TextAlign? current) {
    const aligns = core.TextAlign.values;
    final labels = aligns.map((a) => a.name).toList();
    return _buildToggleRow(
      count: aligns.length,
      labels: labels,
      isSelected: (i) => current == aligns[i],
      onTap: (i) =>
          _applyStyleChange(ElementStyle(hasText: true, textAlign: aligns[i])),
    );
  }

  Widget _buildToggleRow({
    required int count,
    required List<String> labels,
    required bool Function(int) isSelected,
    required ValueChanged<int> onTap,
  }) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < count; i++)
          _ToggleChip(
            label: labels[i],
            isSelected: isSelected(i),
            onTap: () => onTap(i),
          ),
      ],
    );
  }

  /// Constructs a temporary preview element from the active tool's overlay
  /// data, so the StaticCanvasPainter renders it with the actual rough style.
  Element? _buildPreviewElement(ToolOverlay? overlay) {
    if (overlay == null) return null;
    final toolType = _editorState.activeToolType;
    const previewId = ElementId('__preview__');
    // Use a fixed seed so the rough strokes don't flicker on each frame.
    // (Without this, each new Element gets a random seed, causing the
    // hand-drawn jitter pattern to change every pointer-move.)
    const previewSeed = 42;

    // Shape tools: preview from creationBounds
    if (overlay.creationBounds != null) {
      final b = overlay.creationBounds!;
      return switch (toolType) {
        ToolType.rectangle => RectangleElement(
          id: previewId,
          x: b.left,
          y: b.top,
          width: b.size.width,
          height: b.size.height,
          seed: previewSeed,
        ),
        ToolType.ellipse => EllipseElement(
          id: previewId,
          x: b.left,
          y: b.top,
          width: b.size.width,
          height: b.size.height,
          seed: previewSeed,
        ),
        ToolType.diamond => DiamondElement(
          id: previewId,
          x: b.left,
          y: b.top,
          width: b.size.width,
          height: b.size.height,
          seed: previewSeed,
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
          id: previewId,
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
          points: relPts,
          seed: previewSeed,
        ),
        ToolType.arrow => ArrowElement(
          id: previewId,
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
          points: relPts,
          seed: previewSeed,
          endArrowhead: Arrowhead.arrow,
        ),
        ToolType.freedraw => FreedrawElement(
          id: previewId,
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
          points: relPts,
          seed: previewSeed,
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
      final measured = element.copyWithText(text: text);
      final isBound = element.containerId != null;
      if (isBound) {
        // Bound text: keep parent's dimensions, just update text
        _editorState = _editorState.applyResult(UpdateElementResult(measured));
      } else {
        // Standalone text: auto-resize using TextRenderer.measure
        final (w, h) = TextRenderer.measure(measured);
        final updated = measured.copyWith(
          width: math.max(w + 4, 20.0),
          height: math.max(h, element.fontSize * element.lineHeight),
        );
        _editorState = _editorState.applyResult(UpdateElementResult(updated));
      }
    });
  }

  Widget _buildTextEditingOverlay() {
    final element = _editorState.scene.getElementById(_editingTextElementId!);
    if (element == null) return const SizedBox.shrink();

    final zoom = _editorState.viewport.zoom;
    final textElem = element is TextElement ? element : null;
    final fontSize = (textElem?.fontSize ?? 20.0) * zoom;
    final fontFamily = textElem?.fontFamily ?? 'Virgil';
    final lineHeight = textElem?.lineHeight ?? 1.25;
    final textColor = _parseColor(element.strokeColor);

    // For bound text, center the editor within the parent shape
    if (textElem != null && textElem.containerId != null) {
      final parent = _editorState.scene.getElementById(
        ElementId(textElem.containerId!),
      );
      if (parent != null) {
        final parentTopLeft = _editorState.viewport.sceneToScreen(
          Offset(parent.x, parent.y),
        );
        final parentW = parent.width * zoom;
        final parentH = parent.height * zoom;

        return Positioned(
          left: parentTopLeft.dx,
          top: parentTopLeft.dy,
          child: SizedBox(
            width: parentW,
            height: parentH,
            child: Center(
              child: IntrinsicWidth(
                child:
                    TextSelectionGestureDetectorBuilder(
                      delegate: _TextSelectionDelegate(_editableTextKey),
                    ).buildGestureDetector(
                      behavior: HitTestBehavior.translucent,
                      child: EditableText(
                        key: _editableTextKey,
                        rendererIgnoresPointer: true,
                        controller: _textEditingController,
                        focusNode: _textFocusNode,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontFamily: fontFamily,
                          color: textColor,
                          height: lineHeight,
                        ),
                        cursorColor: Colors.blue,
                        backgroundCursorColor: Colors.grey,
                        selectionColor: Colors.blue.shade300.withValues(
                          alpha: 0.5,
                        ),
                        maxLines: null,
                        onChanged: (_) => _onTextChanged(),
                        onSubmitted: (_) => _commitTextEditing(),
                      ),
                    ),
              ),
            ),
          ),
        );
      }
    }

    // Standalone text: position at element's top-left
    final screenPos = _editorState.viewport.sceneToScreen(
      Offset(element.x, element.y),
    );

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      child: IntrinsicWidth(
        child:
            TextSelectionGestureDetectorBuilder(
              delegate: _TextSelectionDelegate(_editableTextKey),
            ).buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: EditableText(
                key: _editableTextKey,
                rendererIgnoresPointer: true,
                controller: _textEditingController,
                focusNode: _textFocusNode,
                autofocus: true,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: fontFamily,
                  color: textColor,
                  height: lineHeight,
                ),
                cursorColor: Colors.blue,
                backgroundCursorColor: Colors.grey,
                selectionColor: Colors.blue.shade300.withValues(alpha: 0.5),
                onChanged: (_) => _onTextChanged(),
                onSubmitted: (_) => _commitTextEditing(),
              ),
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
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Undo/redo shortcuts (intercept before tool dispatch)
    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      if (shift) {
        final redone = _historyManager.redo(_editorState.scene);
        if (redone != null) {
          setState(() {
            _editorState = _editorState.copyWith(scene: redone);
          });
        }
      } else {
        final undone = _historyManager.undo(_editorState.scene);
        if (undone != null) {
          setState(() {
            _editorState = _editorState.copyWith(scene: undone);
          });
        }
      }
      return;
    }

    // File shortcuts: Ctrl+S save, Ctrl+Shift+S save-as, Ctrl+O open
    if (ctrl && key == LogicalKeyboardKey.keyS) {
      if (shift) {
        _saveFileAs();
      } else {
        _saveFile();
      }
      return;
    }
    if (ctrl && key == LogicalKeyboardKey.keyO) {
      _openFile();
      return;
    }

    // Tool shortcuts (no modifier keys held)
    if (!ctrl && !shift) {
      final label = key.keyLabel;
      if (label.length == 1) {
        // 9 = import image (not a tool, but an action)
        if (label == '9') {
          _importImage();
          return;
        }
        final toolType = toolTypeForKey(label.toLowerCase());
        if (toolType != null) {
          _switchTool(toolType);
          return;
        }
      }
    }

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
      final result = _activeTool.onKeyEvent(
        keyName,
        shift: shift,
        ctrl: ctrl,
        context: _toolContext,
      );
      if (isSceneChangingResult(result)) {
        _historyManager.push(_editorState.scene);
      }
      _applyResult(result);
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
      ToolType.frame => Icons.crop_free,
    };
  }
}

Color _parseColor(String hex) {
  if (hex == 'transparent') return Colors.transparent;
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('ff$h', radix: 16));
}

class _ColorSwatch extends StatelessWidget {
  final String color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = _parseColor(color);
    final isTransparent = color == 'transparent';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isTransparent ? Colors.white : parsed,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: isTransparent
            ? CustomPaint(painter: _DiagonalLinePainter())
            : null,
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.blue.shade900 : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

/// Delegate for [TextSelectionGestureDetectorBuilder] to enable text
/// selection (tap-to-place-cursor, drag-to-select) on [EditableText].
class _TextSelectionDelegate
    extends TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey;

  _TextSelectionDelegate(this.editableTextKey);

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => true;
}
