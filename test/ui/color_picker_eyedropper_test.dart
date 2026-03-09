import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign, ColorSwatch;

void main() {
  // Helper to create a test image of a solid color
  Future<ui.Image> createTestImage(Color color,
      {int width = 100, int height = 100}) async {
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
    testWidgets('eyedropper button visible when onRenderScene provided',
        (tester) async {
      await tester.pumpWidget(buildOverlay(
        currentColor: '#ff0000',
        onSelect: (_) {},
        onDismiss: () {},
        onRenderScene: (_) async => await createTestImage(Colors.red),
        onSampleColor: (_, _) async => '#ff0000',
        canvasSize: const Size(100, 100),
      ));

      expect(find.byIcon(Icons.colorize), findsOneWidget);
    });

    testWidgets('eyedropper button hidden when onRenderScene is null',
        (tester) async {
      await tester.pumpWidget(buildOverlay(
        currentColor: '#ff0000',
        onSelect: (_) {},
        onDismiss: () {},
      ));

      expect(find.byIcon(Icons.colorize), findsNothing);
    });

    testWidgets('tapping eyedropper button activates eyedropper mode',
        (tester) async {
      await tester.pumpWidget(buildOverlay(
        currentColor: '#ff0000',
        onSelect: (_) {},
        onDismiss: () {},
        onRenderScene: (_) async => await createTestImage(Colors.red),
        onSampleColor: (_, _) async => '#ff0000',
        canvasSize: const Size(100, 100),
      ));

      await tester.tap(find.byIcon(Icons.colorize));
      await tester.pumpAndSettle();

      // Eyedropper button should now have primaryContainer background
      // (indicates active state)
      final material = tester.widget<Material>(find.ancestor(
        of: find.byIcon(Icons.colorize),
        matching: find.byType(Material),
      ).first);
      expect(material.color, isNot(Colors.transparent));
    });

    testWidgets('I key toggles eyedropper mode', (tester) async {
      await tester.pumpWidget(buildOverlay(
        currentColor: '#ff0000',
        onSelect: (_) {},
        onDismiss: () {},
        onRenderScene: (_) async => await createTestImage(Colors.red),
        onSampleColor: (_, _) async => '#ff0000',
        canvasSize: const Size(100, 100),
      ));

      // Press I to activate
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();

      // Should be active — the colorize icon Material has non-transparent color
      var material = tester.widget<Material>(find.ancestor(
        of: find.byIcon(Icons.colorize),
        matching: find.byType(Material),
      ).first);
      expect(material.color, isNot(Colors.transparent));

      // Press I again to deactivate
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();

      material = tester.widget<Material>(find.ancestor(
        of: find.byIcon(Icons.colorize),
        matching: find.byType(Material),
      ).first);
      expect(material.color, Colors.transparent);
    });

    testWidgets('Escape deactivates eyedropper without closing palette',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(buildOverlay(
        currentColor: '#ff0000',
        onSelect: (_) {},
        onDismiss: () => dismissed = true,
        onRenderScene: (_) async => await createTestImage(Colors.red),
        onSampleColor: (_, _) async => '#ff0000',
        canvasSize: const Size(100, 100),
      ));

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
      final material = tester.widget<Material>(find.ancestor(
        of: find.byIcon(Icons.colorize),
        matching: find.byType(Material),
      ).first);
      expect(material.color, Colors.transparent);
    });
  });

  group('ColorPickerButton eyedropper passthrough', () {
    testWidgets('passes eyedropper callbacks to overlay', (tester) async {
      await tester.pumpWidget(MaterialApp(
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
      ));

      // Tap the button to open the palette
      await tester.tap(find.byType(ColorPickerButton));
      await tester.pumpAndSettle();

      // The overlay should have the eyedropper button
      expect(find.byIcon(Icons.colorize), findsOneWidget);
    });
  });
}
