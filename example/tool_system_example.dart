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

import 'package:markdraw/markdraw.dart' as core show TextAlign;
import 'package:markdraw/markdraw.dart' hide TextAlign;

import 'file_io_stub.dart' if (dart.library.io) 'file_io_native.dart';

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
  List<LibraryItem> _libraryItems = [];
  bool _showLibraryPanel = false;
  bool _toolLocked = false;
  bool _isCompact = false;

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

  void _undo() {
    final undone = _historyManager.undo(_editorState.scene);
    if (undone != null) {
      setState(() {
        _editorState = _editorState.copyWith(scene: undone);
      });
    }
  }

  void _redo() {
    final redone = _historyManager.redo(_editorState.scene);
    if (redone != null) {
      setState(() {
        _editorState = _editorState.copyWith(scene: redone);
      });
    }
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
        );
        if (result != null) {
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
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export SVG',
          fileName: 'drawing.svg',
          type: FileType.any,
        );
        if (result != null) {
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

      // Decode to get natural dimensions and pre-populate cache
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final decodedImage = frame.image;
      final naturalWidth = decodedImage.width.toDouble();
      final naturalHeight = decodedImage.height.toDouble();

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

      // Pre-populate cache so the image renders instantly
      _imageCache.putImage(fileId, decodedImage);

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

  void _addToLibrary() {
    final selected = _selectedElements;
    if (selected.isEmpty) return;

    final name = 'Item ${_libraryItems.length + 1}';
    final item = LibraryUtils.createFromElements(
      elements: selected,
      name: name,
      allSceneElements: _editorState.scene.activeElements,
      sceneFiles: _editorState.scene.files,
    );
    setState(() {
      _libraryItems = [..._libraryItems, item];
      _showLibraryPanel = true;
    });
  }

  void _placeLibraryItem(LibraryItem item) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final screenSize = renderBox?.size ?? const Size(800, 600);
    final centerScene = _editorState.viewport.screenToScene(
      Offset(screenSize.width / 2, screenSize.height / 2),
    );
    final position = Point(centerScene.dx, centerScene.dy);

    _historyManager.push(_editorState.scene);
    _applyResult(LibraryUtils.instantiate(item: item, position: position));
  }

  void _removeLibraryItem(String id) {
    setState(() {
      _libraryItems = _libraryItems.where((i) => i.id != id).toList();
    });
  }

  Future<void> _importLibrary() async {
    try {
      final file = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Library',
        type: FileType.custom,
        allowedExtensions: ['excalidrawlib', 'markdrawlib'],
        withData: kIsWeb,
      );
      if (file == null || file.files.isEmpty) return;
      final picked = file.files.first;

      final String content;
      if (kIsWeb && picked.bytes != null) {
        content = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        content = await readStringFromFile(picked.path!);
      } else {
        return;
      }

      final format = DocumentService.detectFormat(picked.name);
      final ParseResult<LibraryDocument> result;
      switch (format) {
        case DocumentFormat.markdrawLibrary:
          result = LibraryCodec.parse(content);
        case DocumentFormat.excalidrawLibrary:
          result = ExcalidrawLibCodec.parse(content);
        case DocumentFormat.markdraw:
        case DocumentFormat.excalidraw:
          debugPrint('Not a library file');
          return;
      }

      setState(() {
        _libraryItems = [..._libraryItems, ...result.value.items];
        _showLibraryPanel = true;
      });
    } catch (e) {
      debugPrint('Library import error: $e');
    }
  }

  Future<void> _exportLibrary() async {
    if (_libraryItems.isEmpty) return;
    try {
      final doc = LibraryDocument(items: _libraryItems);
      final content = ExcalidrawLibCodec.serialize(doc);

      if (kIsWeb) {
        downloadFile('library.excalidrawlib', content);
      } else {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Library',
          fileName: 'library.excalidrawlib',
          allowedExtensions: ['excalidrawlib', 'markdrawlib'],
          type: FileType.custom,
        );
        if (result != null) {
          final format = DocumentService.detectFormat(result);
          final String output;
          switch (format) {
            case DocumentFormat.excalidrawLibrary:
              output = ExcalidrawLibCodec.serialize(doc);
            case DocumentFormat.markdrawLibrary:
              output = LibraryCodec.serialize(doc);
            default:
              output = ExcalidrawLibCodec.serialize(doc);
          }
          await writeStringToFile(result, output);
        }
      }
    } catch (e) {
      debugPrint('Library export error: $e');
    }
  }

  Widget _buildLibraryPanel() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Text('Library',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.file_upload, size: 18),
                  onPressed: _importLibrary,
                  tooltip: 'Import Library',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.file_download, size: 18),
                  onPressed: _libraryItems.isEmpty ? null : _exportLibrary,
                  tooltip: 'Export Library',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showLibraryPanel = false),
                  tooltip: 'Close',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          if (_selectedElements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add to Library'),
                  onPressed: _addToLibrary,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _libraryItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No library items.\nSelect elements and click "Add to Library".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _libraryItems.length,
                    itemBuilder: (context, index) {
                      final item = _libraryItems[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${item.elements.length} element${item.elements.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _placeLibraryItem(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          onPressed: () => _removeLibraryItem(item.id),
                          tooltip: 'Remove',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save drawing',
          fileName: 'drawing.markdraw',
          type: FileType.custom,
          allowedExtensions: ['markdraw', 'excalidraw'],
        );
        if (result != null) {
          await writeStringToFile(result, content);
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
        DocumentFormat.markdrawLibrary ||
        DocumentFormat.excalidrawLibrary =>
          throw ArgumentError('Use Import Library for library files'),
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

  InteractionMode get _interactionMode =>
      _isCompact ? InteractionMode.touch : InteractionMode.pointer;

  ToolContext get _toolContext => ToolContext(
    scene: _editorState.scene,
    viewport: _editorState.viewport,
    selectedIds: _editorState.selectedIds,
    clipboard: _editorState.clipboard,
    interactionMode: _interactionMode,
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              if (isCompact != _isCompact) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _isCompact = isCompact);
                });
              }
              return _buildBody(toolOverlay, marqueeRect);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ToolOverlay? toolOverlay, Rect? marqueeRect) {
    return Stack(
      children: [
        // Full-bleed canvas + desktop panels
        Row(
          children: [
            Expanded(child: _buildCanvas(toolOverlay, marqueeRect)),
            if (!_isCompact && _showLibraryPanel) _buildLibraryPanel(),
          ],
        ),
        // Toolbar
        if (_isCompact)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildCompactToolbar()),
          )
        else ...[
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildToolbar()),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _buildHamburgerMenu(),
          ),
        ],
        // Floating property panel — desktop left side
        if (!_isCompact && _selectedElements.isNotEmpty)
          Positioned(
            top: 60,
            left: 12,
            bottom: 12,
            child: _buildPropertyPanel(),
          ),
        // Compact menu button — top-left
        if (_isCompact)
          Positioned(
            top: 12,
            left: 12,
            child: _buildCompactMenuButton(),
          ),
      ],
    );
  }

  Widget _buildCanvas(ToolOverlay? toolOverlay, Rect? marqueeRect) {
    return MouseRegion(
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
                  _activeTool.onPointerDown(
                    point,
                    _toolContext,
                  ),
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
                final hit =
                    _editorState.scene.getElementAtPoint(
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
                final factor =
                    event.scrollDelta.dy < 0 ? 1.1 : 0.9;
                final newViewport =
                    _editorState.viewport.zoomAt(
                      factor,
                      event.localPosition,
                    );
                _applyResult(
                  UpdateViewportResult(newViewport),
                );
              }
            },
            child: CustomPaint(
              painter: StaticCanvasPainter(
                scene: _editorState.scene,
                adapter: _adapter,
                viewport: _editorState.viewport,
                previewElement:
                    _buildPreviewElement(toolOverlay),
                editingElementId: _editingTextElementId,
                resolvedImages: _resolveImages(),
              ),
              foregroundPainter: InteractiveCanvasPainter(
                viewport: _editorState.viewport,
                interactionMode: _interactionMode,
                selection: _isDraggingPointHandle()
                    ? null
                    : _buildSelectionOverlay(),
                marqueeRect: marqueeRect,
                bindTargetBounds:
                    toolOverlay?.bindTargetBounds,
                bindTargetAngle:
                    toolOverlay?.bindTargetAngle ?? 0.0,
                pointHandles: _buildPointHandles(),
                creationPoints: toolOverlay?.creationPoints,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (_editingTextElementId != null)
            _buildTextEditingOverlay(),
          // Compact property panel as bottom sheet trigger
          if (_isCompact && _selectedElements.isNotEmpty)
            Positioned(
              bottom: 72,
              right: 12,
              child: _buildCompactPropertyButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildHamburgerMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.menu, size: 20),
        tooltip: 'Menu',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onSelected: (value) {
          switch (value) {
            case 'open':
              _openFile();
            case 'save':
              _saveFile();
            case 'save_as':
              _saveFileAs();
            case 'export_png':
              _exportPng();
            case 'export_svg':
              _exportSvg();
            case 'library':
              setState(() => _showLibraryPanel = !_showLibraryPanel);
            case 'import_image':
              _importImage();
          }
        },
        itemBuilder: (context) => [
          _menuItem('open', Icons.folder_open, 'Open', 'Ctrl+O'),
          _menuItem('save', Icons.save, 'Save', 'Ctrl+S'),
          _menuItem('save_as', Icons.save_as, 'Save As', 'Ctrl+Shift+S'),
          const PopupMenuDivider(),
          _menuItem(
            'export_png',
            Icons.image,
            'Export PNG',
            'Ctrl+Shift+E',
          ),
          _menuItem('export_svg', Icons.code, 'Export SVG', null),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'library',
            child: Row(
              children: [
                Icon(
                  Icons.library_books,
                  size: 18,
                  color: _showLibraryPanel ? Colors.blue : Colors.grey.shade700,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Library')),
                if (_showLibraryPanel)
                  const Icon(Icons.check, size: 16, color: Colors.blue),
              ],
            ),
          ),
          _menuItem(
            'import_image',
            Icons.add_photo_alternate,
            'Import Image',
            '9',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    String? shortcut,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (shortcut != null)
            Text(
              shortcut,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Undo / Redo
          _toolbarButton(
            icon: Icons.undo,
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: _undo,
          ),
          _toolbarButton(
            icon: Icons.redo,
            tooltip: 'Redo (Ctrl+Shift+Z)',
            onPressed: _redo,
          ),
          _toolbarDivider(),
          // Tool buttons
          for (final type in ToolType.values) ...[
            if (type == ToolType.frame)
              _toolbarButton(
                iconWidget: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 20),
                    Positioned(
                      right: -6,
                      bottom: -3,
                      child: Text(
                        '9',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Import Image (9)',
                onPressed: _importImage,
              ),
            _toolbarButton(
              iconWidget: Stack(
                clipBehavior: Clip.none,
                children: [
                  _iconWidgetFor(
                    type,
                    color: _editorState.activeToolType == type
                        ? Colors.blue
                        : Colors.grey.shade700,
                    size: 20,
                  ),
                  if (shortcutForToolType(type) != null)
                    Positioned(
                      right: -6,
                      bottom: -3,
                      child: Text(
                        shortcutForToolType(type)!,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _editorState.activeToolType == type
                              ? Colors.blue.shade300
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: '${type.name} (${shortcutForToolType(type)})',
              onPressed: () => _switchTool(type),
              isActive: _editorState.activeToolType == type,
            ),
          ],
          _toolbarDivider(),
          // Tool lock
          _toolbarButton(
            icon: _toolLocked ? Icons.lock : Icons.lock_open,
            tooltip: 'Keep tool active (Q)',
            onPressed: () {
              setState(() {
                _toolLocked = !_toolLocked;
                _editorState = _editorState.copyWith(
                  toolLocked: _toolLocked,
                );
                if (!_toolLocked) {
                  _switchTool(ToolType.select);
                }
              });
            },
            isActive: _toolLocked,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _compactToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo',
              onPressed: _undo,
            ),
            _compactToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo',
              onPressed: _redo,
            ),
            _toolbarDivider(),
            for (final type in ToolType.values)
              _compactToolbarButton(
                iconWidget: _iconWidgetFor(
                  type,
                  color: _editorState.activeToolType == type
                      ? Colors.blue
                      : Colors.grey.shade700,
                  size: 22,
                ),
                tooltip: type.name,
                onPressed: () => _switchTool(type),
                isActive: _editorState.activeToolType == type,
              ),
          ],
        ),
      ),
    );
  }

  Widget _compactToolbarButton({
    IconData? icon,
    Widget? iconWidget,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: iconWidget ??
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? Colors.blue : Colors.grey.shade700,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMenuButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.menu, size: 24),
        tooltip: 'Menu',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () => _showCompactMenu(),
      ),
    );
  }

  void _showCompactMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _compactMenuItem(Icons.folder_open, 'Open', () {
              Navigator.pop(ctx);
              _openFile();
            }),
            _compactMenuItem(Icons.save, 'Save', () {
              Navigator.pop(ctx);
              _saveFile();
            }),
            _compactMenuItem(Icons.save_as, 'Save As', () {
              Navigator.pop(ctx);
              _saveFileAs();
            }),
            const Divider(),
            _compactMenuItem(Icons.image, 'Export PNG', () {
              Navigator.pop(ctx);
              _exportPng();
            }),
            _compactMenuItem(Icons.code, 'Export SVG', () {
              Navigator.pop(ctx);
              _exportSvg();
            }),
            const Divider(),
            _compactMenuItem(Icons.add_photo_alternate, 'Import Image', () {
              Navigator.pop(ctx);
              _importImage();
            }),
            _compactMenuItem(Icons.library_books, 'Library', () {
              Navigator.pop(ctx);
              _showCompactLibrary();
            }),
          ],
        ),
      ),
    );
  }

  ListTile _compactMenuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _buildCompactPropertyButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.tune, size: 22),
        tooltip: 'Properties',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () => _showCompactPropertyPanel(),
      ),
    );
  }

  void _showCompactPropertyPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        minChildSize: 0.15,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) {
          final elements = _selectedElements;
          if (elements.isEmpty) return const SizedBox.shrink();
          final style = PropertyPanelState.fromElements(elements);
          final isLocked = style.locked == true;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: isLocked,
                  child: Opacity(
                    opacity: isLocked ? 0.4 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Stroke'),
                        _buildColorPickerRow(
                          selected: style.strokeColor,
                          onSelect: (c) =>
                              _applyStyleChange(ElementStyle(strokeColor: c)),
                          quickPicks: _strokeQuickPicks,
                        ),
                        const SizedBox(height: 8),
                        _buildSectionLabel('Background'),
                        _buildColorPickerRow(
                          selected: style.backgroundColor,
                          onSelect: (c) => _applyStyleChange(
                              ElementStyle(backgroundColor: c)),
                          quickPicks: _backgroundQuickPicks,
                        ),
                        const SizedBox(height: 8),
                        _buildSectionLabel('Fill style'),
                        _buildFillStyleRow(style.fillStyle),
                        const SizedBox(height: 8),
                        _buildSectionLabel('Stroke width'),
                        _buildStrokeWidthRow(style.strokeWidth),
                        const SizedBox(height: 8),
                        _buildSectionLabel('Stroke style'),
                        _buildStrokeStyleRow(style.strokeStyle),
                        const SizedBox(height: 8),
                        _buildSectionLabel('Sloppiness'),
                        _buildRoughnessRow(style.roughness),
                        if (style.hasRoundness) ...[
                          const SizedBox(height: 8),
                          _buildSectionLabel('Roundness'),
                          _buildRoundnessRow(style.roundness),
                        ],
                        if (style.hasArrows) ...[
                          const SizedBox(height: 8),
                          _buildSectionLabel('Arrow type'),
                          _buildElbowedRow(style.elbowed),
                        ],
                        if (style.hasText) ...[
                          const SizedBox(height: 12),
                          _buildSectionLabel('Font family'),
                          _buildFontFamilyRow(style.fontFamily),
                          const SizedBox(height: 8),
                          _buildSectionLabel('Font size'),
                          _buildFontSizeRow(style.fontSize),
                          const SizedBox(height: 8),
                          _buildSectionLabel('Text align'),
                          _buildTextAlignRow(style.textAlign),
                        ],
                        if (style.hasLines) ...[
                          const SizedBox(height: 8),
                          _buildArrowheadRow(
                            label: 'Start arrowhead',
                            current: style.startArrowhead,
                            isNone: style.startArrowheadNone,
                            onSelect: (a) {
                              if (a == null) {
                                _applyStyleChange(const ElementStyle(
                                    hasLines: true,
                                    startArrowheadNone: true));
                              } else {
                                _applyStyleChange(ElementStyle(
                                    hasLines: true, startArrowhead: a));
                              }
                            },
                          ),
                          const SizedBox(height: 4),
                          _buildArrowheadRow(
                            label: 'End arrowhead',
                            current: style.endArrowhead,
                            isNone: style.endArrowheadNone,
                            onSelect: (a) {
                              if (a == null) {
                                _applyStyleChange(const ElementStyle(
                                    hasLines: true, endArrowheadNone: true));
                              } else {
                                _applyStyleChange(ElementStyle(
                                    hasLines: true, endArrowhead: a));
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildSectionLabel('Opacity'),
                        _buildOpacitySlider(style.opacity),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionLabel('Layer order'),
                _buildLayerButtons(),
                const SizedBox(height: 8),
                _buildAlignmentButtons(elements.length),
                const SizedBox(height: 12),
                _buildLockToggle(style.locked),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCompactLibrary() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Library',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.file_upload, size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _importLibrary();
                      },
                      tooltip: 'Import Library',
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download, size: 20),
                      onPressed: _libraryItems.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _exportLibrary();
                            },
                      tooltip: 'Export Library',
                    ),
                  ],
                ),
              ),
              if (_selectedElements.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add to Library'),
                      onPressed: () {
                        _addToLibrary();
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              Expanded(
                child: _libraryItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No library items.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _libraryItems.length,
                        itemBuilder: (context, index) {
                          final item = _libraryItems[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                                '${item.elements.length} element${item.elements.length == 1 ? '' : 's'}'),
                            onTap: () {
                              _placeLibraryItem(item);
                              Navigator.pop(ctx);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () {
                                _removeLibraryItem(item.id);
                                Navigator.pop(ctx);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton({
    IconData? icon,
    Widget? iconWidget,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: iconWidget ??
                  Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.blue : Colors.grey.shade700,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 20,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Colors.grey.shade300,
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
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        _exportPng,
    // Ctrl variants for non-macOS platforms
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveFile,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
        _saveFileAs,
    const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openFile,
    const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
        _exportPng,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        _redo,
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
    final isLocked = style.locked == true;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            IgnorePointer(
              ignoring: isLocked,
              child: Opacity(
                opacity: isLocked ? 0.4 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Stroke'),
                    _buildColorPickerRow(
                      selected: style.strokeColor,
                      onSelect: (c) =>
                          _applyStyleChange(ElementStyle(strokeColor: c)),
                      quickPicks: _strokeQuickPicks,
                    ),
                    const SizedBox(height: 8),
                    _buildSectionLabel('Background'),
                    _buildColorPickerRow(
                      selected: style.backgroundColor,
                      onSelect: (c) =>
                          _applyStyleChange(ElementStyle(backgroundColor: c)),
                      quickPicks: _backgroundQuickPicks,
                    ),
                    const SizedBox(height: 8),
                    _buildSectionLabel('Fill style'),
                    _buildFillStyleRow(style.fillStyle),
                    const SizedBox(height: 8),
                    _buildSectionLabel('Stroke width'),
                    _buildStrokeWidthRow(style.strokeWidth),
                    const SizedBox(height: 8),
                    _buildSectionLabel('Stroke style'),
                    _buildStrokeStyleRow(style.strokeStyle),
                    const SizedBox(height: 8),
                    _buildSectionLabel('Sloppiness'),
                    _buildRoughnessRow(style.roughness),
                    if (style.hasRoundness) ...[
                      const SizedBox(height: 8),
                      _buildSectionLabel('Roundness'),
                      _buildRoundnessRow(style.roundness),
                    ],
                    if (style.hasArrows) ...[
                      const SizedBox(height: 8),
                      _buildSectionLabel('Arrow type'),
                      _buildElbowedRow(style.elbowed),
                    ],
                    if (style.hasText) ...[
                      const SizedBox(height: 12),
                      _buildSectionLabel('Font family'),
                      _buildFontFamilyRow(style.fontFamily),
                      const SizedBox(height: 8),
                      _buildSectionLabel('Font size'),
                      _buildFontSizeRow(style.fontSize),
                      const SizedBox(height: 8),
                      _buildSectionLabel('Text align'),
                      _buildTextAlignRow(style.textAlign),
                    ],
                    if (style.hasLines) ...[
                      const SizedBox(height: 8),
                      _buildArrowheadRow(
                        label: 'Start arrowhead',
                        current: style.startArrowhead,
                        isNone: style.startArrowheadNone,
                        onSelect: (a) {
                          if (a == null) {
                            _applyStyleChange(const ElementStyle(
                                hasLines: true, startArrowheadNone: true));
                          } else {
                            _applyStyleChange(ElementStyle(
                                hasLines: true, startArrowhead: a));
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      _buildArrowheadRow(
                        label: 'End arrowhead',
                        current: style.endArrowhead,
                        isNone: style.endArrowheadNone,
                        onSelect: (a) {
                          if (a == null) {
                            _applyStyleChange(const ElementStyle(
                                hasLines: true, endArrowheadNone: true));
                          } else {
                            _applyStyleChange(ElementStyle(
                                hasLines: true, endArrowhead: a));
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildSectionLabel('Opacity'),
                    _buildOpacitySlider(style.opacity),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSectionLabel('Layer order'),
            _buildLayerButtons(),
            const SizedBox(height: 8),
            _buildAlignmentButtons(elements.length),
            const SizedBox(height: 12),
            _buildLockToggle(style.locked),
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

  // Excalidraw Open Color palette — stroke uses saturated, background uses pastel
  static const _strokeQuickPicks = [
    '#1e1e1e', // black
    '#e03131', // red
    '#40c057', // green
    '#228be6', // blue
    '#fab005', // yellow
  ];

  static const _backgroundQuickPicks = [
    'transparent',
    '#ffc9c9', // red light
    '#b2f2bb', // green light
    '#a5d8ff', // blue light
    '#ffec99', // yellow light
  ];

  Widget _buildColorPickerRow({
    required String? selected,
    required ValueChanged<String> onSelect,
    required List<String> quickPicks,
  }) {
    final isQuickPick = quickPicks.contains(selected);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in quickPicks)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _ColorSwatch(
              color: c,
              isSelected: selected == c,
              onTap: () => onSelect(c),
            ),
          ),
        // Vertical separator
        Container(
          width: 1,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: Colors.grey.shade300,
        ),
        // Active-color button that opens the full palette popup
        _ColorPickerButton(
          color: selected ?? '#000000',
          isActive: !isQuickPick,
          onColorSelected: onSelect,
        ),
      ],
    );
  }

  Widget _buildStrokeWidthRow(double? current) {
    const widths = [1.0, 2.0, 4.0, 6.0];
    const displayWidths = [1.0, 2.0, 3.5, 5.0];
    const tooltips = ['Thin', 'Medium', 'Bold', 'Extra bold'];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < widths.length; i++)
          _IconToggleChip(
            isSelected: current == widths[i],
            onTap: () =>
                _applyStyleChange(ElementStyle(strokeWidth: widths[i])),
            tooltip: tooltips[i],
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _StrokeWidthIcon(displayWidths[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildStrokeStyleRow(StrokeStyle? current) {
    const styles = StrokeStyle.values;
    final names = ['solid', 'dashed', 'dotted'];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < styles.length; i++)
          _IconToggleChip(
            isSelected: current == styles[i],
            onTap: () =>
                _applyStyleChange(ElementStyle(strokeStyle: styles[i])),
            tooltip: names[i],
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _StrokeStyleIcon(names[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildFillStyleRow(FillStyle? current) {
    const styles = FillStyle.values;
    final names = ['solid', 'hachure', 'cross-hatch', 'zigzag'];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < styles.length; i++)
          _IconToggleChip(
            isSelected: current == styles[i],
            onTap: () =>
                _applyStyleChange(ElementStyle(fillStyle: styles[i])),
            tooltip: names[i],
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _FillStyleIcon(names[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildRoughnessRow(double? current) {
    const values = [0.0, 1.0, 3.0];
    const tooltips = ['Architect', 'Artist', 'Cartoonist'];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < values.length; i++)
          _IconToggleChip(
            isSelected: current == values[i],
            onTap: () =>
                _applyStyleChange(ElementStyle(roughness: values[i])),
            tooltip: tooltips[i],
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _RoughnessIcon(values[i]),
            ),
          ),
      ],
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

  Widget _buildRoundnessRow(Roundness? current) {
    final isRound = current != null;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _IconToggleChip(
          isSelected: !isRound,
          onTap: () {
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
          },
          tooltip: 'Sharp',
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _RoundnessIcon(false),
          ),
        ),
        _IconToggleChip(
          isSelected: isRound,
          onTap: () {
            _applyStyleChange(
              const ElementStyle(
                roundness: Roundness.adaptive(value: 8),
                hasRoundness: true,
              ),
            );
          },
          tooltip: 'Round',
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _RoundnessIcon(true),
          ),
        ),
      ],
    );
  }

  Widget _buildElbowedRow(bool? current) {
    final isElbowed = current ?? false;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _IconToggleChip(
          isSelected: !isElbowed,
          onTap: () {
            _historyManager.push(_editorState.scene);
            _applyStyleChange(
                const ElementStyle(hasArrows: true, elbowed: false));
          },
          tooltip: 'Sharp',
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _ArrowTypeIcon('sharp'),
          ),
        ),
        _IconToggleChip(
          isSelected: false, // round is not a distinct mode currently
          onTap: () {
            _historyManager.push(_editorState.scene);
            _applyStyleChange(
                const ElementStyle(hasArrows: true, elbowed: false));
          },
          tooltip: 'Round',
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _ArrowTypeIcon('round'),
          ),
        ),
        _IconToggleChip(
          isSelected: isElbowed,
          onTap: () {
            _historyManager.push(_editorState.scene);
            _applyStyleChange(
                const ElementStyle(hasArrows: true, elbowed: true));
          },
          tooltip: 'Elbowed',
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _ArrowTypeIcon('elbow'),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowheadRow({
    required String label,
    required Arrowhead? current,
    required bool isNone,
    required void Function(Arrowhead?) onSelect,
  }) {
    final isStart = label.toLowerCase().contains('start');
    const arrowheads = Arrowhead.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _IconToggleChip(
              isSelected: isNone,
              onTap: () => onSelect(null),
              tooltip: 'None',
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _ArrowheadIcon(null, isStart: isStart),
              ),
            ),
            for (final ah in arrowheads)
              _IconToggleChip(
                isSelected: current == ah,
                onTap: () => onSelect(ah),
                tooltip: ah.name[0].toUpperCase() + ah.name.substring(1),
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _ArrowheadIcon(ah, isStart: isStart),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayerButtons() {
    return Row(
      children: [
        Tooltip(
          message: 'Send to back (Ctrl+Shift+[)',
          child: IconButton(
            icon: const Icon(Icons.vertical_align_bottom, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              _historyManager.push(_editorState.scene);
              final ids = _editorState.selectedIds;
              final updated =
                  LayerUtils.sendToBack(_editorState.scene, ids);
              if (updated.isEmpty) return;
              _applyResult(CompoundResult([
                for (final e in updated) UpdateElementResult(e),
              ]));
            },
          ),
        ),
        Tooltip(
          message: 'Send backward (Ctrl+[)',
          child: IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              _historyManager.push(_editorState.scene);
              final ids = _editorState.selectedIds;
              final updated =
                  LayerUtils.sendBackward(_editorState.scene, ids);
              if (updated.isEmpty) return;
              _applyResult(CompoundResult([
                for (final e in updated) UpdateElementResult(e),
              ]));
            },
          ),
        ),
        Tooltip(
          message: 'Bring forward (Ctrl+])',
          child: IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              _historyManager.push(_editorState.scene);
              final ids = _editorState.selectedIds;
              final updated =
                  LayerUtils.bringForward(_editorState.scene, ids);
              if (updated.isEmpty) return;
              _applyResult(CompoundResult([
                for (final e in updated) UpdateElementResult(e),
              ]));
            },
          ),
        ),
        Tooltip(
          message: 'Bring to front (Ctrl+Shift+])',
          child: IconButton(
            icon: const Icon(Icons.vertical_align_top, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              _historyManager.push(_editorState.scene);
              final ids = _editorState.selectedIds;
              final updated =
                  LayerUtils.bringToFront(_editorState.scene, ids);
              if (updated.isEmpty) return;
              _applyResult(CompoundResult([
                for (final e in updated) UpdateElementResult(e),
              ]));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlignmentButtons(int selectedCount) {
    if (selectedCount < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Align'),
        Wrap(
          spacing: 4,
          children: [
            _alignButton(Icons.align_horizontal_left, 'Align left',
                AlignmentUtils.alignLeft),
            _alignButton(Icons.align_horizontal_center, 'Align center H',
                AlignmentUtils.alignCenterH),
            _alignButton(Icons.align_horizontal_right, 'Align right',
                AlignmentUtils.alignRight),
            _alignButton(Icons.align_vertical_top, 'Align top',
                AlignmentUtils.alignTop),
            _alignButton(Icons.align_vertical_center, 'Align center V',
                AlignmentUtils.alignCenterV),
            _alignButton(Icons.align_vertical_bottom, 'Align bottom',
                AlignmentUtils.alignBottom),
          ],
        ),
        if (selectedCount >= 3) ...[
          const SizedBox(height: 4),
          _buildSectionLabel('Distribute'),
          Wrap(
            spacing: 4,
            children: [
              _alignButton(Icons.horizontal_distribute, 'Distribute H',
                  AlignmentUtils.distributeH),
              _alignButton(Icons.vertical_distribute, 'Distribute V',
                  AlignmentUtils.distributeV),
            ],
          ),
        ],
      ],
    );
  }

  Widget _alignButton(
    IconData icon,
    String tooltip,
    List<Element> Function(List<Element>) operation,
  ) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        onPressed: () {
          final elements = _selectedElements;
          if (elements.isEmpty) return;
          _historyManager.push(_editorState.scene);
          final updated = operation(elements);
          if (updated.isEmpty) return;
          _applyResult(CompoundResult([
            for (final e in updated) UpdateElementResult(e),
          ]));
        },
      ),
    );
  }

  Widget _buildLockToggle(bool? current) {
    return Row(
      children: [
        Icon(
          current == true ? Icons.lock : Icons.lock_open,
          size: 16,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 4),
        const Text('Locked', style: TextStyle(fontSize: 12)),
        const Spacer(),
        Switch(
          value: current ?? false,
          onChanged: (on) {
            _historyManager.push(_editorState.scene);
            final elements = _selectedElements;
            if (elements.isEmpty) return;
            final results = <ToolResult>[
              for (final e in elements)
                UpdateElementResult(e.copyWith(locked: on)),
            ];
            _applyResult(
              results.length == 1 ? results.first : CompoundResult(results),
            );
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
    const families = ['Excalifont', 'Nunito', 'Lilita One', 'Virgil'];
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
    final fontFamily = textElem?.fontFamily ?? 'Excalifont';
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
          child: Transform.rotate(
            angle: parent.angle,
            alignment: Alignment.center,
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
                        style: FontResolver.resolve(
                          fontFamily,
                          baseStyle: TextStyle(
                            fontSize: fontSize,
                            color: textColor,
                            height: lineHeight,
                          ),
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
          ),
        );
      }
    }

    // Standalone text: position at element's center, rotate around center
    final centerScene = Offset(
      element.x + element.width / 2,
      element.y + element.height / 2,
    );
    final screenCenter = _editorState.viewport.sceneToScreen(centerScene);

    return Positioned(
      left: screenCenter.dx,
      top: screenCenter.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: element.angle,
          alignment: Alignment.center,
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
                    style: FontResolver.resolve(
                      fontFamily,
                      baseStyle: TextStyle(
                        fontSize: fontSize,
                        color: textColor,
                        height: lineHeight,
                      ),
                    ),
                    cursorColor: Colors.blue,
                    backgroundCursorColor: Colors.grey,
                    selectionColor: Colors.blue.shade300.withValues(alpha: 0.5),
                    onChanged: (_) => _onTextChanged(),
                    onSubmitted: (_) => _commitTextEditing(),
                  ),
                ),
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
        _redo();
      } else {
        _undo();
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

    // Tool lock toggle (Q, no modifiers)
    if (!ctrl && !shift && key == LogicalKeyboardKey.keyQ) {
      setState(() {
        _toolLocked = !_toolLocked;
        _editorState = _editorState.copyWith(toolLocked: _toolLocked);
        if (!_toolLocked) {
          _switchTool(ToolType.select);
        }
      });
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

  bool _isDraggingPointHandle() {
    return _activeTool is SelectTool &&
        (_activeTool as SelectTool).isDraggingPoint;
  }

  List<Point>? _buildPointHandles() {
    if (_editorState.selectedIds.length != 1) return null;
    final elem = _editorState.scene.getElementById(
      _editorState.selectedIds.first,
    );
    if (elem == null) return null;
    if (elem is LineElement) {
      return elem.points
          .map((p) => Point(elem.x + p.x, elem.y + p.y))
          .toList();
    }
    return null;
  }

  SelectionOverlay? _buildSelectionOverlay() {
    if (_editorState.selectedIds.isEmpty) return null;
    final selected = _editorState.selectedIds
        .map((id) => _editorState.scene.getElementById(id))
        .whereType<Element>()
        .toList();
    if (selected.isEmpty) return null;
    return SelectionOverlay.fromElements(selected, mode: _interactionMode);
  }

  Widget _iconWidgetFor(ToolType type, {Color? color, double? size}) {
    final s = size ?? 24;
    if (type == ToolType.diamond) {
      return CustomPaint(
        size: Size(s, s),
        painter: _DiamondIconPainter(color: color ?? Colors.grey.shade800),
      );
    }
    return Icon(_iconFor(type), color: color, size: s);
  }

  IconData _iconFor(ToolType type) {
    return switch (type) {
      ToolType.select => Icons.near_me,
      ToolType.rectangle => Icons.rectangle_outlined,
      ToolType.ellipse => Icons.circle_outlined,
      ToolType.diamond => Icons.square_outlined,
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
    // Light colors get a gray outline for visibility (like Excalidraw)
    final isLight =
        !isTransparent && (parsed.r + parsed.g + parsed.b) > 1.8;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isTransparent ? Colors.white : parsed,
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isLight || isTransparent)
                    ? Colors.grey.shade400
                    : Colors.transparent,
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

/// The 6th swatch that shows the active color and opens a full palette popup.
class _ColorPickerButton extends StatelessWidget {
  final String color;
  final bool isActive;
  final ValueChanged<String> onColorSelected;

  const _ColorPickerButton({
    required this.color,
    required this.isActive,
    required this.onColorSelected,
  });

  static const _paletteColors = [
    ['#f8f9fa', '#e9ecef', '#ced4da', '#868e96', '#343a40'],
    ['#fff5f5', '#ffc9c9', '#ff8787', '#fa5252', '#e03131'],
    ['#fff0f6', '#fcc2d7', '#f783ac', '#e64980', '#c2255c'],
    ['#f8f0fc', '#eebefa', '#da77f2', '#be4bdb', '#9c36b5'],
    ['#f3f0ff', '#d0bfff', '#9775fa', '#7950f2', '#6741d9'],
    ['#e7f5ff', '#a5d8ff', '#4dabf7', '#228be6', '#1971c2'],
    ['#e3fafc', '#99e9f2', '#3bc9db', '#15aabf', '#0c8599'],
    ['#e6fcf5', '#96f2d7', '#38d9a9', '#12b886', '#099268'],
    ['#ebfbee', '#b2f2bb', '#69db7c', '#40c057', '#2f9e44'],
    ['#fff9db', '#ffec99', '#ffd43b', '#fab005', '#f08c00'],
    ['#fff4e6', '#ffd8a8', '#ffa94d', '#fd7e14', '#e8590c'],
    ['#f8f1ee', '#eaddd7', '#d2bab0', '#a18072', '#846358'],
  ];

  @override
  Widget build(BuildContext context) {
    final parsed = _parseColor(color);
    final isTransparent = color == 'transparent';
    final isLight =
        !isTransparent && (parsed.r + parsed.g + parsed.b) > 1.8;
    return GestureDetector(
      onTap: () => _showPalettePopup(context),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isTransparent ? Colors.white : parsed,
          border: Border.all(
            color: isActive
                ? Colors.blue
                : (isLight || isTransparent)
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: isTransparent
            ? CustomPaint(painter: _DiagonalLinePainter())
            : null,
      ),
    );
  }

  void _showPalettePopup(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ColorPaletteOverlay(
        anchor: offset,
        currentColor: color,
        onSelect: (c) {
          entry.remove();
          onColorSelected(c);
        },
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

/// Full-palette popup overlay with grid + transparent + hex input.
class _ColorPaletteOverlay extends StatefulWidget {
  final Offset anchor;
  final String currentColor;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const _ColorPaletteOverlay({
    required this.anchor,
    required this.currentColor,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ColorPaletteOverlay> createState() => _ColorPaletteOverlayState();
}

class _ColorPaletteOverlayState extends State<_ColorPaletteOverlay> {
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: widget.currentColor == 'transparent' ? '' : widget.currentColor,
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const swatchSize = 24.0;
    const spacing = 3.0;
    const cols = 5;
    const rows = 12;
    const popupWidth = cols * (swatchSize + spacing) + spacing + 24;
    const popupHeight = (rows + 1) * (swatchSize + spacing) + spacing + 60;

    // Position popup below the anchor button, clamped to screen
    final screen = MediaQuery.of(context).size;
    var left = widget.anchor.dx - popupWidth / 2 + 14;
    var top = widget.anchor.dy + 34;
    if (left + popupWidth > screen.width - 8) {
      left = screen.width - popupWidth - 8;
    }
    if (left < 8) left = 8;
    if (top + popupHeight > screen.height - 8) {
      top = widget.anchor.dy - popupHeight - 4;
    }

    return Stack(
      children: [
        // Dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transparent swatch
                  GestureDetector(
                    onTap: () => widget.onSelect('transparent'),
                    child: Container(
                      width: swatchSize,
                      height: swatchSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: widget.currentColor == 'transparent'
                              ? Colors.blue
                              : Colors.grey.shade400,
                          width:
                              widget.currentColor == 'transparent' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: CustomPaint(painter: _DiagonalLinePainter()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Palette grid: 12 hue rows x 5 shades
                  for (final row in _ColorPickerButton._paletteColors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spacing),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final hex in row)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: spacing),
                              child: _buildGridSwatch(hex, swatchSize),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Hex input
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        hintText: '#rrggbb',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (value) {
                        final hex = value.trim();
                        if (_isValidHex(hex)) {
                          widget.onSelect(hex);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridSwatch(String hex, double size) {
    final parsed = _parseColor(hex);
    final isLight = (parsed.r + parsed.g + parsed.b) > 1.8;
    final isSelected =
        widget.currentColor.toLowerCase() == hex.toLowerCase();
    return GestureDetector(
      onTap: () => widget.onSelect(hex),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: parsed,
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : isLight
                    ? Colors.grey.shade300
                    : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  bool _isValidHex(String value) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6) return false;
    return int.tryParse(hex, radix: 16) != null;
  }
}

class _DiamondIconPainter extends CustomPainter {
  final Color color;
  _DiamondIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Matches Excalidraw's Tabler "square-rotated" icon:
    // a rounded square rotated 45°.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.58; // side length of inner square
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        const Radius.circular(2.5),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiamondIconPainter old) => old.color != color;
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

class _IconToggleChip extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconToggleChip({
    required this.child,
    required this.isSelected,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: child),
      ),
    );
    if (tooltip != null) {
      chip = Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

class _FillStyleIcon extends CustomPainter {
  final String style;
  _FillStyleIcon(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawRect(rect, paint);

    final fillPaint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.0;
    switch (style) {
      case 'solid':
        canvas.drawRect(rect, fillPaint..style = PaintingStyle.fill);
      case 'hachure':
        canvas.save();
        canvas.clipRect(rect);
        for (var x = -size.height; x < size.width; x += 4) {
          canvas.drawLine(
            Offset(rect.left + x, rect.bottom),
            Offset(rect.left + x + rect.height, rect.top),
            fillPaint..style = PaintingStyle.stroke,
          );
        }
        canvas.restore();
      case 'cross-hatch':
        canvas.save();
        canvas.clipRect(rect);
        for (var x = -size.height; x < size.width; x += 4) {
          canvas.drawLine(
            Offset(rect.left + x, rect.bottom),
            Offset(rect.left + x + rect.height, rect.top),
            fillPaint..style = PaintingStyle.stroke,
          );
          canvas.drawLine(
            Offset(rect.left + x, rect.top),
            Offset(rect.left + x + rect.height, rect.bottom),
            fillPaint..style = PaintingStyle.stroke,
          );
        }
        canvas.restore();
      case 'zigzag':
        canvas.save();
        canvas.clipRect(rect);
        final path = Path();
        for (var x = rect.left; x < rect.right; x += 6) {
          path.moveTo(x, rect.top);
          var y = rect.top;
          var goRight = true;
          while (y < rect.bottom) {
            final nx = goRight ? x + 3 : x;
            final ny = y + 3;
            path.lineTo(nx, ny);
            y = ny;
            goRight = !goRight;
          }
        }
        canvas.drawPath(path, fillPaint..style = PaintingStyle.stroke);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FillStyleIcon old) => old.style != style;
}

class _StrokeWidthIcon extends CustomPainter {
  final double width;
  _StrokeWidthIcon(this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
  }

  @override
  bool shouldRepaint(_StrokeWidthIcon old) => old.width != width;
}

class _StrokeStyleIcon extends CustomPainter {
  final String style;
  _StrokeStyleIcon(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    switch (style) {
      case 'solid':
        canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
      case 'dashed':
        final path = Path();
        var x = 4.0;
        while (x < size.width - 4) {
          path.moveTo(x, y);
          path.lineTo(math.min(x + 5, size.width - 4), y);
          x += 8;
        }
        canvas.drawPath(path, paint);
      case 'dotted':
        var x = 5.0;
        while (x < size.width - 4) {
          canvas.drawCircle(Offset(x, y), 1.0, paint..style = PaintingStyle.fill);
          x += 5;
        }
    }
  }

  @override
  bool shouldRepaint(_StrokeStyleIcon old) => old.style != style;
}

class _RoughnessIcon extends CustomPainter {
  final double roughness;
  _RoughnessIcon(this.roughness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    final path = Path();
    path.moveTo(4, y);
    if (roughness < 0.5) {
      // Architect: clean straight line
      path.lineTo(size.width - 4, y);
    } else if (roughness < 2.0) {
      // Artist: slightly wobbly
      final w = size.width - 8;
      for (var i = 0; i <= 8; i++) {
        final t = i / 8.0;
        final offset = math.sin(t * math.pi * 3) * 2.0;
        path.lineTo(4 + w * t, y + offset);
      }
    } else {
      // Cartoonist: very wobbly
      final w = size.width - 8;
      for (var i = 0; i <= 12; i++) {
        final t = i / 12.0;
        final offset = math.sin(t * math.pi * 5) * 3.5;
        path.lineTo(4 + w * t, y + offset);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoughnessIcon old) => old.roughness != roughness;
}

class _RoundnessIcon extends CustomPainter {
  final bool rounded;
  _RoundnessIcon(this.rounded);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (rounded) {
      path.moveTo(size.width - 6, 6);
      path.lineTo(size.width - 6, 12);
      path.quadraticBezierTo(size.width - 6, size.height - 6, 12, size.height - 6);
      path.lineTo(6, size.height - 6);
    } else {
      path.moveTo(size.width - 6, 6);
      path.lineTo(size.width - 6, size.height - 6);
      path.lineTo(6, size.height - 6);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoundnessIcon old) => old.rounded != rounded;
}

class _ArrowTypeIcon extends CustomPainter {
  final String type; // 'sharp', 'round', 'elbow'
  _ArrowTypeIcon(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    switch (type) {
      case 'sharp':
        // Angled line from bottom-left to top-right via midpoint
        path.moveTo(5, size.height - 5);
        path.lineTo(size.width / 2, 8);
        path.lineTo(size.width - 5, size.height - 5);
      case 'round':
        // Curved path
        path.moveTo(5, size.height - 5);
        path.quadraticBezierTo(size.width / 2, 2, size.width - 5, size.height - 5);
      case 'elbow':
        // Right-angle path
        path.moveTo(5, size.height - 5);
        path.lineTo(5, 8);
        path.lineTo(size.width - 5, 8);
        path.lineTo(size.width - 5, size.height - 5);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowTypeIcon old) => old.type != type;
}

class _ArrowheadIcon extends CustomPainter {
  final Arrowhead? arrowhead;
  final bool isStart;

  _ArrowheadIcon(this.arrowhead, {this.isStart = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e1e1e)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cy = size.height / 2;

    // Line endpoints: tip is the arrowhead end
    final double lineStart;
    final double lineEnd;
    if (isStart) {
      lineStart = size.width - 4;
      lineEnd = 4;
    } else {
      lineStart = 4;
      lineEnd = size.width - 4;
    }

    // Draw the shaft
    canvas.drawLine(Offset(lineStart, cy), Offset(lineEnd, cy), paint);

    if (arrowhead == null) return;

    // Draw arrowhead at lineEnd
    final tipX = lineEnd;
    final dir = isStart ? 1.0 : -1.0; // direction back along shaft

    switch (arrowhead!) {
      case Arrowhead.arrow:
        // Open chevron
        final path = Path()
          ..moveTo(tipX + dir * 5, cy - 4)
          ..lineTo(tipX, cy)
          ..lineTo(tipX + dir * 5, cy + 4);
        canvas.drawPath(path, paint);
      case Arrowhead.bar:
        // Perpendicular bar
        canvas.drawLine(Offset(tipX, cy - 4), Offset(tipX, cy + 4), paint);
      case Arrowhead.dot:
        // Filled circle
        canvas.drawCircle(
            Offset(tipX, cy), 3, paint..style = PaintingStyle.fill);
      case Arrowhead.triangle:
        // Filled triangle
        final path = Path()
          ..moveTo(tipX, cy)
          ..lineTo(tipX + dir * 6, cy - 4)
          ..lineTo(tipX + dir * 6, cy + 4)
          ..close();
        canvas.drawPath(path, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_ArrowheadIcon old) =>
      old.arrowhead != arrowhead || old.isStart != isStart;
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
