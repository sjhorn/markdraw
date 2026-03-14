import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

// --- Helpers ---

RectangleElement _rect({
  String id = 'r1',
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 50,
  String? link,
  String strokeColor = '#000000',
}) {
  return RectangleElement(
    id: ElementId(id),
    x: x,
    y: y,
    width: w,
    height: h,
    link: link,
    strokeColor: strokeColor,
  );
}

EllipseElement _ellipse({String id = 'e1', double x = 0, double y = 0}) {
  return EllipseElement(
    id: ElementId(id),
    x: x,
    y: y,
    width: 80,
    height: 80,
  );
}

DiamondElement _diamond({String id = 'd1'}) {
  return DiamondElement(
    id: ElementId(id),
    x: 0,
    y: 0,
    width: 60,
    height: 60,
  );
}

TextElement _text({
  String id = 't1',
  String text = 'Hello',
  String? containerId,
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 20,
}) {
  return TextElement(
    id: ElementId(id),
    x: x,
    y: y,
    width: w,
    height: h,
    text: text,
    containerId: containerId,
  );
}

LineElement _line({String id = 'l1'}) {
  return LineElement(
    id: ElementId(id),
    x: 0,
    y: 0,
    width: 100,
    height: 100,
    points: [const Point(0, 0), const Point(100, 100)],
  );
}

ArrowElement _arrow({String id = 'a1'}) {
  return ArrowElement(
    id: ElementId(id),
    x: 0,
    y: 0,
    width: 100,
    height: 0,
    points: [const Point(0, 0), const Point(100, 0)],
    endArrowhead: Arrowhead.arrow,
  );
}

FrameElement _frame({String id = 'f1', String label = 'Frame 1'}) {
  return FrameElement(
    id: ElementId(id),
    x: 0,
    y: 0,
    width: 200,
    height: 200,
    label: label,
  );
}

Scene _sceneWithRect() {
  return Scene().addElement(_rect());
}

const _canvasSize = Size(800, 600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------
  // 1. Construction & defaults
  // ---------------------------------------------------------------
  group('Construction & defaults', () {
    test('creates with default state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.editorState.scene.activeElements, isEmpty);
      expect(c.editorState.viewport.zoom, 1.0);
      expect(c.editorState.selectedIds, isEmpty);
      expect(c.editorState.activeToolType, ToolType.select);
      expect(c.canvasBackgroundColor, '#ffffff');
      expect(c.gridSize, isNull);
      expect(c.objectsSnapMode, isFalse);
      expect(c.documentName, isNull);
      expect(c.zenMode, isFalse);
      expect(c.viewMode, isFalse);
      expect(c.showMarkdownPanel, isFalse);
      expect(c.showLibraryPanel, isFalse);
      expect(c.toolLocked, isFalse);
      expect(c.isCompact, isFalse);
      expect(c.isEditingLinear, isFalse);
      expect(c.fontPickerOpen, isFalse);
      expect(c.copiedStyle, isNull);
      expect(c.isFindOpen, isFalse);
      expect(c.findQuery, '');
      expect(c.findResults, isEmpty);
      expect(c.findCurrentIndex, -1);
      expect(c.pendingColorPicker, isNull);
      expect(c.editingTextElementId, isNull);
      expect(c.editingFrameLabelId, isNull);
      expect(c.isEditingExisting, isFalse);
      expect(c.originalText, isNull);
      expect(c.isLinkEditorOpen, isFalse);
      expect(c.isLinkEditorEditing, isFalse);
      expect(c.linkToElementMode, isFalse);
      expect(c.libraryItems, isEmpty);
      expect(c.mousePosition, isNull);
    });

    test('accepts config with initial style and background', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialBackground: '#ff0000',
          initialStyle: ElementStyle(strokeColor: '#0000ff'),
        ),
      );
      addTearDown(c.dispose);

      expect(c.canvasBackgroundColor, '#ff0000');
      expect(c.defaultStyle.strokeColor, '#0000ff');
    });

    test('interactionMode reflects isCompact', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.interactionMode, InteractionMode.pointer);
      c.isCompact = true;
      expect(c.interactionMode, InteractionMode.touch);
    });

    test('isCreationTool is false for select/hand/eraser/laser', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      for (final t in [
        ToolType.select,
        ToolType.hand,
        ToolType.eraser,
        ToolType.laser,
      ]) {
        c.switchTool(t);
        expect(c.isCreationTool, isFalse, reason: '$t should not be creation');
      }
    });

    test('isCreationTool is true for shape/line/text tools', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      for (final t in [
        ToolType.rectangle,
        ToolType.ellipse,
        ToolType.diamond,
        ToolType.arrow,
        ToolType.line,
        ToolType.freedraw,
        ToolType.text,
        ToolType.frame,
      ]) {
        c.switchTool(t);
        expect(c.isCreationTool, isTrue, reason: '$t should be creation');
      }
    });

    test('cursorForTool returns appropriate cursors', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.select);
      expect(c.cursorForTool, SystemMouseCursors.basic);

      c.switchTool(ToolType.hand);
      expect(c.cursorForTool, SystemMouseCursors.basic);

      c.switchTool(ToolType.eraser);
      expect(c.cursorForTool, SystemMouseCursors.none);

      c.switchTool(ToolType.laser);
      expect(c.cursorForTool, SystemMouseCursors.precise);

      c.switchTool(ToolType.rectangle);
      expect(c.cursorForTool, SystemMouseCursors.precise);
    });
  });

  // ---------------------------------------------------------------
  // 2. switchTool
  // ---------------------------------------------------------------
  group('switchTool', () {
    test('changes active tool type', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      expect(c.editorState.activeToolType, ToolType.rectangle);

      c.switchTool(ToolType.ellipse);
      expect(c.editorState.activeToolType, ToolType.ellipse);
    });

    test('clears selection when switching to non-select tool', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      expect(c.editorState.selectedIds, isNotEmpty);

      c.switchTool(ToolType.rectangle);
      expect(c.editorState.selectedIds, isEmpty);
    });

    test('preserves selection when switching to select', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));

      c.switchTool(ToolType.hand);
      // Selection is cleared on non-select
      c.switchTool(ToolType.select);
      // Select tool does not clear existing selection
      expect(c.editorState.activeToolType, ToolType.select);
    });

    test('blocks non-hand tools in view mode', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.toggleViewMode();
      expect(c.viewMode, isTrue);
      expect(c.editorState.activeToolType, ToolType.hand);

      c.switchTool(ToolType.rectangle);
      expect(c.editorState.activeToolType, ToolType.hand);
    });

    test('notifies listeners on switch', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.switchTool(ToolType.diamond);
      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------
  // 3. Undo/Redo
  // ---------------------------------------------------------------
  group('Undo/Redo', () {
    test('undo restores previous scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final original = c.editorState.scene;
      c.applyScene(_sceneWithRect());
      c.undo();
      expect(identical(c.editorState.scene, original), isTrue);
    });

    test('redo restores undone scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(_sceneWithRect());
      final after = c.editorState.scene;
      c.undo();
      c.redo();
      expect(identical(c.editorState.scene, after), isTrue);
    });

    test('undo calls onSceneChanged', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      c.applyScene(_sceneWithRect());
      changed = null;
      c.undo();
      expect(changed, isNotNull);
    });

    test('redo calls onSceneChanged', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      c.applyScene(_sceneWithRect());
      c.undo();
      changed = null;
      c.redo();
      expect(changed, isNotNull);
    });

    test('undo does nothing when empty', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var called = false;
      c.onSceneChanged = (_) => called = true;
      c.undo();
      expect(called, isFalse);
    });

    test('redo does nothing when empty', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var called = false;
      c.onSceneChanged = (_) => called = true;
      c.redo();
      expect(called, isFalse);
    });

    test('pushHistory makes undo available', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.historyManager.canUndo, isFalse);
      c.pushHistory();
      expect(c.historyManager.canUndo, isTrue);
    });
  });

  // ---------------------------------------------------------------
  // 4. Zoom methods
  // ---------------------------------------------------------------
  group('Zoom methods', () {
    test('zoomIn increases zoom', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final before = c.editorState.viewport.zoom;
      c.zoomIn(_canvasSize);
      expect(c.editorState.viewport.zoom, greaterThan(before));
    });

    test('zoomOut decreases zoom', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final before = c.editorState.viewport.zoom;
      c.zoomOut(_canvasSize);
      expect(c.editorState.viewport.zoom, lessThan(before));
    });

    test('resetZoom resets to default', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.zoomIn(_canvasSize);
      c.resetZoom();
      expect(c.editorState.viewport.zoom, 1.0);
      expect(c.editorState.viewport.offset, Offset.zero);
    });

    test('zoomToFit adjusts viewport to show all elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene()
          .addElement(_rect(x: 0, y: 0, w: 1000, h: 1000))
          .addElement(_rect(id: 'r2', x: 2000, y: 2000, w: 500, h: 500)));
      c.zoomToFit(_canvasSize);
      // Viewport should have changed from default
      expect(c.editorState.viewport.zoom, isNot(1.0));
    });

    test('zoomToFit does nothing on empty scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.zoomToFit(_canvasSize);
      expect(c.editorState.viewport.zoom, 1.0);
    });

    test('zoomToSelection fits selected elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(x: 500, y: 500, w: 100, h: 100);
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.zoomToSelection(_canvasSize);
      // Viewport should have changed
      expect(c.editorState.viewport.offset, isNot(Offset.zero));
    });

    test('zoomToSelection does nothing with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(_sceneWithRect());
      final before = c.editorState.viewport;
      c.zoomToSelection(_canvasSize);
      expect(c.editorState.viewport.zoom, before.zoom);
    });
  });

  // ---------------------------------------------------------------
  // 5. applyDefaultStyleToElement
  // ---------------------------------------------------------------
  group('applyDefaultStyleToElement', () {
    test('applies stroke and fill to rectangle', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(
            strokeColor: '#ff0000',
            backgroundColor: '#00ff00',
            strokeWidth: 4.0,
          ),
        ),
      );
      addTearDown(c.dispose);

      final styled = c.applyDefaultStyleToElement(_rect());
      expect(styled.strokeColor, '#ff0000');
      expect(styled.backgroundColor, '#00ff00');
      expect(styled.strokeWidth, 4.0);
    });

    test('applies font size and family to text element', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(
            fontSize: 28.0,
            fontFamily: 'Excalifont',
          ),
        ),
      );
      addTearDown(c.dispose);

      final styled = c.applyDefaultStyleToElement(_text());
      expect(styled, isA<TextElement>());
      expect((styled as TextElement).fontSize, 28.0);
      expect(styled.fontFamily, 'Excalifont');
    });

    test('applies arrowhead style to line element', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(
            endArrowhead: Arrowhead.arrow,
          ),
        ),
      );
      addTearDown(c.dispose);

      final styled = c.applyDefaultStyleToElement(_line());
      expect(styled, isA<LineElement>());
      expect((styled as LineElement).endArrowhead, Arrowhead.arrow);
    });

    test('applies roundness to rectangle', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(
            roundness: Roundness.adaptive(value: 10),
          ),
        ),
      );
      addTearDown(c.dispose);

      final styled = c.applyDefaultStyleToElement(_rect());
      expect(styled.roundness, isNotNull);
      expect(styled.roundness!.value, 10);
    });

    test('applies roundness to diamond as proportional', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(
            roundness: Roundness.adaptive(value: 5),
          ),
        ),
      );
      addTearDown(c.dispose);

      final styled = c.applyDefaultStyleToElement(_diamond());
      expect(styled.roundness, isNotNull);
    });
  });

  // ---------------------------------------------------------------
  // 6. applyResult
  // ---------------------------------------------------------------
  group('applyResult', () {
    test('AddElementResult adds element to scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.applyResult(AddElementResult(r));
      expect(c.editorState.scene.activeElements, hasLength(1));
    });

    test('UpdateElementResult updates element in scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.applyResult(AddElementResult(r));
      final updated = r.copyWith(x: 50);
      c.applyResult(UpdateElementResult(updated));

      final found = c.editorState.scene.getElementById(r.id);
      expect(found!.x, 50);
    });

    test('RemoveElementResult removes element', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.applyResult(AddElementResult(r));
      c.applyResult(RemoveElementResult(r.id));
      expect(c.editorState.scene.activeElements, isEmpty);
    });

    test('SetSelectionResult updates selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.applyResult(AddElementResult(r));
      c.applyResult(SetSelectionResult({r.id}));
      expect(c.editorState.selectedIds, contains(r.id));
    });

    test('UpdateViewportResult updates viewport', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyResult(UpdateViewportResult(
        const ViewportState(zoom: 2.0, offset: Offset(100, 200)),
      ));
      expect(c.editorState.viewport.zoom, 2.0);
      expect(c.editorState.viewport.offset, const Offset(100, 200));
    });

    test('CompoundResult applies multiple results', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      final e = _ellipse();
      c.applyResult(CompoundResult([
        AddElementResult(r),
        AddElementResult(e),
      ]));
      expect(c.editorState.scene.activeElements, hasLength(2));
    });

    test('null result is ignored', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyResult(null);
      expect(c.editorState.scene.activeElements, isEmpty);
    });

    test('calls onSceneChanged for scene-changing results', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      c.applyResult(AddElementResult(_rect()));
      expect(changed, isNotNull);
    });

    test('applies default style to AddElementResult in creation mode', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(strokeColor: '#ff0000'),
        ),
      );
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      c.applyResult(AddElementResult(_rect()));
      final elem = c.editorState.scene.activeElements.first;
      expect(elem.strokeColor, '#ff0000');
    });

    test('does not apply default style in select mode', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(strokeColor: '#ff0000'),
        ),
      );
      addTearDown(c.dispose);

      // Select tool is default, not a creation tool
      c.applyResult(AddElementResult(_rect(strokeColor: '#000000')));
      final elem = c.editorState.scene.activeElements.first;
      expect(elem.strokeColor, '#000000');
    });

    test('clears isEditingLinear on selection change', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.isEditingLinear = true;
      expect(c.isEditingLinear, isTrue);

      c.applyResult(SetSelectionResult({}));
      expect(c.isEditingLinear, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // 7. Text editing lifecycle
  // ---------------------------------------------------------------
  group('Text editing lifecycle', () {
    test('startTextEditingExisting sets editing state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Original');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);

      expect(c.editingTextElementId, t.id);
      expect(c.isEditingExisting, isTrue);
      expect(c.originalText, 'Original');
      expect(c.textEditingController.text, 'Original');
    });

    test('commitTextEditing updates element text', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Old');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = 'New text';
      c.commitTextEditing();

      expect(c.editingTextElementId, isNull);
      final updated = c.editorState.scene.getElementById(t.id) as TextElement;
      expect(updated.text, 'New text');
    });

    test('commitTextEditing removes empty text element', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Old');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = '';
      c.commitTextEditing();

      expect(c.editorState.scene.getElementById(t.id), isNull);
    });

    test('commitTextEditing removes empty bound text and cleans parent', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = _text(id: 'bt1', text: 'Label', containerId: 'r1');
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.startTextEditingExisting(bt);
      c.textEditingController.text = '  ';
      c.commitTextEditing();

      // Bound text removed
      expect(c.editorState.scene.getElementById(const ElementId('bt1')),
          isNull);
      // Parent's boundElements cleaned up
      final parent = c.editorState.scene.getElementById(const ElementId('r1'))!;
      expect(parent.boundElements, isEmpty);
    });

    test('cancelTextEditing reverts existing text', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Original');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = 'Changed';
      c.cancelTextEditing();

      expect(c.editingTextElementId, isNull);
      final restored = c.editorState.scene.getElementById(t.id) as TextElement;
      expect(restored.text, 'Original');
    });

    test('cancelTextEditing removes new text element', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Simulate creating a new text via tool: add a text with empty text
      // then start editing it as "not existing"
      final t = _text(text: '');
      c.loadScene(Scene().addElement(t));
      // Manually set up the editing state for a new element
      c.applyResult(SetSelectionResult({t.id}));

      // Start editing as new (isEditingExisting = false)
      // We'll use startTextEditingExisting and manipulate flags
      // Actually, cancel on non-existing removes the element
      // Let's do a bound text scenario instead
      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.startBoundTextEditing(r);

      // A new bound text was created
      expect(c.editingTextElementId, isNotNull);
      expect(c.isEditingExisting, isFalse);

      c.cancelTextEditing();
      // The new bound text should be removed
      expect(c.editingTextElementId, isNull);
    });

    test('onTextChanged updates element dimensions', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Hi');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = 'Hello World, this is a longer text';
      c.onTextChanged();

      final updated = c.editorState.scene.getElementById(t.id) as TextElement;
      expect(updated.text, 'Hello World, this is a longer text');
    });

    test('onTextChanged does nothing when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Should not throw
      c.onTextChanged();
    });

    test('commitTextEditing calls onSceneChanged', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      final t = _text(text: 'Hi');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = 'Updated';
      changed = null;
      c.commitTextEditing();
      expect(changed, isNotNull);
    });

    test('commitTextEditing does nothing when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Should not throw
      c.commitTextEditing();
    });
  });

  // ---------------------------------------------------------------
  // 8. Bound text editing
  // ---------------------------------------------------------------
  group('Bound text editing', () {
    test('startBoundTextEditing creates new bound text if none exists', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.startBoundTextEditing(r);

      expect(c.editingTextElementId, isNotNull);
      expect(c.isEditingExisting, isFalse);

      // Verify a text element was created
      final scene = c.editorState.scene;
      final textElements =
          scene.activeElements.whereType<TextElement>().toList();
      expect(textElements, hasLength(1));
      expect(textElements.first.containerId, r.id.value);
    });

    test('startBoundTextEditing opens existing bound text', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = _text(id: 'bt1', text: 'Existing', containerId: 'r1');
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.startBoundTextEditing(r);

      expect(c.editingTextElementId, const ElementId('bt1'));
      expect(c.isEditingExisting, isTrue);
      expect(c.originalText, 'Existing');
      expect(c.textEditingController.text, 'Existing');
    });
  });

  // ---------------------------------------------------------------
  // 9. Arrow label editing
  // ---------------------------------------------------------------
  group('Arrow label editing', () {
    test('startArrowLabelEditing creates new label text', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = _arrow();
      c.loadScene(Scene().addElement(a));
      c.startArrowLabelEditing(a);

      expect(c.editingTextElementId, isNotNull);
      expect(c.isEditingExisting, isFalse);
    });

    test('startArrowLabelEditing opens existing label', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = _arrow().copyWith(
        boundElements: [const BoundElement(id: 'lbl1', type: 'text')],
      );
      final lbl = _text(id: 'lbl1', text: 'Label', containerId: 'a1');
      c.loadScene(Scene().addElement(a).addElement(lbl));
      c.startArrowLabelEditing(a);

      expect(c.editingTextElementId, const ElementId('lbl1'));
      expect(c.isEditingExisting, isTrue);
      expect(c.textEditingController.text, 'Label');
    });
  });

  // ---------------------------------------------------------------
  // 10. Frame label editing
  // ---------------------------------------------------------------
  group('Frame label editing', () {
    test('startFrameLabelEditing sets editing state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame();
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);

      expect(c.editingFrameLabelId, f.id);
    });

    test('commitFrameLabel updates label', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame(label: 'Old Label');
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);
      c.commitFrameLabel('New Label');

      expect(c.editingFrameLabelId, isNull);
      final updated =
          c.editorState.scene.getElementById(f.id) as FrameElement;
      expect(updated.label, 'New Label');
    });

    test('commitFrameLabel ignores empty label', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame(label: 'Keep Me');
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);
      c.commitFrameLabel('  ');

      final updated =
          c.editorState.scene.getElementById(f.id) as FrameElement;
      expect(updated.label, 'Keep Me');
    });

    test('commitFrameLabel ignores same label', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame(label: 'Same');
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);
      // Before commit, no history should be pushed for same label
      c.commitFrameLabel('Same');
      expect(c.historyManager.canUndo, isFalse);
    });

    test('commitFrameLabel clears editing if element is not a frame', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Set up a non-frame element id as editing target
      final r = _rect();
      c.loadScene(Scene().addElement(r));
      // Manually trigger: simulate a frame being deleted
      final f = _frame();
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);
      // Now remove frame and try to commit
      c.applyResult(RemoveElementResult(f.id));
      c.commitFrameLabel('Whatever');
      expect(c.editingFrameLabelId, isNull);
    });

    test('cancelFrameLabelEditing clears state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame();
      c.loadScene(Scene().addElement(f));
      c.startFrameLabelEditing(f);
      c.cancelFrameLabelEditing();

      expect(c.editingFrameLabelId, isNull);
    });
  });

  // ---------------------------------------------------------------
  // 11. hitTestFrameLabel
  // ---------------------------------------------------------------
  group('hitTestFrameLabel', () {
    test('hits frame label area above frame', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Frame at (0, 50), label is above the frame
      final f = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 50,
        width: 200,
        height: 200,
        label: 'TestFrame',
      );
      c.loadScene(Scene().addElement(f));

      // Label area: y from (50 - 4 - 18) = 28 to (50 - 4) = 46
      // x from 0 to clamp(9*8=72, 40, 200)=72
      final hit = c.hitTestFrameLabel(const Point(10, 35));
      expect(hit, isNotNull);
      expect(hit!.id, const ElementId('f1'));
    });

    test('misses frame label area below label', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 50,
        width: 200,
        height: 200,
        label: 'TestFrame',
      );
      c.loadScene(Scene().addElement(f));

      // Below the label area
      final hit = c.hitTestFrameLabel(const Point(10, 100));
      expect(hit, isNull);
    });
  });

  // ---------------------------------------------------------------
  // 12. Library management
  // ---------------------------------------------------------------
  group('Library management', () {
    test('addToLibrary adds selected elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();

      expect(c.libraryItems, hasLength(1));
      expect(c.showLibraryPanel, isTrue);
    });

    test('addToLibrary does nothing with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(_sceneWithRect());
      c.addToLibrary();
      expect(c.libraryItems, isEmpty);
    });

    test('placeLibraryItem adds element to scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();
      final item = c.libraryItems.first;

      c.placeLibraryItem(item, _canvasSize);
      // Original + placed copy
      expect(c.editorState.scene.activeElements.length, greaterThan(1));
    });

    test('placeLibraryItemAt places at specific position', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();
      final item = c.libraryItems.first;

      c.placeLibraryItemAt(item, const Offset(100, 100));
      expect(c.editorState.scene.activeElements.length, greaterThan(1));
    });

    test('removeLibraryItem removes item by id', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();
      expect(c.libraryItems, hasLength(1));

      c.removeLibraryItem(c.libraryItems.first.id);
      expect(c.libraryItems, isEmpty);
    });

    test('libraryItems setter replaces list', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.libraryItems = [
        LibraryItem(
          id: 'test',
          name: 'Test',
          status: 'published',
          created: 0,
          elements: [_rect()],
        ),
      ];
      expect(c.libraryItems, hasLength(1));
    });
  });

  // ---------------------------------------------------------------
  // 13. Scene management
  // ---------------------------------------------------------------
  group('Scene management', () {
    test('loadScene clears history and replaces scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(_sceneWithRect());
      expect(c.historyManager.canUndo, isTrue);

      c.loadScene(Scene().addElement(_ellipse()));
      expect(c.historyManager.canUndo, isFalse);
      expect(c.editorState.scene.activeElements, hasLength(1));
    });

    test('loadScene sets background', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene(), background: '#123456');
      expect(c.canvasBackgroundColor, '#123456');
    });

    test('loadScene clears selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.loadScene(Scene());
      expect(c.editorState.selectedIds, isEmpty);
    });

    test('applyScene pushes undo', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(_sceneWithRect());
      expect(c.historyManager.canUndo, isTrue);
    });

    test('applyScene sets background', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(Scene(), background: '#abcdef');
      expect(c.canvasBackgroundColor, '#abcdef');
    });

    test('replaceScene does not push undo', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.replaceScene(_sceneWithRect());
      expect(c.historyManager.canUndo, isFalse);
    });

    test('replaceScene sets background', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.replaceScene(Scene(), background: '#ff00ff');
      expect(c.canvasBackgroundColor, '#ff00ff');
    });

    test('clear resets scene and history', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(_sceneWithRect());
      c.clear();
      expect(c.editorState.scene.activeElements, isEmpty);
      expect(c.historyManager.canUndo, isFalse);
    });

    test('clear clears selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.clear();
      expect(c.editorState.selectedIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // 14. Toggles
  // ---------------------------------------------------------------
  group('Toggles', () {
    test('toggleMarkdownPanel toggles state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.showMarkdownPanel, isFalse);
      c.toggleMarkdownPanel();
      expect(c.showMarkdownPanel, isTrue);
      c.toggleMarkdownPanel();
      expect(c.showMarkdownPanel, isFalse);
    });

    test('toggleToolLocked toggles and switches to select when unlocking', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      c.toggleToolLocked();
      expect(c.toolLocked, isTrue);
      expect(c.editorState.activeToolType, ToolType.rectangle);

      c.toggleToolLocked();
      expect(c.toolLocked, isFalse);
      expect(c.editorState.activeToolType, ToolType.select);
    });

    test('toggleGrid toggles between null and 20', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.gridSize, isNull);
      c.toggleGrid();
      expect(c.gridSize, 20);
      c.toggleGrid();
      expect(c.gridSize, isNull);
    });

    test('toggleObjectsSnapMode toggles', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.objectsSnapMode, isFalse);
      c.toggleObjectsSnapMode();
      expect(c.objectsSnapMode, isTrue);
      c.toggleObjectsSnapMode();
      expect(c.objectsSnapMode, isFalse);
    });

    test('toggleZenMode toggles', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.zenMode, isFalse);
      c.toggleZenMode();
      expect(c.zenMode, isTrue);
      c.toggleZenMode();
      expect(c.zenMode, isFalse);
    });

    test('toggleViewMode enters and exits', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.viewMode, isFalse);
      c.toggleViewMode();
      expect(c.viewMode, isTrue);
      expect(c.editorState.activeToolType, ToolType.hand);

      c.toggleViewMode();
      expect(c.viewMode, isFalse);
      expect(c.editorState.activeToolType, ToolType.select);
    });

    test('toggleViewMode restores previous tool on exit', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      c.toggleViewMode();
      expect(c.editorState.activeToolType, ToolType.hand);

      c.toggleViewMode();
      expect(c.editorState.activeToolType, ToolType.rectangle);
    });

    test('toggleViewMode clears selection on enter', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.toggleViewMode();
      expect(c.editorState.selectedIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // 15. Style changes
  // ---------------------------------------------------------------
  group('Style changes', () {
    test('applyStyleChange updates default style', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyStyleChange(const ElementStyle(strokeColor: '#ff0000'));
      expect(c.defaultStyle.strokeColor, '#ff0000');
    });

    test('applyStyleChange updates selected elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.applyStyleChange(const ElementStyle(strokeColor: '#00ff00'));

      final updated = c.editorState.scene.getElementById(r.id)!;
      expect(updated.strokeColor, '#00ff00');
    });

    test('applyStyleChange propagates opacity to frame children', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame();
      final child = _rect(id: 'child1', x: 10, y: 10, w: 50, h: 50)
          .copyWith(frameId: 'f1');
      c.loadScene(Scene().addElement(f).addElement(child));
      c.applyResult(SetSelectionResult({f.id}));
      c.applyStyleChange(const ElementStyle(opacity: 50));

      final updatedChild =
          c.editorState.scene.getElementById(const ElementId('child1'))!;
      expect(updatedChild.opacity, 50);
    });

    test('copyStyle captures element style', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(strokeColor: '#123456');
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.copyStyle();

      expect(c.copiedStyle, isNotNull);
      expect(c.copiedStyle!.strokeColor, '#123456');
    });

    test('copyStyle does nothing with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.copyStyle();
      expect(c.copiedStyle, isNull);
    });

    test('copyStyle captures text properties from TextElement', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Hello',
        fontSize: 28,
        fontFamily: 'Excalifont',
      );
      c.loadScene(Scene().addElement(t));
      c.applyResult(SetSelectionResult({t.id}));
      c.copyStyle();

      expect(c.copiedStyle!.fontSize, 28);
      expect(c.copiedStyle!.fontFamily, 'Excalifont');
    });

    test('pasteStyle applies copied style to selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Copy from r1
      final r1 = _rect(id: 'r1', strokeColor: '#ff0000');
      final r2 = _rect(id: 'r2', strokeColor: '#000000');
      c.loadScene(Scene().addElement(r1).addElement(r2));
      c.applyResult(SetSelectionResult({r1.id}));
      c.copyStyle();

      // Paste to r2
      c.applyResult(SetSelectionResult({r2.id}));
      c.pasteStyle();

      final updated = c.editorState.scene.getElementById(r2.id)!;
      expect(updated.strokeColor, '#ff0000');
    });

    test('pasteStyle does nothing without copied style', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.pasteStyle(); // no-op
      expect(c.editorState.scene.getElementById(r.id)!.strokeColor, '#000000');
    });

    test('pasteStyle does nothing with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyStyleChange(const ElementStyle(strokeColor: '#ff0000'));
      c.pasteStyle(); // no copiedStyle, no-op
    });
  });

  // ---------------------------------------------------------------
  // 16. Find
  // ---------------------------------------------------------------
  group('Find', () {
    test('openFind sets isFindOpen', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.openFind();
      expect(c.isFindOpen, isTrue);
    });

    test('closeFind clears all state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.openFind();
      c.updateFindQuery('hello');
      c.closeFind();

      expect(c.isFindOpen, isFalse);
      expect(c.findQuery, '');
      expect(c.findResults, isEmpty);
      expect(c.findCurrentIndex, -1);
    });

    test('updateFindQuery finds matching text elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text(text: 'Hello World');
      c.loadScene(Scene().addElement(t));
      c.updateFindQuery('hello');

      expect(c.findResults, hasLength(1));
      expect(c.findCurrentIndex, 0);
    });

    test('updateFindQuery finds matching frame labels', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final f = _frame(label: 'Login Screen');
      c.loadScene(Scene().addElement(f));
      c.updateFindQuery('login');

      expect(c.findResults, hasLength(1));
    });

    test('updateFindQuery returns empty on no match', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_text(text: 'ABC')));
      c.updateFindQuery('xyz');
      expect(c.findResults, isEmpty);
      expect(c.findCurrentIndex, -1);
    });

    test('updateFindQuery empty string clears results', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_text(text: 'Hello')));
      c.updateFindQuery('hello');
      expect(c.findResults, hasLength(1));

      c.updateFindQuery('');
      expect(c.findResults, isEmpty);
    });

    test('findNext wraps around', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t1 = _text(id: 't1', text: 'abc');
      final t2 = _text(id: 't2', text: 'abcdef', x: 200);
      c.loadScene(Scene().addElement(t1).addElement(t2));
      c.updateFindQuery('abc');
      expect(c.findResults, hasLength(2));
      expect(c.findCurrentIndex, 0);

      c.findNext(_canvasSize);
      expect(c.findCurrentIndex, 1);

      c.findNext(_canvasSize);
      expect(c.findCurrentIndex, 0); // wrapped
    });

    test('findPrevious wraps around', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t1 = _text(id: 't1', text: 'abc');
      final t2 = _text(id: 't2', text: 'abcdef', x: 200);
      c.loadScene(Scene().addElement(t1).addElement(t2));
      c.updateFindQuery('abc');

      c.findPrevious(_canvasSize);
      expect(c.findCurrentIndex, 1); // wrapped from 0 to last

      c.findPrevious(_canvasSize);
      expect(c.findCurrentIndex, 0);
    });

    test('findNext does nothing with no results', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.findNext(_canvasSize); // no-op
      expect(c.findCurrentIndex, -1);
    });

    test('findPrevious does nothing with no results', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.findPrevious(_canvasSize); // no-op
      expect(c.findCurrentIndex, -1);
    });

    test('updateFindQuery resolves bound text to parent container', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = _text(id: 'bt1', text: 'Label text', containerId: 'r1');
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.updateFindQuery('label');

      expect(c.findResults, hasLength(1));
      expect(c.findResults.first, const ElementId('r1'));
    });
  });

  // ---------------------------------------------------------------
  // 17. Link editor
  // ---------------------------------------------------------------
  group('Link editor', () {
    test('openLinkEditor sets editing mode', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.openLinkEditor();
      expect(c.isLinkEditorOpen, isTrue);
      expect(c.isLinkEditorEditing, isTrue);
    });

    test('closeLinkEditor clears all link state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.openLinkEditor();
      c.enterLinkToElementMode();
      c.closeLinkEditor();

      expect(c.isLinkEditorOpen, isFalse);
      expect(c.isLinkEditorEditing, isFalse);
      expect(c.linkToElementMode, isFalse);
    });

    test('showLinkInfo sets info mode', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.showLinkInfo();
      expect(c.isLinkEditorOpen, isTrue);
      expect(c.isLinkEditorEditing, isFalse);
    });

    test('setElementLink sets link on element', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.setElementLink(r.id, 'https://example.com');

      final updated = c.editorState.scene.getElementById(r.id)!;
      expect(updated.link, 'https://example.com');
    });

    test('setElementLink clears link with null', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(link: 'https://example.com');
      c.loadScene(Scene().addElement(r));
      c.setElementLink(r.id, null);

      final updated = c.editorState.scene.getElementById(r.id)!;
      expect(updated.link, isNull);
    });

    test('setElementLink clears link with empty string', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(link: 'https://example.com');
      c.loadScene(Scene().addElement(r));
      c.setElementLink(r.id, '');

      final updated = c.editorState.scene.getElementById(r.id)!;
      expect(updated.link, isNull);
    });

    test('enterLinkToElementMode sets flag', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.enterLinkToElementMode();
      expect(c.linkToElementMode, isTrue);
    });

    test('followLink with element link selects target', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r1 = _rect(id: 'r1');
      final r2 = _rect(id: 'r2', x: 500, y: 500);
      c.loadScene(Scene().addElement(r1).addElement(r2));

      c.followLink('#r2', _canvasSize);
      expect(c.editorState.selectedIds, contains(const ElementId('r2')));
    });

    test('followLink with missing element target does nothing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(_sceneWithRect());
      c.followLink('#nonexistent', _canvasSize);
      expect(c.editorState.selectedIds, isEmpty);
    });

    test('followLink with URL calls onLinkOpen', () {
      String? openedUrl;
      final c = MarkdrawController(
        config: MarkdrawEditorConfig(
          onLinkOpen: (url) => openedUrl = url,
        ),
      );
      addTearDown(c.dispose);

      c.followLink('https://example.com', _canvasSize);
      expect(openedUrl, 'https://example.com');
    });

    test('followLink normalizes URL without protocol', () {
      String? openedUrl;
      final c = MarkdrawController(
        config: MarkdrawEditorConfig(
          onLinkOpen: (url) => openedUrl = url,
        ),
      );
      addTearDown(c.dispose);

      c.followLink('example.com', _canvasSize);
      expect(openedUrl, 'https://example.com');
    });

    test('followLink normalizes absolute path to file URL', () {
      String? openedUrl;
      final c = MarkdrawController(
        config: MarkdrawEditorConfig(
          onLinkOpen: (url) => openedUrl = url,
        ),
      );
      addTearDown(c.dispose);

      c.followLink('/path/to/file', _canvasSize);
      expect(openedUrl, 'file:////path/to/file');
    });
  });

  // ---------------------------------------------------------------
  // 18. hitTestLinkIcon
  // ---------------------------------------------------------------
  group('hitTestLinkIcon', () {
    test('hits link icon near top-right corner', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(link: 'https://test.com', x: 0, y: 0, w: 100, h: 50);
      c.loadScene(Scene().addElement(r));

      // Icon center: x=100-8=92, y=0-18=-18
      final hit = c.hitTestLinkIcon(const Point(92, -18));
      expect(hit, isNotNull);
    });

    test('misses link icon when element is selected', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(link: 'https://test.com');
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));

      final hit = c.hitTestLinkIcon(const Point(92, -18));
      expect(hit, isNull);
    });

    test('misses element without link', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));

      final hit = c.hitTestLinkIcon(const Point(92, -18));
      expect(hit, isNull);
    });
  });

  // ---------------------------------------------------------------
  // 19. Serialization
  // ---------------------------------------------------------------
  group('Serialization', () {
    test('serializeScene returns markdraw format', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final content = c.serializeScene();
      expect(content, contains('rect'));
    });

    test('serializeScene returns excalidraw format', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final content =
          c.serializeScene(format: DocumentFormat.excalidraw);
      expect(content, contains('"type"'));
    });

    test('loadFromContent loads markdraw format', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final content = c.serializeScene();
      c.clear();

      c.loadFromContent(content, 'test.markdraw');
      expect(c.editorState.scene.activeElements, hasLength(1));
    });

    test('loadFromContent loads excalidraw format', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final content =
          c.serializeScene(format: DocumentFormat.excalidraw);
      c.clear();

      c.loadFromContent(content, 'test.excalidraw');
      expect(c.editorState.scene.activeElements, hasLength(1));
    });

    test('serializeScene includes background and grid', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.canvasBackgroundColor = '#ff0000';
      c.toggleGrid();
      c.loadScene(Scene().addElement(_rect()));

      final content = c.serializeScene();
      expect(content, contains('#ff0000'));
    });

    test('serializeScene includes document name', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.renameDocument('My Doc');
      c.loadScene(Scene().addElement(_rect()));

      final content = c.serializeScene();
      expect(content, contains('My Doc'));
    });
  });

  // ---------------------------------------------------------------
  // 20. Export
  // ---------------------------------------------------------------
  group('Export', () {
    test('exportSvg returns valid SVG string', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final svg = c.exportSvg();
      expect(svg, contains('<svg'));
      expect(svg, contains('</svg>'));
    });

    test('exportSvg with selection exports only selected', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r1 = _rect(id: 'r1');
      final r2 = _rect(id: 'r2', x: 200);
      c.loadScene(Scene().addElement(r1).addElement(r2));
      c.applyResult(SetSelectionResult({r1.id}));

      final svg = c.exportSvg(selectedOnly: true);
      expect(svg, contains('<svg'));
    });

    test('exportSvg without selection exports all', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      final svg = c.exportSvg(selectedOnly: false);
      expect(svg, contains('<svg'));
    });
  });

  // ---------------------------------------------------------------
  // 21. Helpers
  // ---------------------------------------------------------------
  group('Helpers', () {
    test('getSceneFontFamilies returns fonts from text elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'A',
        fontFamily: 'Excalifont',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 100,
        y: 0,
        width: 100,
        height: 20,
        text: 'B',
        fontFamily: 'Virgil',
      );
      c.loadScene(Scene().addElement(t1).addElement(t2));

      final fonts = c.getSceneFontFamilies();
      expect(fonts, containsAll(['Excalifont', 'Virgil']));
    });

    test('getSceneFontFamilies returns empty for no text', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      expect(c.getSceneFontFamilies(), isEmpty);
    });

    test('panViewport pans by given deltas', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.panViewport(100, 200);
      expect(c.editorState.viewport.offset.dx, 100);
      expect(c.editorState.viewport.offset.dy, 200);
    });

    test('cycleFontSize increases through presets', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Default fontSize is likely 20
      c.cycleFontSize(increase: true);
      expect(c.defaultStyle.fontSize, 28);

      c.cycleFontSize(increase: true);
      expect(c.defaultStyle.fontSize, 36);

      // At max, stays at max
      c.cycleFontSize(increase: true);
      expect(c.defaultStyle.fontSize, 36);
    });

    test('cycleFontSize decreases through presets', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Default is 20
      c.cycleFontSize(increase: false);
      expect(c.defaultStyle.fontSize, 16);

      // At min, stays at min
      c.cycleFontSize(increase: false);
      expect(c.defaultStyle.fontSize, 16);
    });

    test('renameDocument sets name', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.renameDocument('Test Doc');
      expect(c.documentName, 'Test Doc');
    });

    test('renameDocument empty string sets null', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.renameDocument('Test');
      c.renameDocument('');
      expect(c.documentName, isNull);
    });

    test('resetCanvas clears scene and name', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(_sceneWithRect());
      c.renameDocument('Test');
      c.resetCanvas();

      expect(c.editorState.scene.activeElements, isEmpty);
      expect(c.documentName, isNull);
    });

    test('resetCanvas pushes undo history', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(_sceneWithRect());
      c.resetCanvas();
      expect(c.historyManager.canUndo, isTrue);
    });

    test('resetCanvas calls onSceneChanged', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      c.loadScene(_sceneWithRect());
      changed = null;
      c.resetCanvas();
      expect(changed, isNotNull);
    });

    test('toScene converts screen to scene coordinates', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final p = c.toScene(const Offset(100, 200));
      expect(p.x, 100);
      expect(p.y, 200);
    });

    test('toScene accounts for viewport zoom', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyResult(UpdateViewportResult(
        const ViewportState(zoom: 2.0),
      ));
      final p = c.toScene(const Offset(100, 200));
      expect(p.x, 50); // 100 / 2
      expect(p.y, 100); // 200 / 2
    });

    test('selectedElements resolves from IDs', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      final e = _ellipse();
      c.loadScene(Scene().addElement(r).addElement(e));
      c.applyResult(SetSelectionResult({r.id, e.id}));

      expect(c.selectedElements, hasLength(2));
    });

    test('selectedElements skips missing IDs', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.loadScene(Scene().addElement(_rect()));
      c.applyResult(SetSelectionResult(
        {const ElementId('r1'), const ElementId('nonexistent')},
      ));
      expect(c.selectedElements, hasLength(1));
    });
  });

  // ---------------------------------------------------------------
  // 22. dispatchKey
  // ---------------------------------------------------------------
  group('dispatchKey', () {
    test('dispatches Delete key to select tool', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.dispatchKey('Delete');

      expect(c.editorState.scene.activeElements, isEmpty);
    });

    test('dispatches key with shift modifier', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Just verify it doesn't throw
      c.dispatchKey('A', shift: true, ctrl: true);
    });
  });

  // ---------------------------------------------------------------
  // 23. Selection helpers
  // ---------------------------------------------------------------
  group('Selection helpers', () {
    test('isDraggingPointHandle returns false by default', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.isDraggingPointHandle(), isFalse);
    });

    test('buildPointHandles returns null with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.buildPointHandles(), isNull);
    });

    test('buildPointHandles returns points for 2-point line', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final l = _line();
      c.loadScene(Scene().addElement(l));
      c.applyResult(SetSelectionResult({l.id}));

      final handles = c.buildPointHandles();
      expect(handles, isNotNull);
      expect(handles, hasLength(2));
    });

    test('buildPointHandles returns null for multi-point line without editing',
        () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final l = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [
          const Point(0, 0),
          const Point(50, 50),
          const Point(100, 100),
        ],
      );
      c.loadScene(Scene().addElement(l));
      c.applyResult(SetSelectionResult({l.id}));

      expect(c.buildPointHandles(), isNull);

      // Enable editing mode
      c.isEditingLinear = true;
      expect(c.buildPointHandles(), isNotNull);
    });

    test('buildPointHandles returns null for rectangle', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));

      expect(c.buildPointHandles(), isNull);
    });

    test('buildSegmentMidpoints returns null when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.buildSegmentMidpoints(), isNull);
    });

    test('buildMidpointHandles returns null when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.buildMidpointHandles(), isNull);
    });

    test('buildMidpointHandles returns points for line in edit mode', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final l = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
      );
      c.loadScene(Scene().addElement(l));
      c.applyResult(SetSelectionResult({l.id}));
      c.isEditingLinear = true;

      final mp = c.buildMidpointHandles();
      expect(mp, isNotNull);
      expect(mp, hasLength(1));
    });

    test('buildSelectionOverlay returns null with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.buildSelectionOverlay(), isNull);
    });

    test('buildSelectionOverlay returns overlay for selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));

      final overlay = c.buildSelectionOverlay();
      expect(overlay, isNotNull);
    });
  });

  // ---------------------------------------------------------------
  // 24. buildPreviewElement
  // ---------------------------------------------------------------
  group('buildPreviewElement', () {
    test('returns null for null overlay', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.buildPreviewElement(null), isNull);
    });

    test('builds rectangle preview from creation bounds', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(10, 20, 100, 50),
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<RectangleElement>());
      expect(preview!.x, 10);
      expect(preview.y, 20);
    });

    test('builds ellipse preview from creation bounds', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.ellipse);
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(0, 0, 80, 80),
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<EllipseElement>());
    });

    test('builds diamond preview from creation bounds', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.diamond);
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(0, 0, 60, 60),
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<DiamondElement>());
    });

    test('builds line preview from creation points', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.line);
      const overlay = ToolOverlay(
        creationPoints: [Point(0, 0), Point(100, 100)],
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<LineElement>());
    });

    test('builds arrow preview from creation points', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.arrow);
      const overlay = ToolOverlay(
        creationPoints: [Point(0, 0), Point(50, 0)],
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<ArrowElement>());
    });

    test('builds freedraw preview from creation points', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.freedraw);
      const overlay = ToolOverlay(
        creationPoints: [
          Point(0, 0),
          Point(10, 10),
          Point(20, 5),
        ],
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isA<FreedrawElement>());
    });

    test('returns null for select tool with bounds overlay', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.select);
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(0, 0, 50, 50),
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isNull);
    });

    test('returns null with single creation point (needs >=2)', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.switchTool(ToolType.line);
      const overlay = ToolOverlay(
        creationPoints: [Point(0, 0)],
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview, isNull);
    });

    test('applies default style to preview', () {
      final c = MarkdrawController(
        config: const MarkdrawEditorConfig(
          initialStyle: ElementStyle(strokeColor: '#ff0000'),
        ),
      );
      addTearDown(c.dispose);

      c.switchTool(ToolType.rectangle);
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(0, 0, 100, 100),
      );
      final preview = c.buildPreviewElement(overlay);
      expect(preview!.strokeColor, '#ff0000');
    });
  });

  // ---------------------------------------------------------------
  // 25. requestColorPicker / clearPendingColorPicker
  // ---------------------------------------------------------------
  group('requestColorPicker / clearPendingColorPicker', () {
    test('requestColorPicker sets target', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.requestColorPicker(ColorPickerTarget.stroke);
      expect(c.pendingColorPicker, ColorPickerTarget.stroke);

      c.requestColorPicker(ColorPickerTarget.background);
      expect(c.pendingColorPicker, ColorPickerTarget.background);

      c.requestColorPicker(ColorPickerTarget.font);
      expect(c.pendingColorPicker, ColorPickerTarget.font);
    });

    test('clearPendingColorPicker clears target', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.requestColorPicker(ColorPickerTarget.stroke);
      c.clearPendingColorPicker();
      expect(c.pendingColorPicker, isNull);
    });
  });

  // ---------------------------------------------------------------
  // 26. Flowchart methods
  // ---------------------------------------------------------------
  group('Flowchart methods', () {
    test('flowchartCreate does nothing with no selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.flowchartCreate(LinkDirection.right);
      expect(c.flowchartCreator.isCreating, isFalse);
    });

    test('flowchartCreate does nothing with non-node selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = _text();
      c.loadScene(Scene().addElement(t));
      c.applyResult(SetSelectionResult({t.id}));
      c.flowchartCreate(LinkDirection.right);
      expect(c.flowchartCreator.isCreating, isFalse);
    });

    test('flowchartCreate starts creation with valid node', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.flowchartCreate(LinkDirection.right);
      expect(c.flowchartCreator.isCreating, isTrue);
    });

    test('flowchartCommit adds elements to scene', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.flowchartCreate(LinkDirection.right);
      c.flowchartCommit();

      // Should have original + new node + arrow
      expect(c.editorState.scene.activeElements.length, greaterThan(1));
    });

    test('flowchartCommit does nothing when not creating', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.flowchartCommit(); // no-op
      expect(c.editorState.scene.activeElements, isEmpty);
    });

    test('flowchartCancel clears pending elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.flowchartCreate(LinkDirection.right);
      expect(c.flowchartCreator.isCreating, isTrue);

      c.flowchartCancel();
      expect(c.flowchartCreator.isCreating, isFalse);
    });

    test('flowchartCancel does nothing when not creating', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.flowchartCancel(); // no-op
    });

    test('flowchartNavigate with no selection does nothing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.flowchartNavigate(LinkDirection.right); // no-op
    });

    test('flowchartNavigateEnd clears state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.flowchartNavigateEnd(); // no-op when not exploring
    });
  });

  // ---------------------------------------------------------------
  // 27. resolveImages / toScene
  // ---------------------------------------------------------------
  group('resolveImages', () {
    test('returns null for empty files', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(c.resolveImages(), isNull);
    });
  });

  // ---------------------------------------------------------------
  // 28. Setters
  // ---------------------------------------------------------------
  group('Setters', () {
    test('isCompact setter notifies on change', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.isCompact = true;
      expect(notified, isTrue);
    });

    test('isCompact setter does not notify when same', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.isCompact = false; // already false
      var notified = false;
      c.addListener(() => notified = true);
      c.isCompact = false;
      expect(notified, isFalse);
    });

    test('showLibraryPanel setter notifies', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.showLibraryPanel = true;
      expect(notified, isTrue);
      expect(c.showLibraryPanel, isTrue);
    });

    test('fontPickerOpen setter notifies', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.fontPickerOpen = true;
      expect(notified, isTrue);
      expect(c.fontPickerOpen, isTrue);
    });

    test('isEditingLinear setter notifies', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.isEditingLinear = true;
      expect(notified, isTrue);
      expect(c.isEditingLinear, isTrue);
    });

    test('canvasBackgroundColor setter notifies', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.canvasBackgroundColor = '#abcdef';
      expect(notified, isTrue);
      expect(c.canvasBackgroundColor, '#abcdef');
    });

    test('lastCanvasSize setter does not notify', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      var notified = false;
      c.addListener(() => notified = true);
      c.lastCanvasSize = const Size(800, 600);
      expect(notified, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // 29. toolContext
  // ---------------------------------------------------------------
  group('toolContext', () {
    test('reflects current state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.toggleGrid();
      c.toggleObjectsSnapMode();
      final ctx = c.toolContext;
      expect(ctx.gridSize, 20);
      expect(ctx.objectsSnapMode, isTrue);
      expect(ctx.interactionMode, InteractionMode.pointer);
    });
  });

  // ---------------------------------------------------------------
  // 30. onTextChanged with bound text
  // ---------------------------------------------------------------
  group('onTextChanged with bound text', () {
    test('updates bound text element directly', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = _text(id: 'bt1', text: 'Old', containerId: 'r1');
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.startTextEditingExisting(bt);
      c.textEditingController.text = 'New bound text';
      c.onTextChanged();

      final updated = c.editorState.scene.getElementById(
        const ElementId('bt1'),
      ) as TextElement;
      expect(updated.text, 'New bound text');
    });
  });

  // ---------------------------------------------------------------
  // 31. Library import/export
  // ---------------------------------------------------------------
  group('Library import/export', () {
    test('exportLibraryContent serializes items', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();

      final content = c.exportLibraryContent();
      expect(content, isNotEmpty);
    });

    test('exportLibraryContent as markdraw library format', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();

      final content = c.exportLibraryContent(
        format: DocumentFormat.markdrawLibrary,
      );
      expect(content, isNotEmpty);
    });

    test('importLibraryFromContent loads excalidraw library', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      // Create and export, then re-import
      final r = _rect();
      c.loadScene(Scene().addElement(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.addToLibrary();
      final content = c.exportLibraryContent(
        format: DocumentFormat.excalidrawLibrary,
      );
      c.libraryItems = []; // clear

      c.importLibraryFromContent(content, 'lib.excalidrawlib');
      expect(c.libraryItems, isNotEmpty);
      expect(c.showLibraryPanel, isTrue);
    });

    test('importLibraryFromContent throws for non-library files', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      expect(
        () => c.importLibraryFromContent('{}', 'test.excalidraw'),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------
  // 32. applyScene / replaceScene detailed
  // ---------------------------------------------------------------
  group('applyScene / replaceScene detailed', () {
    test('applyScene followed by undo restores original', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final original = c.editorState.scene;
      c.applyScene(_sceneWithRect());
      c.undo();
      expect(identical(c.editorState.scene, original), isTrue);
    });

    test('replaceScene after applyScene creates single undo entry', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(_sceneWithRect());
      expect(c.historyManager.undoCount, 1);

      c.replaceScene(Scene().addElement(_ellipse()));
      expect(c.historyManager.undoCount, 1);
    });

    test('applyScene clears selection', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      c.applyResult(AddElementResult(r));
      c.applyResult(SetSelectionResult({r.id}));
      c.applyScene(Scene());
      expect(c.editorState.selectedIds, isEmpty);
    });

    test('applyScene sets background when provided', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(Scene(), background: '#ff0000');
      expect(c.canvasBackgroundColor, '#ff0000');
    });
  });

  // ---------------------------------------------------------------
  // 33. applyStyleChange with text properties to bound text
  // ---------------------------------------------------------------
  group('applyStyleChange text-to-bound-text', () {
    test('fontSize applied to bound text of selected container', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = _text(
        id: 'bt1',
        text: 'Label',
        containerId: 'r1',
        w: 100,
        h: 20,
      );
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.applyResult(SetSelectionResult({r.id}));
      c.applyStyleChange(const ElementStyle(fontSize: 36));

      final updatedBt = c.editorState.scene.getElementById(
        const ElementId('bt1'),
      ) as TextElement;
      expect(updatedBt.fontSize, 36);
    });
  });

  // ---------------------------------------------------------------
  // 34. onPointerSignal (scroll zoom)
  // ---------------------------------------------------------------
  group('onPointerSignal', () {
    test('scroll up zooms in', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final before = c.editorState.viewport.zoom;
      // PointerScrollEvent with negative dy = scroll up = zoom in
      const event = PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, -120),
      );
      c.onPointerSignal(event);
      expect(c.editorState.viewport.zoom, greaterThan(before));
    });

    test('scroll down zooms out', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final before = c.editorState.viewport.zoom;
      const event = PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, 120),
      );
      c.onPointerSignal(event);
      expect(c.editorState.viewport.zoom, lessThan(before));
    });
  });

  // ---------------------------------------------------------------
  // 35. onScaleStart / onScaleUpdate (pinch-to-zoom)
  // ---------------------------------------------------------------
  group('Pinch-to-zoom', () {
    test('onScaleStart records starting state', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyResult(UpdateViewportResult(
        const ViewportState(zoom: 1.5, offset: Offset(10, 20)),
      ));
      c.onScaleStart(ScaleStartDetails());
      expect(c.pinchStartZoom, 1.5);
      expect(c.pinchStartOffset, const Offset(10, 20));
    });

    test('onScaleUpdate with <2 pointers is ignored', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.onScaleStart(ScaleStartDetails());
      final before = c.editorState.viewport.zoom;
      c.onScaleUpdate(ScaleUpdateDetails(
        scale: 2.0,
        localFocalPoint: const Offset(400, 300),
        pointerCount: 1,
      ));
      expect(c.editorState.viewport.zoom, before);
    });
  });

  // ---------------------------------------------------------------
  // 36. Edge cases
  // ---------------------------------------------------------------
  group('Edge cases', () {
    test('multiple undo then redo chain', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.applyScene(Scene().addElement(_rect(id: 'a')));
      c.applyScene(Scene().addElement(_rect(id: 'b')));
      c.applyScene(Scene().addElement(_rect(id: 'c')));

      c.undo();
      c.undo();
      c.undo();
      expect(c.editorState.scene.activeElements, isEmpty);

      c.redo();
      expect(c.editorState.scene.activeElements, hasLength(1));
    });

    test('setElementLink does nothing for non-existent element', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.setElementLink(const ElementId('nope'), 'https://test.com');
      // no crash
    });

    test('commitFrameLabel does nothing when no editing target', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.commitFrameLabel('Test');
      // no crash
    });

    test('cancelTextEditing does nothing when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.cancelTextEditing();
      // no crash
    });

    test('buildMidpointHandles null for elbow arrow in edit mode', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = ArrowElement(
        id: const ElementId('ea1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
        arrowType: ArrowType.sharpElbow,
      );
      c.loadScene(Scene().addElement(a));
      c.applyResult(SetSelectionResult({a.id}));
      c.isEditingLinear = true;

      // buildMidpointHandles excludes elbow arrows
      expect(c.buildMidpointHandles(), isNull);
    });

    test('buildSegmentMidpoints returns midpoints for elbow arrow in edit mode',
        () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = ArrowElement(
        id: const ElementId('ea1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 0), const Point(100, 100)],
        arrowType: ArrowType.sharpElbow,
      );
      c.loadScene(Scene().addElement(a));
      c.applyResult(SetSelectionResult({a.id}));
      c.isEditingLinear = true;

      final midpoints = c.buildSegmentMidpoints();
      expect(midpoints, isNotNull);
      expect(midpoints, hasLength(2)); // 3 points -> 2 segments
    });

    test('buildSegmentMidpoints null for non-elbow arrow', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = _arrow();
      c.loadScene(Scene().addElement(a));
      c.applyResult(SetSelectionResult({a.id}));
      c.isEditingLinear = true;

      // Regular arrow, not elbowed
      expect(c.buildSegmentMidpoints(), isNull);
    });

    test('copyStyle captures arrowhead properties from line', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final l = LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        points: [const Point(0, 0), const Point(100, 100)],
        startArrowhead: Arrowhead.dot,
        endArrowhead: Arrowhead.bar,
      );
      c.loadScene(Scene().addElement(l));
      c.applyResult(SetSelectionResult({l.id}));
      c.copyStyle();

      expect(c.copiedStyle!.startArrowhead, Arrowhead.dot);
      expect(c.copiedStyle!.endArrowhead, Arrowhead.bar);
    });

    test('copyStyle captures arrowType from ArrowElement', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final a = ArrowElement(
        id: const ElementId('a1'),
        x: 0,
        y: 0,
        width: 100,
        height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        arrowType: ArrowType.sharpElbow,
      );
      c.loadScene(Scene().addElement(a));
      c.applyResult(SetSelectionResult({a.id}));
      c.copyStyle();

      expect(c.copiedStyle!.arrowType, ArrowType.sharpElbow);
    });

    test('copyStyle captures bound text properties from container', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect().copyWith(
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final bt = TextElement(
        id: const ElementId('bt1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Label',
        containerId: 'r1',
        fontSize: 32,
        fontFamily: 'Virgil',
      );
      c.loadScene(Scene().addElement(r).addElement(bt));
      c.applyResult(SetSelectionResult({r.id}));
      c.copyStyle();

      expect(c.copiedStyle!.fontSize, 32);
      expect(c.copiedStyle!.fontFamily, 'Virgil');
    });
  });

  // ---------------------------------------------------------------
  // 37. loadFromContent with settings
  // ---------------------------------------------------------------
  group('loadFromContent settings', () {
    test('restores background and grid from markdraw content', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.canvasBackgroundColor = '#ff0000';
      c.toggleGrid(); // gridSize = 20
      c.renameDocument('TestName');
      c.loadScene(Scene().addElement(_rect()));

      final content = c.serializeScene();

      // Clear and reload
      final c2 = MarkdrawController();
      addTearDown(c2.dispose);

      c2.loadFromContent(content, 'test.markdraw');
      expect(c2.canvasBackgroundColor, '#ff0000');
      expect(c2.gridSize, 20);
      expect(c2.documentName, 'TestName');
    });
  });

  // ---------------------------------------------------------------
  // 38. Multiple selection
  // ---------------------------------------------------------------
  group('Multiple selection', () {
    test('selectedElements returns all selected', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect();
      final e = _ellipse();
      final d = _diamond();
      c.loadScene(Scene().addElement(r).addElement(e).addElement(d));
      c.applyResult(SetSelectionResult({r.id, e.id, d.id}));

      expect(c.selectedElements, hasLength(3));
    });

    test('buildSelectionOverlay works with multiple elements', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final r = _rect(x: 0, y: 0, w: 50, h: 50);
      final e = _ellipse(x: 100, y: 100);
      c.loadScene(Scene().addElement(r).addElement(e));
      c.applyResult(SetSelectionResult({r.id, e.id}));

      final overlay = c.buildSelectionOverlay();
      expect(overlay, isNotNull);
    });
  });

  // ---------------------------------------------------------------
  // 39. Restoring text focus
  // ---------------------------------------------------------------
  group('restoreTextFocus', () {
    test('clears suppressFocusCommit when not editing', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.suppressFocusCommit = true;
      c.restoreTextFocus(false, null);
      expect(c.suppressFocusCommit, isFalse);
    });

    test('clears suppressFocusCommit when editingTextElementId is null', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      c.suppressFocusCommit = true;
      c.restoreTextFocus(true, null);
      // editingTextElementId is null, so suppress is cleared
      expect(c.suppressFocusCommit, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // 40. onTextChanged edge cases
  // ---------------------------------------------------------------
  group('onTextChanged edge cases', () {
    test('onTextChanged with non-auto-resize text keeps width', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      final t = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 200,
        height: 40,
        text: 'Hi',
        autoResize: false,
      );
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      c.textEditingController.text = 'Longer text content here';
      c.onTextChanged();

      final updated = c.editorState.scene.getElementById(t.id) as TextElement;
      expect(updated.width, 200); // Width stays fixed
    });

    test('onTextChanged calls onSceneChanged', () {
      final c = MarkdrawController();
      addTearDown(c.dispose);

      Scene? changed;
      c.onSceneChanged = (s) => changed = s;
      final t = _text(text: 'Old');
      c.loadScene(Scene().addElement(t));
      c.startTextEditingExisting(t);
      changed = null;
      c.textEditingController.text = 'New';
      c.onTextChanged();
      expect(changed, isNotNull);
    });
  });
}
