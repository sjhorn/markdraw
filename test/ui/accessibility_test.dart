import 'package:flutter/material.dart' hide Element, SelectionOverlay;
import 'package:flutter_test/flutter_test.dart';

import 'package:markdraw/markdraw.dart' hide TextAlign, ColorSwatch;
import 'package:markdraw/src/ui/color_picker.dart' as cp;

void main() {
  group('Toolbar accessibility', () {
    testWidgets('DesktopToolbar has FocusTraversalGroup', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopToolbar(controller: controller),
          ),
        ),
      );

      expect(find.byType(FocusTraversalGroup), findsAtLeast(1));
    });

    testWidgets('CompactToolbar has FocusTraversalGroup', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactToolbar(controller: controller),
          ),
        ),
      );

      expect(find.byType(FocusTraversalGroup), findsAtLeast(1));
    });

    testWidgets('DesktopToolbar buttons have Semantics', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopToolbar(controller: controller),
          ),
        ),
      );

      // Each toolbar button should have a Semantics widget
      final semantics = find.byType(Semantics);
      expect(semantics, findsAtLeast(5)); // At least tool buttons
    });

    testWidgets('CompactToolbar buttons have Semantics', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactToolbar(controller: controller),
          ),
        ),
      );

      final semantics = find.byType(Semantics);
      expect(semantics, findsAtLeast(5));
    });

    testWidgets('ToggleChip uses InkWell for tap feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleChip(
              label: 'Test',
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('IconToggleChip uses InkWell for tap feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconToggleChip(
              isSelected: false,
              onTap: () {},
              child: const Icon(Icons.check),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('ZoomControls zoom percentage has Semantics', (tester) async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomControls(
              controller: controller,
              getCanvasSize: () => const Size(800, 600),
            ),
          ),
        ),
      );

      // Should find Semantics for the zoom percentage display
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final zoomSemantic = semantics.where(
        (s) =>
            s.properties.label != null &&
            s.properties.label!.contains('Zoom') &&
            s.properties.label!.contains('%'),
      );
      expect(zoomSemantic, isNotEmpty);
    });

    testWidgets('ThemeButtons have Semantics on each button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeButtons(
              currentThemeMode: ThemeMode.system,
              onThemeModeChanged: (_) {},
              dismissOnTap: false,
            ),
          ),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final labeledButtons = semantics.where(
        (s) => s.properties.label != null && s.properties.button == true,
      );
      // Light, Dark, System = 3 buttons
      expect(labeledButtons.length, greaterThanOrEqualTo(3));
    });

    testWidgets('ColorSwatch uses InkWell for tap feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: cp.ColorSwatch(
              color: '#ff0000',
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });
  });
}
