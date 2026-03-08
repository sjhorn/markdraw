library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter/services.dart';

import 'package:markdraw/markdraw.dart' as core show TextAlign;
import 'package:markdraw/markdraw.dart' hide TextAlign;


/// Which color picker to open programmatically.
enum ColorPickerTarget { stroke, background, font }

/// Controller for [MarkdrawEditor]. Holds all editor state and logic.
///
/// Can be created internally by the widget or provided externally
/// (like [TextEditingController]).
class MarkdrawController extends ChangeNotifier {
  MarkdrawController({
    MarkdrawEditorConfig config = const MarkdrawEditorConfig(),
  }) : _config = config {
    _editorState = EditorState(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
      activeToolType: ToolType.select,
    );
    _activeTool = createTool(ToolType.select);
    _defaultStyle = config.initialStyle;
    _canvasBackgroundColor = config.initialBackground;

    _textFocusNode.addListener(_onTextFocusChanged);

    _imageCache.onImageDecoded = () {
      notifyListeners();
    };
  }

  final MarkdrawEditorConfig _config;

  // Core state
  late EditorState _editorState;
  late Tool _activeTool;
  final _adapter = RoughCanvasAdapter();
  final _historyManager = HistoryManager();
  final ClipboardService _clipboardService = const FlutterClipboardService();
  final _imageCache = ImageElementCache();

  // UI state
  List<LibraryItem> _libraryItems = [];
  bool _showLibraryPanel = false;
  bool _showMarkdownPanel = false;
  bool _toolLocked = false;
  bool _isCompact = false;
  bool _isEditingLinear = false;
  bool _fontPickerOpen = false;
  bool _zenMode = false;
  bool _viewMode = false;
  ToolType? _toolBeforeViewMode;
  ColorPickerTarget? _pendingColorPicker;
  ElementStyle _defaultStyle = const ElementStyle();
  String _canvasBackgroundColor = '#ffffff';
  int? _gridSize;

  // Copied style for paste-style
  ElementStyle? _copiedStyle;

  // Drag coalescing
  Scene? _sceneBeforeDrag;

  // Double-click detection
  DateTime? _lastPointerUpTime;

  // Focus management
  final keyboardFocusNode = FocusNode();

  // Text editing state
  ElementId? _editingTextElementId;
  final textEditingController = TextEditingController();
  final _textFocusNode = FocusNode();
  final editableTextKey = GlobalKey<EditableTextState>();
  bool _isEditingExisting = false;
  String? _originalText;
  bool _suppressFocusCommit = false;

  // Mouse position for eraser cursor
  Offset? _mousePosition;

  // Pinch-to-zoom state
  double _pinchStartZoom = 1.0;
  Offset _pinchStartOffset = Offset.zero;

  // Callbacks set by the widget
  VoidCallback? onThemeToggle;
  void Function(Scene)? onSceneChanged;

  // --- Public getters ---

  EditorState get editorState => _editorState;
  Tool get activeTool => _activeTool;
  RoughAdapter get adapter => _adapter;
  HistoryManager get historyManager => _historyManager;
  ImageElementCache get imageCache => _imageCache;
  MarkdrawEditorConfig get config => _config;

  List<LibraryItem> get libraryItems => _libraryItems;
  bool get showLibraryPanel => _showLibraryPanel;
  bool get showMarkdownPanel => _showMarkdownPanel;
  bool get toolLocked => _toolLocked;
  bool get isCompact => _isCompact;
  bool get isEditingLinear => _isEditingLinear;
  bool get fontPickerOpen => _fontPickerOpen;
  ElementStyle get defaultStyle => _defaultStyle;
  String get canvasBackgroundColor => _canvasBackgroundColor;
  int? get gridSize => _gridSize;
  ElementStyle? get copiedStyle => _copiedStyle;
  bool get zenMode => _zenMode;
  bool get viewMode => _viewMode;
  ColorPickerTarget? get pendingColorPicker => _pendingColorPicker;

  ElementId? get editingTextElementId => _editingTextElementId;
  FocusNode get textFocusNode => _textFocusNode;
  bool get isEditingExisting => _isEditingExisting;
  String? get originalText => _originalText;
  bool get suppressFocusCommit => _suppressFocusCommit;
  Offset? get mousePosition => _mousePosition;
  double get pinchStartZoom => _pinchStartZoom;
  Offset get pinchStartOffset => _pinchStartOffset;

  InteractionMode get interactionMode =>
      _isCompact ? InteractionMode.touch : InteractionMode.pointer;

  bool get isCreationTool => switch (_editorState.activeToolType) {
    ToolType.select ||
    ToolType.hand ||
    ToolType.eraser ||
    ToolType.laser ||
    ToolType.eyedropper => false,
    _ => true,
  };

  ToolContext get toolContext => ToolContext(
    scene: _editorState.scene,
    viewport: _editorState.viewport,
    selectedIds: _editorState.selectedIds,
    clipboard: _editorState.clipboard,
    interactionMode: interactionMode,
    isEditingLinear: _isEditingLinear,
    gridSize: _gridSize,
  );

  List<Element> get selectedElements {
    return _editorState.selectedIds
        .map((id) => _editorState.scene.getElementById(id))
        .whereType<Element>()
        .toList();
  }

  MouseCursor get cursorForTool {
    return switch (_editorState.activeToolType) {
      ToolType.select || ToolType.hand => SystemMouseCursors.basic,
      ToolType.eraser => SystemMouseCursors.none,
      ToolType.laser => SystemMouseCursors.precise,
      ToolType.eyedropper => SystemMouseCursors.precise,
      _ => SystemMouseCursors.precise,
    };
  }

  // --- Public setters ---

  set isCompact(bool value) {
    if (_isCompact != value) {
      _isCompact = value;
      notifyListeners();
    }
  }

  set showLibraryPanel(bool value) {
    _showLibraryPanel = value;
    notifyListeners();
  }

  set fontPickerOpen(bool value) {
    _fontPickerOpen = value;
    notifyListeners();
  }

  set isEditingLinear(bool value) {
    _isEditingLinear = value;
    notifyListeners();
  }

  set canvasBackgroundColor(String value) {
    _canvasBackgroundColor = value;
    notifyListeners();
  }

  set mousePosition(Offset? value) {
    _mousePosition = value;
    // Don't notify — handled by setState in the widget
  }

  set suppressFocusCommit(bool value) {
    _suppressFocusCommit = value;
  }

  // --- Lifecycle ---

  @override
  void dispose() {
    _imageCache.dispose();
    keyboardFocusNode.dispose();
    textEditingController.dispose();
    _textFocusNode.removeListener(_onTextFocusChanged);
    _textFocusNode.dispose();
    super.dispose();
  }

  // --- Tool management ---

  void switchTool(ToolType type) {
    // In view mode, only the hand tool is allowed
    if (_viewMode && type != ToolType.hand) return;
    _activeTool.reset();
    _activeTool = createTool(type);
    _editorState = _editorState.copyWith(
      activeToolType: type,
      selectedIds: type == ToolType.select ? null : {},
    );
    cancelTextEditing();
    keyboardFocusNode.requestFocus();
    notifyListeners();
  }

  // --- Undo/Redo ---

  void undo() {
    final undone = _historyManager.undo(_editorState.scene);
    if (undone != null) {
      _editorState = _editorState.copyWith(scene: undone);
      onSceneChanged?.call(_editorState.scene);
      notifyListeners();
    }
  }

  void redo() {
    final redone = _historyManager.redo(_editorState.scene);
    if (redone != null) {
      _editorState = _editorState.copyWith(scene: redone);
      onSceneChanged?.call(_editorState.scene);
      notifyListeners();
    }
  }

  // --- Zoom ---

  void zoomIn(Size canvasSize) {
    final viewport = _editorState.viewport;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final newZoom = (viewport.zoom + _config.zoomStep)
        .clamp(_config.minZoom, _config.maxZoom);
    final factor = newZoom / viewport.zoom;
    applyResult(UpdateViewportResult(
      viewport.zoomAt(factor, center,
          minZoom: _config.minZoom, maxZoom: _config.maxZoom),
    ));
  }

  void zoomOut(Size canvasSize) {
    final viewport = _editorState.viewport;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final newZoom = (viewport.zoom - _config.zoomStep)
        .clamp(_config.minZoom, _config.maxZoom);
    final factor = newZoom / viewport.zoom;
    applyResult(UpdateViewportResult(
      viewport.zoomAt(factor, center,
          minZoom: _config.minZoom, maxZoom: _config.maxZoom),
    ));
  }

  void resetZoom() {
    applyResult(UpdateViewportResult(const ViewportState()));
  }

  void zoomToFit(Size canvasSize) {
    final bounds = ExportBounds.compute(_editorState.scene);
    if (bounds == null) return;
    applyResult(UpdateViewportResult(
      _editorState.viewport.fitToBounds(bounds, canvasSize, padding: 40),
    ));
  }

  void zoomToSelection(Size canvasSize) {
    if (_editorState.selectedIds.isEmpty) return;
    final bounds = ExportBounds.compute(
      _editorState.scene,
      selectedIds: _editorState.selectedIds,
    );
    if (bounds == null) return;
    applyResult(UpdateViewportResult(
      _editorState.viewport.fitToBounds(bounds, canvasSize, padding: 40),
    ));
  }

  // --- Default style application ---

  Element applyDefaultStyleToElement(Element element) {
    Element styled = element.copyWith(
      strokeColor: _defaultStyle.strokeColor,
      backgroundColor: _defaultStyle.backgroundColor,
      strokeWidth: _defaultStyle.strokeWidth,
      strokeStyle: _defaultStyle.strokeStyle,
      fillStyle: _defaultStyle.fillStyle,
      roughness: _defaultStyle.roughness,
      opacity: _defaultStyle.opacity,
    );
    if (styled is TextElement) {
      styled = styled.copyWithText(
        fontSize: _defaultStyle.fontSize,
        fontFamily: _defaultStyle.fontFamily,
        textAlign: _defaultStyle.textAlign,
      );
    }
    if (styled is LineElement) {
      styled = styled.copyWithLine(
        startArrowhead: _defaultStyle.startArrowhead,
        clearStartArrowhead: _defaultStyle.startArrowheadNone,
        endArrowhead: _defaultStyle.endArrowhead,
        clearEndArrowhead: _defaultStyle.endArrowheadNone,
      );
    }
    if (styled is ArrowElement) {
      styled = styled.copyWithArrow(arrowType: _defaultStyle.arrowType);
    }
    if (_defaultStyle.roundness != null &&
        (styled is RectangleElement || styled is DiamondElement)) {
      final r = styled is DiamondElement
          ? Roundness.proportional(value: _defaultStyle.roundness!.value)
          : Roundness.adaptive(value: _defaultStyle.roundness!.value);
      styled = styled.copyWith(roundness: r);
    }
    return styled;
  }

  ToolResult _applyDefaultStyleToResult(ToolResult result) {
    if (result is AddElementResult) {
      return AddElementResult(applyDefaultStyleToElement(result.element));
    }
    if (result is CompoundResult) {
      return CompoundResult(
        result.results.map(_applyDefaultStyleToResult).toList(),
      );
    }
    return result;
  }

  // --- Result application ---

  void applyResult(ToolResult? result) {
    if (result == null) return;

    final styled = isCreationTool
        ? _applyDefaultStyleToResult(result)
        : result;

    _syncToSystemClipboard(styled);

    if (_isEditingLinear && _containsSelectionChange(styled)) {
      _isEditingLinear = false;
    }

    final newState = _editorState.applyResult(styled);
    if (newState.activeToolType != _editorState.activeToolType) {
      final previousToolType = _editorState.activeToolType;
      _activeTool.reset();
      _activeTool = createTool(newState.activeToolType);

      if (previousToolType == ToolType.text) {
        _startTextEditing(newState);
      }
    }
    _editorState = newState;

    if (isSceneChangingResult(styled)) {
      onSceneChanged?.call(_editorState.scene);
    }

    notifyListeners();
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

  bool _containsSelectionChange(ToolResult result) {
    if (result is SetSelectionResult) return true;
    if (result is CompoundResult) {
      return result.results.any(_containsSelectionChange);
    }
    return false;
  }

  // --- Text editing ---

  void _startTextEditing(EditorState state) {
    if (state.selectedIds.length != 1) return;
    final id = state.selectedIds.first;
    final element = state.scene.getElementById(id);
    if (element == null || element.type != 'text') return;

    _editingTextElementId = id;
    _isEditingExisting = false;
    _originalText = null;
    textEditingController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void startTextEditingExisting(TextElement element) {
    _historyManager.push(_editorState.scene);
    _editingTextElementId = element.id;
    _isEditingExisting = true;
    _originalText = element.text;
    textEditingController.text = element.text;
    textEditingController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: element.text.length,
    );
    _editorState =
        _editorState.applyResult(SetSelectionResult({element.id}));
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void startBoundTextEditing(Element shape) {
    _historyManager.push(_editorState.scene);
    final existing = _editorState.scene.findBoundText(shape.id);
    if (existing != null) {
      _editingTextElementId = existing.id;
      _isEditingExisting = true;
      _originalText = existing.text;
      textEditingController.text = existing.text;
      textEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: existing.text.length,
      );
    } else {
      final newTextId = ElementId.generate();
      final textElem = TextElement(
        id: newTextId,
        x: shape.x,
        y: shape.y,
        width: shape.width,
        height: shape.height,
        text: '',
        containerId: shape.id.value,
        textAlign: core.TextAlign.center,
      );
      _editorState = _editorState.applyResult(AddElementResult(textElem));
      final newBound = [
        ...shape.boundElements,
        BoundElement(id: newTextId.value, type: 'text'),
      ];
      _editorState = _editorState.applyResult(
        UpdateElementResult(shape.copyWith(boundElements: newBound)),
      );
      _editingTextElementId = newTextId;
      _isEditingExisting = false;
      _originalText = null;
      textEditingController.text = '';
    }
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void startArrowLabelEditing(ArrowElement arrow) {
    _historyManager.push(_editorState.scene);
    final existing = _editorState.scene.findBoundText(arrow.id);
    if (existing != null) {
      _editingTextElementId = existing.id;
      _isEditingExisting = true;
      _originalText = existing.text;
      textEditingController.text = existing.text;
      textEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: existing.text.length,
      );
    } else {
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
        textAlign: core.TextAlign.center,
      );
      _editorState = _editorState.applyResult(AddElementResult(textElem));
      final newBound = [
        ...arrow.boundElements,
        BoundElement(id: newTextId.value, type: 'text'),
      ];
      _editorState = _editorState.applyResult(
        UpdateElementResult(arrow.copyWith(boundElements: newBound)),
      );
      _editingTextElementId = newTextId;
      _isEditingExisting = false;
      _originalText = null;
      textEditingController.text = '';
    }
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
    });
  }

  void _onTextFocusChanged() {
    if (!_textFocusNode.hasFocus &&
        _editingTextElementId != null &&
        !_suppressFocusCommit) {
      commitTextEditing();
    }
  }

  void commitTextEditing() {
    final id = _editingTextElementId;
    if (id == null) return;

    final text = textEditingController.text.trim();
    if (text.isEmpty) {
      final element = _editorState.scene.getElementById(id);
      _editorState = _editorState.applyResult(RemoveElementResult(id));
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
        final measured = element.copyWithText(text: text);
        final isBound = element.containerId != null;
        if (isBound) {
          _editorState = _editorState.applyResult(
            UpdateElementResult(measured),
          );
        } else if (!element.autoResize && element.width > 0) {
          final (_, h) = TextRenderer.measure(
            measured,
            maxWidth: element.width,
          );
          final updated = measured.copyWith(
            height: math.max(h, element.height),
          );
          _editorState = _editorState.applyResult(
            UpdateElementResult(updated),
          );
        } else {
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
    textEditingController.clear();
    keyboardFocusNode.requestFocus();
    onSceneChanged?.call(_editorState.scene);
    notifyListeners();
  }

  void cancelTextEditing() {
    if (_editingTextElementId != null) {
      if (_isEditingExisting && _originalText != null) {
        final element = _editorState.scene.getElementById(
          _editingTextElementId!,
        );
        if (element is TextElement) {
          _editorState = _editorState.applyResult(
            UpdateElementResult(element.copyWithText(text: _originalText!)),
          );
        }
      } else {
        final element = _editorState.scene.getElementById(
          _editingTextElementId!,
        );
        _editorState = _editorState.applyResult(
          RemoveElementResult(_editingTextElementId!),
        );
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
      textEditingController.clear();
      notifyListeners();
    }
  }

  void onTextChanged() {
    final id = _editingTextElementId;
    if (id == null) return;
    final element = _editorState.scene.getElementById(id);
    if (element is! TextElement) return;

    final text = textEditingController.text;
    final measured = element.copyWithText(text: text);
    final isBound = element.containerId != null;
    if (isBound) {
      _editorState =
          _editorState.applyResult(UpdateElementResult(measured));
    } else if (!element.autoResize && element.width > 0) {
      final (_, h) =
          TextRenderer.measure(measured, maxWidth: element.width);
      final updated =
          measured.copyWith(height: math.max(h, element.height));
      _editorState =
          _editorState.applyResult(UpdateElementResult(updated));
    } else {
      final (w, h) = TextRenderer.measure(measured);
      final updated = measured.copyWith(
        width: math.max(w + 4, 20.0),
        height: math.max(h, element.fontSize * element.lineHeight),
      );
      _editorState =
          _editorState.applyResult(UpdateElementResult(updated));
    }
    onSceneChanged?.call(_editorState.scene);
    notifyListeners();
  }

  // --- Library ---

  void addToLibrary() {
    final selected = selectedElements;
    if (selected.isEmpty) return;

    final name = 'Item ${_libraryItems.length + 1}';
    final item = LibraryUtils.createFromElements(
      elements: selected,
      name: name,
      allSceneElements: _editorState.scene.activeElements,
      sceneFiles: _editorState.scene.files,
    );
    _libraryItems = [..._libraryItems, item];
    _showLibraryPanel = true;
    notifyListeners();
  }

  void placeLibraryItem(LibraryItem item, Size screenSize) {
    final centerScene = _editorState.viewport.screenToScene(
      Offset(screenSize.width / 2, screenSize.height / 2),
    );
    final position = Point(centerScene.dx, centerScene.dy);

    _historyManager.push(_editorState.scene);
    applyResult(LibraryUtils.instantiate(item: item, position: position));
  }

  void removeLibraryItem(String id) {
    _libraryItems = _libraryItems.where((i) => i.id != id).toList();
    notifyListeners();
  }

  set libraryItems(List<LibraryItem> items) {
    _libraryItems = items;
    notifyListeners();
  }

  // --- Viewport ---

  Map<String, ui.Image>? resolveImages() {
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

  Point toScene(Offset screenPos) {
    final scene = _editorState.viewport.screenToScene(screenPos);
    return Point(scene.dx, scene.dy);
  }

  // --- Pointer handling ---

  void onPointerDown(Offset localPosition) {
    keyboardFocusNode.requestFocus();
    if (_editingTextElementId != null) {
      commitTextEditing();
    }
    _sceneBeforeDrag = _editorState.scene;
    final point = toScene(localPosition);
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_activeTool is SelectTool) {
      applyResult(
        (_activeTool as SelectTool).onPointerDown(
          point,
          toolContext,
          shift: shift,
        ),
      );
    } else {
      applyResult(_activeTool.onPointerDown(point, toolContext));
    }
  }

  void onPointerMove(Offset localPosition, Offset delta) {
    final point = toScene(localPosition);
    applyResult(
      _activeTool.onPointerMove(
        point,
        toolContext,
        screenDelta: Offset(delta.dx, delta.dy),
      ),
    );
    _mousePosition = localPosition;
    notifyListeners();
  }

  void onPointerUp(Offset localPosition) {
    final point = toScene(localPosition);
    final now = DateTime.now();
    final isDoubleClick = _lastPointerUpTime != null &&
        now.difference(_lastPointerUpTime!).inMilliseconds < 300;
    _lastPointerUpTime = now;

    if (_activeTool is LineTool) {
      applyResult(
        (_activeTool as LineTool).onPointerUp(
          point,
          toolContext,
          isDoubleClick: isDoubleClick,
        ),
      );
    } else if (_activeTool is ArrowTool) {
      applyResult(
        (_activeTool as ArrowTool).onPointerUp(
          point,
          toolContext,
          isDoubleClick: isDoubleClick,
        ),
      );
    } else {
      applyResult(_activeTool.onPointerUp(point, toolContext));
    }

    // Double-click dispatch for text editing and line editing
    if (isDoubleClick &&
        _activeTool is SelectTool &&
        _editingTextElementId == null) {
      final hit = _editorState.scene.getElementAtPoint(point);
      if (hit is TextElement) {
        startTextEditingExisting(hit);
      } else if (hit != null && BoundTextUtils.isTextContainer(hit)) {
        startBoundTextEditing(hit);
      } else if (hit is ArrowElement) {
        startArrowLabelEditing(hit);
      } else if (hit is LineElement) {
        _isEditingLinear = true;
        notifyListeners();
      }
    }

    if (_sceneBeforeDrag != null &&
        !identical(_editorState.scene, _sceneBeforeDrag)) {
      _historyManager.push(_sceneBeforeDrag!);
    }
    _sceneBeforeDrag = null;
  }

  void onPointerHover(Offset localPosition) {
    final point = toScene(localPosition);
    _activeTool.onPointerMove(point, toolContext);
    _mousePosition = localPosition;
    notifyListeners();
  }

  void onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
      final newViewport = _editorState.viewport.zoomAt(
        factor,
        event.localPosition,
        minZoom: _config.minZoom,
        maxZoom: _config.maxZoom,
      );
      applyResult(UpdateViewportResult(newViewport));
    }
  }

  void onScaleStart(ScaleStartDetails details) {
    _pinchStartZoom = _editorState.viewport.zoom;
    _pinchStartOffset = _editorState.viewport.offset;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    var newViewport = ViewportState(
      offset: _pinchStartOffset,
      zoom: _pinchStartZoom,
    );
    newViewport = newViewport.zoomAt(
      details.scale,
      details.localFocalPoint,
      minZoom: _config.minZoom,
      maxZoom: _config.maxZoom,
    );
    newViewport = newViewport.pan(details.focalPointDelta);
    applyResult(UpdateViewportResult(newViewport));
  }

  // --- Style changes ---

  void applyStyleChange(ElementStyle style) {
    final wasEditing = _editingTextElementId != null;
    final savedSelection = wasEditing
        ? editableTextKey.currentState?.textEditingValue.selection
        : null;
    if (wasEditing) _suppressFocusCommit = true;

    // Update sticky defaults
    _defaultStyle = ElementStyle(
      strokeColor: style.strokeColor ?? _defaultStyle.strokeColor,
      backgroundColor:
          style.backgroundColor ?? _defaultStyle.backgroundColor,
      strokeWidth: style.strokeWidth ?? _defaultStyle.strokeWidth,
      strokeStyle: style.strokeStyle ?? _defaultStyle.strokeStyle,
      fillStyle: style.fillStyle ?? _defaultStyle.fillStyle,
      roughness: style.roughness ?? _defaultStyle.roughness,
      opacity: style.opacity ?? _defaultStyle.opacity,
      fontSize: style.fontSize ?? _defaultStyle.fontSize,
      fontFamily: style.fontFamily ?? _defaultStyle.fontFamily,
      textAlign: style.textAlign ?? _defaultStyle.textAlign,
      verticalAlign: style.verticalAlign ?? _defaultStyle.verticalAlign,
      startArrowhead: style.startArrowheadNone
          ? null
          : (style.startArrowhead ?? _defaultStyle.startArrowhead),
      startArrowheadNone: style.startArrowheadNone ||
          (style.startArrowhead == null &&
              _defaultStyle.startArrowheadNone),
      endArrowhead: style.endArrowheadNone
          ? null
          : (style.endArrowhead ?? _defaultStyle.endArrowhead),
      endArrowheadNone: style.endArrowheadNone ||
          (style.endArrowhead == null && _defaultStyle.endArrowheadNone),
      arrowType: style.arrowType ?? _defaultStyle.arrowType,
      roundness: style.roundness ??
          (style.hasRoundness ? null : _defaultStyle.roundness),
    );

    final elements = selectedElements;
    if (elements.isEmpty) {
      notifyListeners();
      restoreTextFocus(wasEditing, savedSelection);
      return;
    }

    _historyManager.push(_editorState.scene);

    // When editing bound text, strokeColor targets the text, not the shape.
    final editingBoundText = _editingTextElementId != null
        ? _editorState.scene.getElementById(_editingTextElementId!)
        : null;
    final isEditingBoundText =
        editingBoundText is TextElement && editingBoundText.containerId != null;

    // Apply style to selected elements — but exclude strokeColor from the
    // parent shape when the user is editing its bound text.
    final shapeStyle = isEditingBoundText && style.strokeColor != null
        ? style.copyWith(clearStrokeColor: true)
        : style;
    final result = PropertyPanelState.applyStyle(elements, shapeStyle);
    applyResult(result);

    // Also apply text properties to bound text of selected containers
    if (style.fontSize != null ||
        style.fontFamily != null ||
        style.textAlign != null ||
        style.verticalAlign != null ||
        style.strokeColor != null) {
      for (final e in elements) {
        final bt = _editorState.scene.findBoundText(e.id);
        if (bt != null) {
          var updated = bt.copyWithText(
            fontSize: style.fontSize,
            fontFamily: style.fontFamily,
            textAlign: style.textAlign,
            verticalAlign: style.verticalAlign,
          );
          if (style.strokeColor != null) {
            updated = updated.copyWith(
              strokeColor: style.strokeColor,
            );
          }
          applyResult(UpdateElementResult(updated));
        }
      }
    }

    restoreTextFocus(wasEditing, savedSelection);
  }

  void restoreTextFocus(bool wasEditing, TextSelection? savedSelection) {
    if (!wasEditing || _editingTextElementId == null) {
      _suppressFocusCommit = false;
      return;
    }
    _textFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressFocusCommit = false;
      if (savedSelection != null && _editingTextElementId != null) {
        final editable = editableTextKey.currentState;
        if (editable != null) {
          editable.userUpdateTextEditingValue(
            editable.textEditingValue.copyWith(selection: savedSelection),
            SelectionChangedCause.keyboard,
          );
        }
      }
    });
  }

  // --- Key dispatch ---

  void dispatchKey(String key, {bool shift = false, bool ctrl = false}) {
    final result = _activeTool.onKeyEvent(
      key,
      shift: shift,
      ctrl: ctrl,
      context: toolContext,
    );
    if (isSceneChangingResult(result)) {
      _historyManager.push(_editorState.scene);
    }
    applyResult(result);
  }

  // --- Selection helpers ---

  bool isDraggingPointHandle() {
    return _activeTool is SelectTool &&
        (_activeTool as SelectTool).isDraggingPoint;
  }

  List<Point>? buildPointHandles() {
    if (_editorState.selectedIds.length != 1) return null;
    final elem = _editorState.scene.getElementById(
      _editorState.selectedIds.first,
    );
    if (elem == null) return null;
    if (elem is LineElement) {
      // Always show endpoint handles for simple 2-point lines/arrows
      // (their bounding box is hidden). For 3+ point lines, require
      // double-click to enter linear editing mode.
      if (elem.points.length <= 2 || _isEditingLinear) {
        return elem.points
            .map((p) => Point(elem.x + p.x, elem.y + p.y))
            .toList();
      }
    }
    return null;
  }

  List<Point>? buildSegmentMidpoints() {
    if (!_isEditingLinear) return null;
    if (_editorState.selectedIds.length != 1) return null;
    final elem = _editorState.scene.getElementById(
      _editorState.selectedIds.first,
    );
    if (elem == null) return null;
    if (elem is! ArrowElement || !elem.elbowed) return null;
    if (elem.points.length < 2) return null;

    final midpoints = <Point>[];
    for (var i = 0; i < elem.points.length - 1; i++) {
      final a = elem.points[i];
      final b = elem.points[i + 1];
      midpoints.add(
          Point(elem.x + (a.x + b.x) / 2, elem.y + (a.y + b.y) / 2));
    }
    return midpoints;
  }

  List<Point>? buildMidpointHandles() {
    if (!_isEditingLinear) return null;
    if (_editorState.selectedIds.length != 1) return null;
    final elem = _editorState.scene.getElementById(
      _editorState.selectedIds.first,
    );
    if (elem == null) return null;
    if (elem is! LineElement) return null;
    if (elem is ArrowElement && elem.elbowed) return null;
    if (elem.points.length < 2) return null;

    final midpoints = <Point>[];
    for (var i = 0; i < elem.points.length - 1; i++) {
      final a = elem.points[i];
      final b = elem.points[i + 1];
      midpoints.add(
          Point(elem.x + (a.x + b.x) / 2, elem.y + (a.y + b.y) / 2));
    }
    return midpoints;
  }

  SelectionOverlay? buildSelectionOverlay() {
    if (_editorState.selectedIds.isEmpty) return null;
    final selected = _editorState.selectedIds
        .map((id) => _editorState.scene.getElementById(id))
        .whereType<Element>()
        .toList();
    if (selected.isEmpty) return null;
    return SelectionOverlay.fromElements(selected, mode: interactionMode);
  }

  // --- Preview element ---

  Element? buildPreviewElement(ToolOverlay? overlay) {
    if (overlay == null) return null;
    final toolType = _editorState.activeToolType;
    const previewId = ElementId('__preview__');
    const previewSeed = 42;

    Element? element;

    if (overlay.creationBounds != null) {
      final b = overlay.creationBounds!;
      element = switch (toolType) {
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

    if (element == null &&
        overlay.creationPoints != null &&
        overlay.creationPoints!.length >= 2) {
      final pts = overlay.creationPoints!;
      final minX = pts.map((p) => p.x).reduce(math.min);
      final minY = pts.map((p) => p.y).reduce(math.min);
      final maxX = pts.map((p) => p.x).reduce(math.max);
      final maxY = pts.map((p) => p.y).reduce(math.max);
      final relPts =
          pts.map((p) => Point(p.x - minX, p.y - minY)).toList();

      element = switch (toolType) {
        ToolType.line => LineElement(
            id: previewId,
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY,
            points: relPts,
            seed: previewSeed,
            closed: overlay.creationClosed,
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

    return element != null ? applyDefaultStyleToElement(element) : null;
  }

  // --- Scene management ---

  void loadScene(Scene scene, {String? background}) {
    _historyManager.clear();
    _editorState = _editorState.copyWith(scene: scene, selectedIds: {});
    if (background != null) {
      _canvasBackgroundColor = background;
    }
    notifyListeners();
  }

  /// Replaces the scene while preserving undo/redo history.
  ///
  /// Unlike [loadScene], this pushes the current scene onto the undo stack
  /// so the change can be undone. Used by the split-pane text editor.
  void applyScene(Scene scene, {String? background}) {
    _historyManager.push(_editorState.scene);
    _editorState = _editorState.copyWith(scene: scene, selectedIds: {});
    if (background != null) {
      _canvasBackgroundColor = background;
    }
    notifyListeners();
  }

  /// Replaces the scene without pushing to the undo stack.
  ///
  /// Used for coalescing rapid edits (e.g. consecutive text-pane keystrokes)
  /// into a single undo entry. Call [applyScene] first to create the undo
  /// point, then [replaceScene] for subsequent updates in the same session.
  void replaceScene(Scene scene, {String? background}) {
    _editorState = _editorState.copyWith(scene: scene, selectedIds: {});
    if (background != null) {
      _canvasBackgroundColor = background;
    }
    notifyListeners();
  }

  void clear() {
    _historyManager.clear();
    _editorState = _editorState.copyWith(
      scene: Scene(),
      selectedIds: {},
    );
    notifyListeners();
  }

  Set<String> getSceneFontFamilies() {
    return _editorState.scene.activeElements
        .whereType<TextElement>()
        .map((e) => e.fontFamily)
        .toSet();
  }

  void pushHistory() {
    _historyManager.push(_editorState.scene);
  }

  void toggleMarkdownPanel() {
    _showMarkdownPanel = !_showMarkdownPanel;
    notifyListeners();
  }

  void toggleToolLocked() {
    _toolLocked = !_toolLocked;
    _editorState = _editorState.copyWith(toolLocked: _toolLocked);
    if (!_toolLocked) {
      switchTool(ToolType.select);
    } else {
      notifyListeners();
    }
  }

  void toggleGrid() {
    _gridSize = _gridSize == null ? 20 : null;
    notifyListeners();
  }

  /// Pans the viewport by the given scene-coordinate deltas.
  void panViewport(double dx, double dy) {
    final viewport = _editorState.viewport;
    final newViewport = ViewportState(
      offset: Offset(viewport.offset.dx + dx, viewport.offset.dy + dy),
      zoom: viewport.zoom,
    );
    applyResult(UpdateViewportResult(newViewport));
  }

  /// Cycles font size through presets [16, 20, 28, 36].
  void cycleFontSize({required bool increase}) {
    const presets = [16.0, 20.0, 28.0, 36.0];
    final current = _defaultStyle.fontSize ?? 20.0;

    double newSize;
    if (increase) {
      newSize = presets.firstWhere(
        (s) => s > current,
        orElse: () => presets.last,
      );
    } else {
      newSize = presets.lastWhere(
        (s) => s < current,
        orElse: () => presets.first,
      );
    }

    applyStyleChange(ElementStyle(fontSize: newSize));
  }

  /// Copies the style from the first selected element.
  void copyStyle() {
    final elements = selectedElements;
    if (elements.isEmpty) return;
    final e = elements.first;
    _copiedStyle = ElementStyle(
      strokeColor: e.strokeColor,
      backgroundColor: e.backgroundColor,
      strokeWidth: e.strokeWidth,
      strokeStyle: e.strokeStyle,
      fillStyle: e.fillStyle,
      roughness: e.roughness,
      opacity: e.opacity,
      fontSize: e is TextElement ? e.fontSize : null,
      fontFamily: e is TextElement ? e.fontFamily : null,
    );
  }

  /// Applies the previously copied style to the current selection.
  void pasteStyle() {
    if (_copiedStyle == null) return;
    final elements = selectedElements;
    if (elements.isEmpty) return;
    applyStyleChange(_copiedStyle!);
  }

  /// Pastes clipboard text as a new TextElement at viewport center.
  Future<void> pasteAsPlaintext(Size canvasSize) async {
    final text = await _clipboardService.readText();
    if (text == null || text.trim().isEmpty) return;

    final centerScene = _editorState.viewport.screenToScene(
      Offset(canvasSize.width / 2, canvasSize.height / 2),
    );

    final textElem = TextElement(
      id: ElementId.generate(),
      x: centerScene.dx,
      y: centerScene.dy,
      width: 10,
      height: 10,
      text: text.trim(),
    );

    final (w, h) = TextRenderer.measure(textElem);
    final sized = textElem.copyWith(
      width: math.max(w + 4, 20.0),
      height: math.max(h, textElem.fontSize * textElem.lineHeight),
    );

    _historyManager.push(_editorState.scene);
    applyResult(CompoundResult([
      AddElementResult(applyDefaultStyleToElement(sized)),
      SetSelectionResult({sized.id}),
    ]));
  }

  /// Clears the canvas, pushing the current scene to undo history.
  void resetCanvas() {
    _historyManager.push(_editorState.scene);
    _editorState = _editorState.copyWith(
      scene: Scene(),
      selectedIds: {},
    );
    onSceneChanged?.call(_editorState.scene);
    notifyListeners();
  }

  /// Toggles zen mode — hides all chrome.
  void toggleZenMode() {
    _zenMode = !_zenMode;
    notifyListeners();
  }

  /// Toggles view (read-only) mode — forces hand tool, blocks switching.
  void toggleViewMode() {
    _viewMode = !_viewMode;
    if (_viewMode) {
      _toolBeforeViewMode = _editorState.activeToolType;
      switchTool(ToolType.hand);
      _editorState = _editorState.copyWith(selectedIds: {});
    } else {
      switchTool(_toolBeforeViewMode ?? ToolType.select);
      _toolBeforeViewMode = null;
    }
    notifyListeners();
  }

  /// Requests programmatic opening of a color picker.
  void requestColorPicker(ColorPickerTarget target) {
    _pendingColorPicker = target;
    notifyListeners();
  }

  /// Clears the pending color picker request.
  void clearPendingColorPicker() {
    _pendingColorPicker = null;
  }

  // --- Convenience methods for serialization / export / import ---

  /// Serializes the current scene to a string in the given [format].
  String serializeScene({DocumentFormat format = DocumentFormat.markdraw}) {
    final doc = SceneDocumentConverter.sceneToDocument(
      _editorState.scene,
      settings: CanvasSettings(
        background: _canvasBackgroundColor,
        grid: _gridSize,
      ),
    );
    return switch (format) {
      DocumentFormat.markdraw => DocumentSerializer.serialize(doc),
      DocumentFormat.excalidraw => ExcalidrawJsonCodec.serialize(doc),
      _ => DocumentSerializer.serialize(doc),
    };
  }

  /// Loads a scene from file content. Detects format from [filename].
  void loadFromContent(String content, String filename) {
    final format = DocumentService.detectFormat(filename);
    final parseResult = switch (format) {
      DocumentFormat.markdraw => DocumentParser.parse(content),
      DocumentFormat.excalidraw => ExcalidrawJsonCodec.parse(content),
      _ => throw ArgumentError('Use importLibraryFromContent for library files'),
    };
    _canvasBackgroundColor = parseResult.value.settings.background;
    _gridSize = parseResult.value.settings.grid;
    loadScene(SceneDocumentConverter.documentToScene(parseResult.value));
  }

  /// Exports the scene (or selection) as PNG bytes.
  Future<Uint8List?> exportPng({int scale = 2, bool selectedOnly = true}) {
    final selectedIds = selectedOnly && _editorState.selectedIds.isNotEmpty
        ? _editorState.selectedIds
        : null;
    return PngExporter.export(
      _editorState.scene,
      _adapter,
      scale: scale,
      backgroundColor: parseColor(_canvasBackgroundColor),
      selectedIds: selectedIds,
    );
  }

  /// Exports the scene (or selection) as an SVG string.
  String exportSvg({bool selectedOnly = true}) {
    final selectedIds = selectedOnly && _editorState.selectedIds.isNotEmpty
        ? _editorState.selectedIds
        : null;
    return SvgExporter.export(
      _editorState.scene,
      backgroundColor: _canvasBackgroundColor,
      selectedIds: selectedIds,
    );
  }

  /// Imports an image from raw bytes, decodes it, and adds it to the scene.
  ///
  /// [canvasSize] is used to center the image in the current viewport.
  Future<void> importImage(
    Uint8List bytes,
    String filename,
    Size canvasSize,
  ) async {
    final ext = filename.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };

    final digest = sha1.convert(bytes);
    final fileId = digest.toString().substring(0, 8);
    final imageFile = ImageFile(mimeType: mimeType, bytes: bytes);

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final decodedImage = frame.image;
    final naturalWidth = decodedImage.width.toDouble();
    final naturalHeight = decodedImage.height.toDouble();

    double width = naturalWidth;
    double height = naturalHeight;
    const maxSize = 800.0;
    if (width > maxSize || height > maxSize) {
      final scale = maxSize / (width > height ? width : height);
      width *= scale;
      height *= scale;
    }

    final centerScene = _editorState.viewport.screenToScene(
      Offset(canvasSize.width / 2, canvasSize.height / 2),
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

    _imageCache.putImage(fileId, decodedImage);

    pushHistory();
    applyResult(
      CompoundResult([
        AddFileResult(fileId: fileId, file: imageFile),
        AddElementResult(element),
        SetSelectionResult({element.id}),
      ]),
    );
  }

  /// Imports library items from file content. Detects format from [filename].
  void importLibraryFromContent(String content, String filename) {
    final format = DocumentService.detectFormat(filename);
    final ParseResult<LibraryDocument> result;
    switch (format) {
      case DocumentFormat.markdrawLibrary:
        result = LibraryCodec.parse(content);
      case DocumentFormat.excalidrawLibrary:
        result = ExcalidrawLibCodec.parse(content);
      case DocumentFormat.markdraw:
      case DocumentFormat.excalidraw:
        throw ArgumentError('Not a library file');
    }
    _libraryItems = [..._libraryItems, ...result.value.items];
    _showLibraryPanel = true;
    notifyListeners();
  }

  /// Serializes the current library items to a string.
  String exportLibraryContent({
    DocumentFormat format = DocumentFormat.excalidrawLibrary,
  }) {
    final doc = LibraryDocument(items: _libraryItems);
    return switch (format) {
      DocumentFormat.excalidrawLibrary => ExcalidrawLibCodec.serialize(doc),
      DocumentFormat.markdrawLibrary => LibraryCodec.serialize(doc),
      _ => ExcalidrawLibCodec.serialize(doc),
    };
  }
}
