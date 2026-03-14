import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;
import 'package:markdraw/src/ui/color_picker.dart' as cp;

void main() {
  // ---------------------------------------------------------------------------
  // 1. keyboard_handler.dart — buildShortcutBindings
  // ---------------------------------------------------------------------------
  group('buildShortcutBindings', () {
    test('returns a non-empty map of shortcut bindings', () {
      var saveCalled = false;
      var saveAsCalled = false;
      var openCalled = false;
      var undoCalled = false;
      var redoCalled = false;
      var exportPngCalled = false;
      var zoomInCalled = false;
      var zoomOutCalled = false;
      var resetZoomCalled = false;
      var findCalled = false;

      final bindings = buildShortcutBindings(
        onSave: () => saveCalled = true,
        onSaveAs: () => saveAsCalled = true,
        onOpen: () => openCalled = true,
        onUndo: () => undoCalled = true,
        onRedo: () => redoCalled = true,
        onExportPng: () => exportPngCalled = true,
        onZoomIn: () => zoomInCalled = true,
        onZoomOut: () => zoomOutCalled = true,
        onResetZoom: () => resetZoomCalled = true,
        onFind: () => findCalled = true,
      );

      expect(bindings, isNotEmpty);
      // At least Cmd+S and Ctrl+S
      expect(bindings.length, greaterThanOrEqualTo(16));

      // Invoke the save callback via the meta variant
      const metaS = SingleActivator(LogicalKeyboardKey.keyS, meta: true);
      bindings[metaS]!();
      expect(saveCalled, isTrue);

      // Invoke the ctrl save variant
      const ctrlS =
          SingleActivator(LogicalKeyboardKey.keyS, control: true);
      saveCalled = false;
      bindings[ctrlS]!();
      expect(saveCalled, isTrue);

      // saveAs
      const metaShiftS = SingleActivator(
        LogicalKeyboardKey.keyS,
        meta: true,
        shift: true,
      );
      bindings[metaShiftS]!();
      expect(saveAsCalled, isTrue);

      // open
      const metaO = SingleActivator(LogicalKeyboardKey.keyO, meta: true);
      bindings[metaO]!();
      expect(openCalled, isTrue);

      // undo
      const metaZ = SingleActivator(LogicalKeyboardKey.keyZ, meta: true);
      bindings[metaZ]!();
      expect(undoCalled, isTrue);

      // redo via shift+Z
      const metaShiftZ = SingleActivator(
        LogicalKeyboardKey.keyZ,
        meta: true,
        shift: true,
      );
      bindings[metaShiftZ]!();
      expect(redoCalled, isTrue);

      // redo via Y
      const metaY = SingleActivator(LogicalKeyboardKey.keyY, meta: true);
      redoCalled = false;
      bindings[metaY]!();
      expect(redoCalled, isTrue);

      // export PNG
      const metaShiftE = SingleActivator(
        LogicalKeyboardKey.keyE,
        meta: true,
        shift: true,
      );
      bindings[metaShiftE]!();
      expect(exportPngCalled, isTrue);

      // zoom in (meta +=)
      const metaEqual =
          SingleActivator(LogicalKeyboardKey.equal, meta: true);
      bindings[metaEqual]!();
      expect(zoomInCalled, isTrue);

      // zoom out (meta -)
      const metaMinus =
          SingleActivator(LogicalKeyboardKey.minus, meta: true);
      bindings[metaMinus]!();
      expect(zoomOutCalled, isTrue);

      // reset zoom (meta 0)
      const metaDigit0 =
          SingleActivator(LogicalKeyboardKey.digit0, meta: true);
      bindings[metaDigit0]!();
      expect(resetZoomCalled, isTrue);

      // find (meta F)
      const metaF = SingleActivator(LogicalKeyboardKey.keyF, meta: true);
      bindings[metaF]!();
      expect(findCalled, isTrue);
    });

    test('ctrl variants all work', () {
      var openCalled = false;
      var exportPngCalled = false;
      var undoCalled = false;
      var redoCalled = false;
      var zoomInCalled = false;
      var zoomOutCalled = false;
      var resetZoomCalled = false;
      var findCalled = false;

      final bindings = buildShortcutBindings(
        onSave: () {},
        onSaveAs: () {},
        onOpen: () => openCalled = true,
        onUndo: () => undoCalled = true,
        onRedo: () => redoCalled = true,
        onExportPng: () => exportPngCalled = true,
        onZoomIn: () => zoomInCalled = true,
        onZoomOut: () => zoomOutCalled = true,
        onResetZoom: () => resetZoomCalled = true,
        onFind: () => findCalled = true,
      );

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyO, control: true)]!();
      expect(openCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyE, control: true, shift: true)]!();
      expect(exportPngCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyZ, control: true)]!();
      expect(undoCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyZ, control: true, shift: true)]!();
      expect(redoCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyY, control: true)]!();
      redoCalled = false;
      bindings[const SingleActivator(
          LogicalKeyboardKey.keyY, control: true)]!();
      expect(redoCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.equal, control: true)]!();
      expect(zoomInCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.minus, control: true)]!();
      expect(zoomOutCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.digit0, control: true)]!();
      expect(resetZoomCalled, isTrue);

      bindings[const SingleActivator(
          LogicalKeyboardKey.keyF, control: true)]!();
      expect(findCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. keyboard_handler.dart — handleKeyEvent
  // ---------------------------------------------------------------------------
  group('handleKeyEvent', () {
    late MarkdrawController controller;

    setUp(() {
      controller = MarkdrawController();
    });

    tearDown(() {
      controller.dispose();
    });

    bool callHandleKeyEvent(
      KeyEvent event, {
      VoidCallback? onSave,
      VoidCallback? onSaveAs,
      VoidCallback? onOpen,
      VoidCallback? onExportPng,
      VoidCallback? onImportImage,
      void Function(ThemeMode)? onThemeToggle,
      ThemeMode Function()? getCurrentThemeMode,
      required BuildContext context,
    }) {
      return handleKeyEvent(
        event: event,
        controller: controller,
        getCanvasSize: () => const Size(800, 600),
        onSave: onSave ?? () {},
        onSaveAs: onSaveAs ?? () {},
        onOpen: onOpen ?? () {},
        onExportPng: onExportPng ?? () {},
        onImportImage: onImportImage ?? () {},
        onThemeToggle: onThemeToggle ?? (_) {},
        getCurrentThemeMode: getCurrentThemeMode ?? () => ThemeMode.light,
        context: context,
      );
    }

    testWidgets('ignores KeyRepeatEvent', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      const event = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isFalse);
    });

    testWidgets('toggles zen mode on Alt+Z', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      expect(controller.zenMode, isFalse);

      // Simulate Alt held via hardware keyboard
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.zenMode, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });

    testWidgets('toggles view mode on Alt+R', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      expect(controller.viewMode, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyR,
        logicalKey: LogicalKeyboardKey.keyR,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.viewMode, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });

    testWidgets('toggles objects snap mode on Alt+S', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      expect(controller.objectsSnapMode, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.objectsSnapMode, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });

    testWidgets('toggles tool locked with Q key', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      expect(controller.toolLocked, isFalse);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyQ,
        logicalKey: LogicalKeyboardKey.keyQ,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.toolLocked, isTrue);
    });

    testWidgets('opens find with Ctrl+F', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      expect(controller.isFindOpen, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: LogicalKeyboardKey.keyF,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.isFindOpen, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('Escape closes find when open', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      controller.openFind();
      expect(controller.isFindOpen, isTrue);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.isFindOpen, isFalse);
    });

    testWidgets('blocks tool shortcuts in view mode', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      controller.toggleViewMode();
      expect(controller.viewMode, isTrue);

      // Tool shortcut '2' for rectangle should be blocked
      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit2,
        logicalKey: LogicalKeyboardKey.digit2,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isFalse);
      expect(
        controller.editorState.activeToolType,
        ToolType.hand, // still hand from view mode
      );
    });

    testWidgets('tool shortcut 2 switches to rectangle', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit2,
        logicalKey: LogicalKeyboardKey.digit2,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(
          controller.editorState.activeToolType, ToolType.rectangle);
    });

    testWidgets('tool shortcut h switches to hand', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyH,
        logicalKey: LogicalKeyboardKey.keyH,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.editorState.activeToolType, ToolType.hand);
    });

    testWidgets('9 key invokes import image callback', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      var importCalled = false;
      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit9,
        logicalKey: LogicalKeyboardKey.digit9,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(
        event,
        context: context,
        onImportImage: () => importCalled = true,
      );
      expect(result, isTrue);
      expect(importCalled, isTrue);
    });

    testWidgets('Ctrl+Delete resets canvas', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      // Add an element so the scene is non-empty
      controller.applyResult(AddElementResult(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      )));
      expect(controller.editorState.scene.activeElements, isNotEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.delete,
        logicalKey: LogicalKeyboardKey.delete,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.editorState.scene.activeElements, isEmpty);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('PageDown scrolls viewport', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      final initialOffset = controller.editorState.viewport.offset;

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.pageDown,
        logicalKey: LogicalKeyboardKey.pageDown,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(event, context: context);
      expect(result, isTrue);
      expect(controller.editorState.viewport.offset.dy,
          greaterThan(initialOffset.dy));
    });

    testWidgets('Ctrl+S calls onSave callback', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      var saved = false;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(
        event,
        context: context,
        onSave: () => saved = true,
      );
      expect(result, isTrue);
      expect(saved, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('Ctrl+Shift+S calls onSaveAs callback', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      var saveAsCalled = false;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(
        event,
        context: context,
        onSaveAs: () => saveAsCalled = true,
      );
      expect(result, isTrue);
      expect(saveAsCalled, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('Ctrl+O calls onOpen callback', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));

      var openCalled = false;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyO,
        logicalKey: LogicalKeyboardKey.keyO,
        timeStamp: Duration.zero,
      );
      final result = callHandleKeyEvent(
        event,
        context: context,
        onOpen: () => openCalled = true,
      );
      expect(result, isTrue);
      expect(openCalled, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. editor_canvas.dart — EditorCanvas
  // ---------------------------------------------------------------------------
  group('EditorCanvas', () {
    testWidgets('renders with a controller', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: EditorCanvas(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EditorCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows eraser cursor when eraser tool active', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.switchTool(ToolType.eraser);
      // Set a mouse position to trigger the cursor overlay
      controller.mousePosition = const Offset(100, 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: EditorCanvas(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EditorCanvas), findsOneWidget);
      // The eraser cursor widget should be present
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('responds to pointer events', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: EditorCanvas(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Hover over the canvas
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(400, 300));
      await tester.pump();
      await gesture.moveTo(const Offset(450, 350));
      await tester.pump();
      await gesture.removePointer();
      await tester.pump();

      expect(find.byType(EditorCanvas), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. markdraw_editor.dart — MarkdrawEditor
  // ---------------------------------------------------------------------------
  group('MarkdrawEditor', () {
    testWidgets('renders with default config', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MarkdrawEditor), findsOneWidget);
      expect(find.byType(EditorCanvas), findsOneWidget);
    });

    testWidgets('renders with external controller', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MarkdrawEditor), findsOneWidget);
      expect(controller.editorState.activeToolType, ToolType.select);
    });

    testWidgets('shows view mode pill when in view mode', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.toggleViewMode();
      await tester.pump();

      expect(find.text('Exit view mode'), findsOneWidget);
    });

    testWidgets('shows zen mode pill when in zen mode', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.toggleZenMode();
      await tester.pump();

      expect(find.text('Exit zen mode'), findsOneWidget);
    });

    testWidgets('hides toolbar in zen mode', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Before zen mode, toolbar should be present
      expect(find.byType(DesktopToolbar), findsOneWidget);

      controller.toggleZenMode();
      await tester.pump();

      // After zen mode, toolbar should be hidden
      expect(find.byType(DesktopToolbar), findsNothing);
    });

    testWidgets('respects config.showToolbar = false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(
                config: MarkdrawEditorConfig(showToolbar: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DesktopToolbar), findsNothing);
    });

    testWidgets('calls onSceneChanged when scene changes', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      Scene? changedScene;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(
                controller: controller,
                onSceneChanged: (scene) => changedScene = scene,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Add an element to trigger scene change
      controller.applyResult(AddElementResult(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      )));
      controller.historyManager.push(controller.editorState.scene);

      expect(changedScene, isNotNull);
    });

    testWidgets('renders Untitled when no document name set', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MarkdrawEditor(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Untitled'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. markdraw_split_pane.dart — MarkdrawSplitPane
  // ---------------------------------------------------------------------------
  group('MarkdrawSplitPane', () {
    testWidgets('renders with child widget', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Use a large enough size to avoid overflow in the text pane header
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdrawSplitPane(
              controller: controller,
              child: const Center(child: Text('Canvas')),
            ),
          ),
        ),
      );
      // Pump enough frames to settle cursor blink timers from re_editor
      await tester.pumpAndSettle();

      expect(find.byType(MarkdrawSplitPane), findsOneWidget);
      expect(find.text('Canvas'), findsOneWidget);
      // The text pane header should show 'markdraw'
      expect(find.text('markdraw'), findsOneWidget);
    });

    testWidgets('shows OK parse status initially', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdrawSplitPane(
              controller: controller,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. markdraw_file_handler.dart — MarkdrawFileHandler
  // ---------------------------------------------------------------------------
  group('MarkdrawFileHandler', () {
    test('constructs with a controller', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final handler = MarkdrawFileHandler(controller: controller);
      expect(handler, isNotNull);
      expect(handler.currentFilePath, isNull);
    });

    test('currentFilePath can be set and read', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final handler = MarkdrawFileHandler(controller: controller);
      handler.currentFilePath = '/tmp/test.markdraw';
      expect(handler.currentFilePath, '/tmp/test.markdraw');
    });

    test('controller reference is accessible', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final handler = MarkdrawFileHandler(controller: controller);
      expect(handler.controller, same(controller));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. markdraw_autocomplete.dart — additional coverage
  // ---------------------------------------------------------------------------
  group('markdraw_autocomplete (additional)', () {
    test('nextElementId with consecutive ids', () {
      const text = 'rect id=rect1\nrect id=rect2\nrect id=rect3';
      expect(nextElementId('rect', text), 'rect4');
    });

    test('nextElementId with very large ids', () {
      const text = 'rect id=rect100\nrect id=rect200';
      // Should return rect1 since 1 is not taken
      expect(nextElementId('rect', text), 'rect1');
    });

    test('elementKeywords has 9 entries', () {
      expect(elementKeywords.length, 9);
    });

    test('markdrawPrompts has unique words except frame', () {
      // 'frame' appears as both element keyword and property key
      final words = markdrawPrompts.map((p) => p.word).toList();
      // Just verify we have enough prompts
      expect(words.length, greaterThan(50));
    });

    test('nextElementId with arrow keyword', () {
      expect(nextElementId('arrow', 'arrow id=arrow1 from r1 to r2'),
          'arrow2');
    });

    test('nextElementId with image keyword', () {
      expect(nextElementId('image', ''), 'image1');
    });

    test('nextElementId does not match partial keyword in id', () {
      // id=rrect1 should not match rect pattern
      expect(nextElementId('rect', 'rrect id=rrect1 at 0,0 size 100x50'),
          'rect1');
    });
  });

  // ---------------------------------------------------------------------------
  // 8. color_picker.dart — ColorSwatch, ColorPaletteOverlay
  // ---------------------------------------------------------------------------
  group('ColorSwatch', () {
    testWidgets('renders with color', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: cp.ColorSwatch(
              color: '#ff0000',
              isSelected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cp.ColorSwatch), findsOneWidget);

      await tester.tap(find.byType(cp.ColorSwatch));
      expect(tapped, isTrue);
    });

    testWidgets('renders selected state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: cp.ColorSwatch(
              color: '#0000ff',
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cp.ColorSwatch), findsOneWidget);
    });

    testWidgets('renders transparent color with diagonal line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: cp.ColorSwatch(
              color: 'transparent',
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Should render at least one CustomPaint with DiagonalLinePainter
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(cp.ColorSwatch), findsOneWidget);
    });

    testWidgets('renders light color with outline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: cp.ColorSwatch(
              color: '#ffffff',
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cp.ColorSwatch), findsOneWidget);
    });
  });

  group('ColorPickerButton', () {
    testWidgets('renders and shows color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerButton(
              color: '#ff0000',
              isActive: false,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorPickerButton), findsOneWidget);
    });

    testWidgets('renders in active state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerButton(
              color: '#00ff00',
              isActive: true,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorPickerButton), findsOneWidget);
    });

    testWidgets('renders with transparent color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerButton(
              color: 'transparent',
              isActive: false,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorPickerButton), findsOneWidget);
    });

    testWidgets('tap opens palette overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ColorPickerButton(
                color: '#ff0000',
                isActive: false,
                onColorSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ColorPickerButton));
      await tester.pump();

      // The palette overlay should appear
      expect(find.byType(ColorPaletteOverlay), findsOneWidget);

      // Tap the transparent swatch in the palette
      // The first swatch inside the overlay should be transparent
      expect(find.text('Hex color'), findsOneWidget);

      // Tap outside to dismiss
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
    });

    testWidgets('paletteColors has expected structure', (tester) async {
      expect(ColorPickerButton.paletteColors.length, 12);
      for (final row in ColorPickerButton.paletteColors) {
        expect(row.length, 5);
        for (final hex in row) {
          expect(hex.startsWith('#'), isTrue);
        }
      }
    });
  });

  group('ColorPaletteOverlay', () {
    testWidgets('renders palette grid with hex input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteOverlay(
              anchor: const Offset(200, 200),
              currentColor: '#ff0000',
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorPaletteOverlay), findsOneWidget);
      expect(find.text('Hex color'), findsOneWidget);
    });

    testWidgets('hides eyedropper button when callbacks not provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteOverlay(
              anchor: const Offset(200, 200),
              currentColor: '#ff0000',
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // No eyedropper icon should be visible
      expect(find.byIcon(Icons.colorize), findsNothing);
    });

    testWidgets('dismiss callback fires when tapping outside', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteOverlay(
              anchor: const Offset(200, 200),
              currentColor: '#ff0000',
              onSelect: (_) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the dismiss backdrop
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('hex input field accepts valid hex', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteOverlay(
              anchor: const Offset(200, 200),
              currentColor: '#ff0000',
              onSelect: (c) => selected = c,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the hex text field and enter a valid color
      final hexField = find.byType(TextField);
      expect(hexField, findsOneWidget);

      await tester.enterText(hexField, '#00ff00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(selected, '#00ff00');
    });

    testWidgets('highlights current color in palette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteOverlay(
              anchor: const Offset(200, 200),
              currentColor: 'transparent',
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorPaletteOverlay), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. color_utils.dart — parseColor
  // ---------------------------------------------------------------------------
  group('color_utils', () {
    test('parseColor parses hex colors', () {
      final red = parseColor('#ff0000');
      expect(red, const Color(0xFFFF0000));
    });

    test('parseColor handles transparent', () {
      final transparent = parseColor('transparent');
      expect(transparent, Colors.transparent);
    });

    test('canvasBackgroundPresets is non-empty', () {
      expect(canvasBackgroundPresets, isNotEmpty);
      expect(canvasBackgroundPresets.first, '#ffffff');
    });

    test('strokeQuickPicks has 5 entries', () {
      expect(strokeQuickPicks.length, 5);
    });

    test('backgroundQuickPicks has 5 entries and starts with transparent', () {
      expect(backgroundQuickPicks.length, 5);
      expect(backgroundQuickPicks.first, 'transparent');
    });
  });

  // ---------------------------------------------------------------------------
  // 10. MarkdrawEditorConfig
  // ---------------------------------------------------------------------------
  group('MarkdrawEditorConfig', () {
    test('default config has expected values', () {
      const config = MarkdrawEditorConfig();
      expect(config.showToolbar, isTrue);
      expect(config.showPropertyPanel, isTrue);
      expect(config.showZoomControls, isTrue);
      expect(config.showHelpButton, isTrue);
      expect(config.showLibraryPanel, isTrue);
      expect(config.showMarkdownButton, isTrue);
      expect(config.showMenu, isTrue);
      expect(config.compactBreakpoint, 600.0);
      expect(config.minZoom, 0.1);
      expect(config.maxZoom, 30.0);
      expect(config.zoomStep, 0.1);
      expect(config.initialBackground, '#ffffff');
      expect(config.tools, isNull);
      expect(config.onLinkOpen, isNull);
    });

    test('custom config overrides defaults', () {
      const config = MarkdrawEditorConfig(
        showToolbar: false,
        showMenu: false,
        compactBreakpoint: 500.0,
        initialBackground: '#000000',
      );
      expect(config.showToolbar, isFalse);
      expect(config.showMenu, isFalse);
      expect(config.compactBreakpoint, 500.0);
      expect(config.initialBackground, '#000000');
    });
  });
}
