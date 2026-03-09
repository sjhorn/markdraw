import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('sampleColorFromImage', () {
    test('returns hex color at given position', () async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Create a 10x10 image with a known color
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);
      picture.dispose();

      final color = await controller.sampleColorFromImage(
        image,
        const Offset(5, 5),
      );
      image.dispose();

      expect(color, '#ff0000');
    });

    test('returns null for out-of-bounds position', () async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);
      picture.dispose();

      expect(
        await controller.sampleColorFromImage(image, const Offset(-1, 5)),
        isNull,
      );
      expect(
        await controller.sampleColorFromImage(image, const Offset(5, -1)),
        isNull,
      );
      expect(
        await controller.sampleColorFromImage(image, const Offset(10, 5)),
        isNull,
      );
      expect(
        await controller.sampleColorFromImage(image, const Offset(5, 10)),
        isNull,
      );
      image.dispose();
    });

    test('samples different colors at different positions', () async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Left half red, right half blue
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 5, 10),
        Paint()..color = const Color(0xFFFF0000),
      );
      canvas.drawRect(
        const Rect.fromLTWH(5, 0, 5, 10),
        Paint()..color = const Color(0xFF0000FF),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);
      picture.dispose();

      final red = await controller.sampleColorFromImage(
        image,
        const Offset(2, 5),
      );
      final blue = await controller.sampleColorFromImage(
        image,
        const Offset(7, 5),
      );
      image.dispose();

      expect(red, '#ff0000');
      expect(blue, '#0000ff');
    });
  });

  group('renderSceneImage', () {
    test('renders scene to image', () async {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      // Add a red rectangle to the scene
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 80,
        height: 80,
        strokeColor: '#ff0000',
        backgroundColor: '#ff0000',
        fillStyle: FillStyle.solid,
      );
      controller.applyResult(AddElementResult(rect));

      final image = await controller.renderSceneImage(const Size(100, 100));

      expect(image, isNotNull);
      expect(image!.width, 100);
      expect(image.height, 100);

      // Sample a pixel inside the rectangle — should not be white background
      final color = await controller.sampleColorFromImage(
        image,
        const Offset(50, 50),
      );
      image.dispose();

      expect(color, isNotNull);
      expect(color, isNot('#ffffff'));
    });
  });
}
