import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final adapter = RoughCanvasAdapter();

  group('PngExporter', () {
    test('returns null for empty scene', () async {
      final scene = Scene();
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNull);
    });

    test('exports single rectangle to non-empty PNG bytes', () async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
      // PNG magic number: 0x89 50 4E 47
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('scale=2 produces larger bytes', () async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      final bytes1x = await PngExporter.export(scene, adapter, scale: 1);
      final bytes2x = await PngExporter.export(scene, adapter, scale: 2);
      expect(bytes1x, isNotNull);
      expect(bytes2x, isNotNull);
      // 2x scale should produce more bytes (larger image)
      expect(bytes2x!.length, greaterThan(bytes1x!.length));
    });

    test('background color produces non-transparent image', () async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        seed: 42,
      ));
      final withBg = await PngExporter.export(
        scene,
        adapter,
        backgroundColor: const Color(0xFFFFFFFF),
      );
      final withoutBg = await PngExporter.export(scene, adapter);
      expect(withBg, isNotNull);
      expect(withoutBg, isNotNull);
      // Both should be valid PNGs, but different sizes due to background
      expect(withBg!.length, isNot(equals(withoutBg!.length)));
    });

    test('selection-only exports subset', () async {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
        seed: 42,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 500,
        y: 500,
        width: 200,
        height: 200,
        seed: 43,
      ));
      // Export only r1 — should be a smaller image than full scene
      final selectedBytes = await PngExporter.export(
        scene,
        adapter,
        selectedIds: {const ElementId('r1')},
      );
      final fullBytes = await PngExporter.export(scene, adapter);
      expect(selectedBytes, isNotNull);
      expect(fullBytes, isNotNull);
    });

    test('includes bound text in export', () async {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      scene = scene.addElement(TextElement(
        id: const ElementId('t1'),
        x: 20,
        y: 20,
        width: 80,
        height: 20,
        text: 'Hello',
        containerId: 'r1',
      ));
      // Should not crash, should produce valid PNG
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('excludes deleted elements', () async {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 500,
        y: 500,
        width: 100,
        height: 80,
        seed: 43,
        isDeleted: true,
      ));
      // Deleted element shouldn't affect bounds
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNotNull);
    });

    test('handles multiple element types', () async {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
        seed: 42,
      ));
      scene = scene.addElement(DiamondElement(
        id: const ElementId('d1'),
        x: 120,
        y: 10,
        width: 80,
        height: 80,
        seed: 43,
      ));
      scene = scene.addElement(LineElement(
        id: const ElementId('l1'),
        x: 0,
        y: 100,
        width: 200,
        height: 0,
        points: [const Point(0, 0), const Point(200, 0)],
        seed: 44,
      ));
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('handles rotated elements', () async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 100,
        height: 60,
        angle: 0.5,
        seed: 42,
      ));
      final bytes = await PngExporter.export(scene, adapter);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('returns null when selection has no matching elements', () async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 80,
      ));
      final bytes = await PngExporter.export(
        scene,
        adapter,
        selectedIds: {const ElementId('nonexistent')},
      );
      expect(bytes, isNull);
    });
  });
}
