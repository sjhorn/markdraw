import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign, ColorSwatch;

void main() {
  // Helper to create a test image of a solid color
  Future<ui.Image> createTestImage(
    Color color, {
    int width = 100,
    int height = 100,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  /// Finds the Container wrapping the eyedropper icon and returns its
  /// background color from the BoxDecoration.
  Color? eyedropperButtonColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.colorize),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration?;
    return decoration?.color;
  }

  Widget buildOverlay({
    required String currentColor,
    required ValueChanged<String> onSelect,
    required VoidCallback onDismiss,
    Future<ui.Image?> Function(Size)? onRenderScene,
    Future<String?> Function(ui.Image, Offset)? onSampleColor,
    Size? canvasSize,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ColorPaletteOverlay(
          anchor: const Offset(100, 100),
          currentColor: currentColor,
          onSelect: onSelect,
          onDismiss: onDismiss,
          onRenderScene: onRenderScene,
          onSampleColor: onSampleColor,
          canvasSize: canvasSize,
        ),
      ),
    );
  }

  group('ColorPaletteOverlay eyedropper', () {
    testWidgets('eyedropper button visible when onRenderScene provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildOverlay(
          currentColor: '#ff0000',
          onSelect: (_) {},
          onDismiss: () {},
          onRenderScene: (_) async => await createTestImage(Colors.red),
          onSampleColor: (_, _) async => '#ff0000',
          canvasSize: const Size(100, 100),
        ),
      );

      expect(find.byIcon(Icons.colorize), findsOneWidget);
    });

    testWidgets('eyedropper button hidden when onRenderScene is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildOverlay(
          currentColor: '#ff0000',
          onSelect: (_) {},
          onDismiss: () {},
        ),
      );

      expect(find.byIcon(Icons.colorize), findsNothing);
    });

    testWidgets('tapping eyedropper button activates eyedropper mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildOverlay(
          currentColor: '#ff0000',
          onSelect: (_) {},
          onDismiss: () {},
          onRenderScene: (_) async => await createTestImage(Colors.red),
          onSampleColor: (_, _) async => '#ff0000',
          canvasSize: const Size(100, 100),
        ),
      );

      await tester.tap(find.byIcon(Icons.colorize));
      await tester.pumpAndSettle();

      // Active state shows non-transparent background
      expect(eyedropperButtonColor(tester), isNot(Colors.transparent));
    });

    testWidgets('I key toggles eyedropper mode', (tester) async {
      await tester.pumpWidget(
        buildOverlay(
          currentColor: '#ff0000',
          onSelect: (_) {},
          onDismiss: () {},
          onRenderScene: (_) async => await createTestImage(Colors.red),
          onSampleColor: (_, _) async => '#ff0000',
          canvasSize: const Size(100, 100),
        ),
      );

      // Press I to activate
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();

      expect(eyedropperButtonColor(tester), isNot(Colors.transparent));

      // Press I again to deactivate
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();

      expect(eyedropperButtonColor(tester), Colors.transparent);
    });

    testWidgets('Escape deactivates eyedropper without closing palette', (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        buildOverlay(
          currentColor: '#ff0000',
          onSelect: (_) {},
          onDismiss: () => dismissed = true,
          onRenderScene: (_) async => await createTestImage(Colors.red),
          onSampleColor: (_, _) async => '#ff0000',
          canvasSize: const Size(100, 100),
        ),
      );

      // Activate eyedropper
      await tester.tap(find.byIcon(Icons.colorize));
      await tester.pumpAndSettle();

      // Press Escape to deactivate (not dismiss palette)
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Palette should still be visible
      expect(find.byIcon(Icons.colorize), findsOneWidget);
      expect(dismissed, isFalse);

      // Eyedropper should be deactivated
      expect(eyedropperButtonColor(tester), Colors.transparent);
    });
  });

  group('ColorPickerButton eyedropper passthrough', () {
    testWidgets('passes eyedropper callbacks to overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerButton(
              color: '#ff0000',
              isActive: false,
              onColorSelected: (_) {},
              onRenderScene: (_) async => await createTestImage(Colors.red),
              onSampleColor: (_, _) async => '#ff0000',
              canvasSize: const Size(100, 100),
            ),
          ),
        ),
      );

      // Tap the button to open the palette
      await tester.tap(find.byType(ColorPickerButton));
      await tester.pumpAndSettle();

      // The overlay should have the eyedropper button
      expect(find.byIcon(Icons.colorize), findsOneWidget);
    });
  });

  group('ColorPickerButton autoOpen', () {
    testWidgets('autoOpen opens palette popup automatically', (tester) async {
      var autoOpenedCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPickerButton(
              color: '#ff0000',
              isActive: false,
              onColorSelected: (_) {},
              autoOpen: true,
              onAutoOpened: () => autoOpenedCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Palette should be visible (has the hex input)
      expect(find.byType(TextField), findsOneWidget);
      expect(autoOpenedCalled, isTrue);
    });
  });
}
