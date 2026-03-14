import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a controller with a rectangle selected so property panels show.
MarkdrawController _controllerWithSelectedRect() {
  final controller = MarkdrawController();
  final scene = Scene().addElement(
    RectangleElement(
      id: const ElementId('r1'),
      x: 10,
      y: 10,
      width: 100,
      height: 60,
    ),
  );
  controller.loadScene(scene);
  // Select the element by applying a selection result.
  controller.applyResult(
    SetSelectionResult({const ElementId('r1')}),
  );
  return controller;
}

/// Creates a controller with two rectangles selected.
MarkdrawController _controllerWithTwoSelected() {
  final controller = MarkdrawController();
  final scene = Scene()
      .addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 60,
      ))
      .addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 10,
        width: 80,
        height: 40,
      ));
  controller.loadScene(scene);
  controller.applyResult(
    SetSelectionResult({const ElementId('r1'), const ElementId('r2')}),
  );
  return controller;
}

/// Creates a controller with three rectangles selected.
MarkdrawController _controllerWithThreeSelected() {
  final controller = MarkdrawController();
  final scene = Scene()
      .addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 60,
      ))
      .addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 10,
        width: 80,
        height: 40,
      ))
      .addElement(RectangleElement(
        id: const ElementId('r3'),
        x: 400,
        y: 10,
        width: 60,
        height: 30,
      ));
  controller.loadScene(scene);
  controller.applyResult(
    SetSelectionResult({
      const ElementId('r1'),
      const ElementId('r2'),
      const ElementId('r3'),
    }),
  );
  return controller;
}

/// Creates a controller with an arrow selected.
MarkdrawController _controllerWithArrowSelected() {
  final controller = MarkdrawController();
  final scene = Scene().addElement(
    ArrowElement(
      id: const ElementId('a1'),
      x: 0,
      y: 0,
      width: 100,
      height: 0,
      points: [const Point(0, 0), const Point(100, 0)],
      endArrowhead: Arrowhead.arrow,
    ),
  );
  controller.loadScene(scene);
  controller.applyResult(
    SetSelectionResult({const ElementId('a1')}),
  );
  return controller;
}

/// Creates a controller with a text element selected.
MarkdrawController _controllerWithTextSelected() {
  final controller = MarkdrawController();
  final scene = Scene().addElement(
    TextElement(
      id: const ElementId('t1'),
      x: 10,
      y: 10,
      width: 100,
      height: 20,
      text: 'Hello',
      fontSize: 20,
    ),
  );
  controller.loadScene(scene);
  controller.applyResult(
    SetSelectionResult({const ElementId('t1')}),
  );
  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // PropertyPanelContent
  // =========================================================================
  group('PropertyPanelContent', () {
    testWidgets('renders with empty elements and default style', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: const ElementStyle(),
                elements: const [],
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PropertyPanelContent), findsOneWidget);
      // Should show Stroke section label
      expect(find.text('Stroke'), findsOneWidget);
    });

    testWidgets('renders with selected rect element', (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PropertyPanelContent), findsOneWidget);
      // Should show section labels
      expect(find.text('Background'), findsOneWidget);
      expect(find.text('Fill style'), findsOneWidget);
      expect(find.text('Stroke width'), findsOneWidget);
      expect(find.text('Stroke style'), findsOneWidget);
      expect(find.text('Sloppiness'), findsOneWidget);
      expect(find.text('Opacity'), findsOneWidget);
      expect(find.text('Layer order'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
    });

    testWidgets('renders locked state (dimmed)', (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: true,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      // When locked, the IgnorePointer with ignoring=true wraps the style panel.
      // Find all IgnorePointers and check that at least one has ignoring=true.
      final ignoreFinders = find.byType(IgnorePointer);
      final allWidgets = tester.widgetList<IgnorePointer>(ignoreFinders);
      expect(allWidgets.any((w) => w.ignoring), isTrue);
    });

    testWidgets('renders with text element (showFullTextProps)', (tester) async {
      final controller = _controllerWithTextSelected();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: true,
                isEditingText: false,
                textOnly: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Font family'), findsOneWidget);
      expect(find.text('Font size'), findsOneWidget);
      expect(find.text('Text align'), findsOneWidget);
    });

    testWidgets('renders isEditingText mode', (tester) async {
      final controller = _controllerWithTextSelected();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: true,
                isEditingText: true,
              ),
            ),
          ),
        ),
      );
      // In editing text mode, it shows Stroke + Opacity labels
      expect(find.text('Stroke'), findsOneWidget);
      expect(find.text('Opacity'), findsOneWidget);
    });

    testWidgets('renders with arrow element (arrows section)', (tester) async {
      final controller = _controllerWithArrowSelected();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Arrow type'), findsOneWidget);
      expect(find.text('Start arrowhead'), findsOneWidget);
      expect(find.text('End arrowhead'), findsOneWidget);
    });

    testWidgets('renders alignment buttons for 2+ selected', (tester) async {
      final controller = _controllerWithTwoSelected();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Align'), findsOneWidget);
    });

    testWidgets('renders distribute buttons for 3+ selected', (tester) async {
      final controller = _controllerWithThreeSelected();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      final style = PropertyPanelState.fromElements(elements);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Distribute'), findsOneWidget);
    });

    testWidgets('renders with roundness support', (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      final elements = controller.selectedElements;
      const style = ElementStyle(
        strokeColor: '#000000',
        backgroundColor: 'transparent',
        strokeWidth: 2.0,
        strokeStyle: StrokeStyle.solid,
        fillStyle: FillStyle.solid,
        roughness: 1.0,
        opacity: 1.0,
        hasRoundness: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PropertyPanelContent(
                controller: controller,
                style: style,
                elements: elements,
                isLocked: false,
                showFullTextProps: false,
                isEditingText: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Edges'), findsOneWidget);
    });
  });

  // =========================================================================
  // HamburgerMenu
  // =========================================================================
  group('HamburgerMenu', () {
    testWidgets('renders menu button', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HamburgerMenu(controller: controller),
          ),
        ),
      );
      expect(find.byType(HamburgerMenu), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('opens popup menu on tap', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HamburgerMenu(
              controller: controller,
              onOpen: () {},
              onSave: () {},
              onExportPng: () {},
              onExportSvg: () {},
              onImportImage: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Menu items should appear
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset Canvas'), findsOneWidget);
      expect(find.text('Zen Mode'), findsOneWidget);
      expect(find.text('View Mode'), findsOneWidget);
    });

    testWidgets('renders with theme mode buttons', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HamburgerMenu(
              controller: controller,
              currentThemeMode: ThemeMode.light,
              onThemeModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Theme buttons should be visible inside menu
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Snap to Objects'), findsOneWidget);
    });
  });

  // =========================================================================
  // HelpDialog
  // =========================================================================
  group('HelpDialog', () {
    testWidgets('showHelpDialog opens and shows shortcuts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHelpDialog(context),
                child: const Text('Show Help'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Help'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
    });

    testWidgets('help dialog can be closed with X button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHelpDialog(context),
                child: const Text('Show Help'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Help'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsNothing);
    });
  });

  // =========================================================================
  // FindOverlay
  // =========================================================================
  group('FindOverlay', () {
    testWidgets('renders search bar with buttons', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FindOverlay(
              controller: controller,
              getCanvasSize: () => const Size(800, 600),
            ),
          ),
        ),
      );
      expect(find.byType(FindOverlay), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // Close button
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Nav buttons
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('text input can receive text', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FindOverlay(
              controller: controller,
              getCanvasSize: () => const Size(800, 600),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'search term');
      await tester.pump();
      expect(find.text('search term'), findsOneWidget);
    });
  });

  // =========================================================================
  // LinkOverlay
  // =========================================================================
  group('LinkOverlay', () {
    testWidgets('renders info mode with link display', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      // Add element with a link
      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          link: 'https://example.com',
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(
        SetSelectionResult({const ElementId('r1')}),
      );
      // Show link info (info mode, not editing)
      controller.showLinkInfo();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkOverlay(
              controller: controller,
              getCanvasSize: () => const Size(800, 600),
            ),
          ),
        ),
      );
      expect(find.byType(LinkOverlay), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('renders editor mode with text field', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      final scene = Scene().addElement(
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
      );
      controller.loadScene(scene);
      controller.applyResult(
        SetSelectionResult({const ElementId('r1')}),
      );
      controller.openLinkEditor();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkOverlay(
              controller: controller,
              getCanvasSize: () => const Size(800, 600),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinkOverlay), findsOneWidget);
      // Editor mode has a Save button
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Link to element'), findsOneWidget);
    });
  });

  // =========================================================================
  // PropertyPanel (desktop)
  // =========================================================================
  group('PropertyPanel', () {
    testWidgets('renders SizedBox.shrink when nothing selected', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanel(controller: controller),
          ),
        ),
      );
      // Should render SizedBox.shrink (returns early when no selection and not creation tool)
      expect(find.byType(PropertyPanel), findsOneWidget);
    });

    testWidgets('renders content when element is selected', (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanel(controller: controller),
          ),
        ),
      );
      expect(find.byType(PropertyPanel), findsOneWidget);
      expect(find.byType(PropertyPanelContent), findsOneWidget);
      expect(find.text('Stroke'), findsOneWidget);
    });

    testWidgets('renders for creation tool (text tool)', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      controller.switchTool(ToolType.text);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanel(controller: controller),
          ),
        ),
      );
      expect(find.byType(PropertyPanelContent), findsOneWidget);
    });

    testWidgets('renders for creation tool (arrow tool)', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      controller.switchTool(ToolType.arrow);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanel(controller: controller),
          ),
        ),
      );
      expect(find.byType(PropertyPanelContent), findsOneWidget);
    });
  });

  // =========================================================================
  // CompactMenuButton
  // =========================================================================
  group('CompactMenuButton', () {
    testWidgets('renders menu icon button', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactMenuButton(controller: controller),
          ),
        ),
      );
      expect(find.byType(CompactMenuButton), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('opens bottom sheet on tap', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactMenuButton(
              controller: controller,
              onOpen: () {},
              onSave: () {},
              onExportPng: () {},
              onExportSvg: () {},
              onImportImage: () {},
              onShowLibrary: () {},
              onThemeModeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Menu items should appear in bottom sheet -- check a few that fit
      // in the default 800x600 test viewport
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('renders without optional callbacks', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactMenuButton(controller: controller),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Without callbacks, menu items are hidden
      expect(find.text('Open'), findsNothing);
      expect(find.text('Save'), findsNothing);
      // Grid toggle always shows
      expect(find.textContaining('Grid'), findsOneWidget);
    });
  });

  // =========================================================================
  // LibraryPanel
  // =========================================================================
  group('LibraryPanel', () {
    testWidgets('renders empty library panel', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryPanel(controller: controller),
          ),
        ),
      );
      expect(find.byType(LibraryPanel), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('No library items.\nSelect elements and click "Add to Library".'),
          findsOneWidget);
    });

    testWidgets('renders with import/export buttons', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: LibraryPanel(
                controller: controller,
                onImportLibrary: () {},
                onExportLibrary: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.file_upload), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows Add to Library button when elements selected',
        (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryPanel(controller: controller),
          ),
        ),
      );
      expect(find.text('Add to Library'), findsOneWidget);
    });
  });

  // =========================================================================
  // FontListContent
  // =========================================================================
  group('FontListContent', () {
    testWidgets('renders font list with search', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FontListContent(
              currentFont: 'Excalifont',
              sceneFonts: {'Excalifont'},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(FontListContent), findsOneWidget);
      // Search field
      expect(find.byType(TextField), findsOneWidget);
      // Scene fonts header
      expect(find.text('Scene fonts'), findsOneWidget);
    });

    testWidgets('shows available fonts header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FontListContent(
              currentFont: 'Excalifont',
              sceneFonts: {'Excalifont'},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Available fonts'), findsOneWidget);
    });

    testWidgets('filters fonts by search query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FontListContent(
              currentFont: 'Excalifont',
              sceneFonts: const {},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      // Type a search query
      await tester.enterText(find.byType(TextField), 'nunito');
      await tester.pump();
      // Should filter fonts to show Nunito
      expect(find.text('Nunito'), findsOneWidget);
    });

    testWidgets('shows dynamic Google Font item for unknown query',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FontListContent(
              currentFont: 'Excalifont',
              sceneFonts: const {},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      // Type an unknown font name
      await tester.enterText(find.byType(TextField), 'my custom font');
      await tester.pump();
      // Should show dynamic Google Font item
      expect(find.textContaining('Google Font:'), findsOneWidget);
    });
  });

  // =========================================================================
  // CompactLibrary (showCompactLibrary)
  // =========================================================================
  group('showCompactLibrary', () {
    testWidgets('opens bottom sheet with library UI', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCompactLibrary(context, controller),
                child: const Text('Open Library'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Library'));
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('No library items.'), findsOneWidget);
    });

    testWidgets('shows import/export buttons when provided', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCompactLibrary(
                  context,
                  controller,
                  onImportLibrary: () {},
                  onExportLibrary: () {},
                ),
                child: const Text('Open Library'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Library'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.file_upload), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
    });
  });

  // =========================================================================
  // showRenameDocumentDialog
  // =========================================================================
  group('showRenameDocumentDialog', () {
    testWidgets('opens rename dialog', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRenameDocumentDialog(context, controller),
                child: const Text('Rename'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsWidgets);
      // "Document name" appears as both labelText and hintText
      expect(find.text('Document name'), findsWidgets);
    });
  });

  // =========================================================================
  // TextEditingOverlay
  // =========================================================================
  group('TextEditingOverlay', () {
    testWidgets('renders editable text for standalone text element',
        (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);
      final textElem = TextElement(
        id: const ElementId('t1'),
        x: 10,
        y: 10,
        width: 100,
        height: 20,
        text: 'Hello',
        fontSize: 20,
      );
      final scene = Scene().addElement(textElem);
      controller.loadScene(scene);
      // Start editing the existing text element
      controller.startTextEditingExisting(textElem);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TextEditingOverlay(controller: controller),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextEditingOverlay), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
    });
  });

  // =========================================================================
  // showCompactPropertyPanel
  // =========================================================================
  group('showCompactPropertyPanel', () {
    testWidgets('opens bottom sheet with property content', (tester) async {
      final controller = _controllerWithSelectedRect();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showCompactPropertyPanel(context, controller),
                child: const Text('Props'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Props'));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyPanelContent), findsOneWidget);
      expect(find.text('Stroke'), findsOneWidget);
    });
  });

  // =========================================================================
  // FontPickerOverlay
  // =========================================================================
  group('FontPickerOverlay', () {
    testWidgets('renders with font list and dismiss backdrop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FontPickerOverlay(
              anchor: const Offset(100, 100),
              currentFont: 'Excalifont',
              sceneFonts: {'Excalifont'},
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.byType(FontPickerOverlay), findsOneWidget);
      expect(find.byType(FontListContent), findsOneWidget);
    });
  });
}
