library;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import 'package:markdraw/markdraw.dart' hide TextAlign;


/// Builds shortcut bindings for system-level shortcuts (Cmd+S, Cmd+O, etc.)
/// that macOS intercepts before KeyEvent reaches Flutter.
Map<ShortcutActivator, VoidCallback> buildShortcutBindings({
  required VoidCallback onSave,
  required VoidCallback onSaveAs,
  required VoidCallback onOpen,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
  required VoidCallback onExportPng,
  required VoidCallback onZoomIn,
  required VoidCallback onZoomOut,
  required VoidCallback onResetZoom,
}) {
  return {
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true): onSave,
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
        onSaveAs,
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true): onOpen,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): onUndo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        onRedo,
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        onExportPng,
    const SingleActivator(LogicalKeyboardKey.keyY, meta: true): onRedo,
    // Ctrl variants for non-macOS platforms
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): onSave,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
        onSaveAs,
    const SingleActivator(LogicalKeyboardKey.keyO, control: true): onOpen,
    const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
        onExportPng,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): onUndo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        onRedo,
    const SingleActivator(LogicalKeyboardKey.keyY, control: true): onRedo,
    // Zoom shortcuts — meta (macOS)
    const SingleActivator(LogicalKeyboardKey.equal, meta: true): onZoomIn,
    const SingleActivator(LogicalKeyboardKey.minus, meta: true): onZoomOut,
    const SingleActivator(LogicalKeyboardKey.digit0, meta: true): onResetZoom,
    // Zoom shortcuts — ctrl
    const SingleActivator(LogicalKeyboardKey.equal, control: true): onZoomIn,
    const SingleActivator(LogicalKeyboardKey.minus, control: true): onZoomOut,
    const SingleActivator(LogicalKeyboardKey.digit0, control: true):
        onResetZoom,
    // Grid toggle is handled in handleKeyEvent — not here, because Cmd+'
    // is NOT intercepted by macOS (unlike Cmd+S/Z) and would double-fire.
  };
}

/// Handles key events dispatched to the editor.
void handleKeyEvent({
  required KeyEvent event,
  required MarkdrawController controller,
  required Size Function() getCanvasSize,
  required VoidCallback onSave,
  required VoidCallback onSaveAs,
  required VoidCallback onOpen,
  required VoidCallback onExportPng,
  required VoidCallback onImportImage,
  required void Function(ThemeMode) onThemeToggle,
  required ThemeMode Function() getCurrentThemeMode,
  required BuildContext context,
  void Function(Element element)? onShowLinkDialog,
}) {
  // Don't intercept keys while editing text
  if (controller.editingTextElementId != null) return;

  if (event is! KeyDownEvent) return;
  final key = event.logicalKey;
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final ctrl = HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;


  final alt = HardwareKeyboard.instance.isAltPressed;

  // Zen mode: Alt+Z
  if (alt && !ctrl && !shift && key == LogicalKeyboardKey.keyZ) {
    controller.toggleZenMode();
    return;
  }

  // View mode: Alt+R
  if (alt && !ctrl && !shift && key == LogicalKeyboardKey.keyR) {
    controller.toggleViewMode();
    return;
  }

  // Block tool shortcuts when in view mode (except hand tool)
  if (controller.viewMode) return;

  // Page scrolling: PgDn/PgUp pans viewport by canvas height (Shift for horizontal)
  if (key == LogicalKeyboardKey.pageDown ||
      key == LogicalKeyboardKey.pageUp) {
    final size = getCanvasSize();
    final down = key == LogicalKeyboardKey.pageDown;
    if (shift) {
      controller.panViewport(
        down ? size.width / controller.editorState.viewport.zoom : -size.width / controller.editorState.viewport.zoom,
        0,
      );
    } else {
      controller.panViewport(
        0,
        down ? size.height / controller.editorState.viewport.zoom : -size.height / controller.editorState.viewport.zoom,
      );
    }
    return;
  }

  // Reset canvas: Ctrl+Delete
  if (ctrl && !shift && key == LogicalKeyboardKey.delete) {
    controller.resetCanvas();
    return;
  }

  // Font size cycling: Ctrl+Shift+< / Ctrl+Shift+>
  if (ctrl && shift &&
      (key == LogicalKeyboardKey.comma ||
          key == LogicalKeyboardKey.period ||
          key == LogicalKeyboardKey.less ||
          key == LogicalKeyboardKey.greater)) {
    final increase = key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.greater;
    controller.cycleFontSize(increase: increase);
    return;
  }

  // Copy/paste styles: Ctrl+Alt+C / Ctrl+Alt+V (before regular Ctrl+C/V)
  if (ctrl && alt && !shift && key == LogicalKeyboardKey.keyC) {
    controller.copyStyle();
    return;
  }
  if (ctrl && alt && !shift && key == LogicalKeyboardKey.keyV) {
    controller.pasteStyle();
    return;
  }

  // Paste as plaintext: Ctrl+Shift+V
  if (ctrl && shift && key == LogicalKeyboardKey.keyV) {
    controller.pasteAsPlaintext(getCanvasSize());
    return;
  }

  // Undo/redo
  if (ctrl && key == LogicalKeyboardKey.keyZ) {
    if (shift) {
      controller.redo();
    } else {
      controller.undo();
    }
    return;
  }
  if (ctrl && key == LogicalKeyboardKey.keyY) {
    controller.redo();
    return;
  }

  // File shortcuts
  if (ctrl && key == LogicalKeyboardKey.keyS) {
    if (shift) {
      onSaveAs();
    } else {
      onSave();
    }
    return;
  }
  if (ctrl && key == LogicalKeyboardKey.keyO) {
    onOpen();
    return;
  }

  // Zoom shortcuts
  if (ctrl && key == LogicalKeyboardKey.equal) {
    controller.zoomIn(getCanvasSize());
    return;
  }
  if (ctrl && key == LogicalKeyboardKey.minus) {
    controller.zoomOut(getCanvasSize());
    return;
  }
  if (ctrl && key == LogicalKeyboardKey.digit0) {
    controller.resetZoom();
    return;
  }

  // Link shortcut
  if (ctrl && !shift && key == LogicalKeyboardKey.keyK) {
    final elements = controller.selectedElements;
    if (elements.length == 1 && onShowLinkDialog != null) {
      onShowLinkDialog(elements.first);
    }
    return;
  }

  // Grid toggle: Ctrl/Cmd+' (matches Excalidraw which uses event.code)
  if (ctrl &&
      (key == LogicalKeyboardKey.quoteSingle ||
          key == LogicalKeyboardKey.quote ||
          event.physicalKey == PhysicalKeyboardKey.quote)) {
    controller.toggleGrid();
    return;
  }

  // Alt+Shift+D: toggle theme
  if (alt && shift && key == LogicalKeyboardKey.keyD) {
    final current = getCurrentThemeMode();
    onThemeToggle(switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    });
    return;
  }

  // Shift+1: zoom to fit, Shift+2: zoom to selection
  if (!ctrl && shift) {
    if (key == LogicalKeyboardKey.digit1) {
      controller.zoomToFit(getCanvasSize());
      return;
    }
    if (key == LogicalKeyboardKey.digit2) {
      controller.zoomToSelection(getCanvasSize());
      return;
    }
  }

  // ? key opens help dialog
  if (!ctrl && key.keyLabel == '?') {
    showHelpDialog(context);
    return;
  }

  // Tool lock toggle (Q)
  if (!ctrl && !shift && key == LogicalKeyboardKey.keyQ) {
    controller.toggleToolLocked();
    return;
  }

  // Color picker shortcuts: S (stroke), G (background) — select tool only
  if (!ctrl && !shift && !alt &&
      controller.editorState.activeToolType == ToolType.select) {
    if (key == LogicalKeyboardKey.keyS) {
      controller.requestColorPicker(ColorPickerTarget.stroke);
      return;
    }
    if (key == LogicalKeyboardKey.keyG) {
      controller.requestColorPicker(ColorPickerTarget.background);
      return;
    }
  }

  // Font picker shortcut: Shift+F — select tool only
  if (!ctrl && shift && !alt &&
      controller.editorState.activeToolType == ToolType.select &&
      key == LogicalKeyboardKey.keyF) {
    controller.requestColorPicker(ColorPickerTarget.font);
    return;
  }

  // Tool shortcuts (no modifier keys)
  if (!ctrl && !shift) {
    final label = key.keyLabel;
    if (label.length == 1) {
      if (label == '9') {
        onImportImage();
        return;
      }
      final toolType = toolTypeForKey(label.toLowerCase());
      if (toolType != null) {
        controller.switchTool(toolType);
        return;
      }
    }
  }

  // Escape exits linear editing mode
  if (key == LogicalKeyboardKey.escape && controller.isEditingLinear) {
    controller.isEditingLinear = false;
    return;
  }

  // Pass to tool
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
  } else if (key == LogicalKeyboardKey.tab) {
    keyName = 'Tab';
  } else if (key.keyLabel.length == 1) {
    keyName = key.keyLabel.toLowerCase();
  }

  if (keyName != null) {
    final result = controller.activeTool.onKeyEvent(
      keyName,
      shift: shift,
      ctrl: ctrl,
      context: controller.toolContext,
    );
    if (isSceneChangingResult(result)) {
      controller.historyManager.push(controller.editorState.scene);
    }
    controller.applyResult(result);
  }
}
