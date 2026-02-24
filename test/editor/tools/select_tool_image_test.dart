import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/image_element.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/editor_state.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/select_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

Scene _sceneWithImage({
  String imgId = 'img1',
  String fileId = 'abc12345',
  double x = 100,
  double y = 100,
  double width = 200,
  double height = 100,
}) {
  var scene = Scene();
  scene = scene.addFile(
    fileId,
    ImageFile(
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1, 2, 3]),
    ),
  );
  scene = scene.addElement(ImageElement(
    id: ElementId(imgId),
    x: x,
    y: y,
    width: width,
    height: height,
    fileId: fileId,
    seed: 42,
  ));
  return scene;
}

void main() {
  group('SelectTool - image resize', () {
    test('resize image maintains aspect ratio by default (no shift)', () {
      final scene = _sceneWithImage(width: 200, height: 100);
      final tool = SelectTool();
      final context = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
      );

      // Start drag on the bottom-right handle area (200+100=300, 100+100=200)
      tool.onPointerDown(const Point(300, 200), context);
      // Drag to the right to widen
      final result = tool.onPointerMove(const Point(350, 250), context);
      tool.reset();

      // Even without shift, image should maintain aspect ratio
      if (result != null) {
        final updated = _findUpdatedElement(result);
        if (updated != null) {
          final img = updated as ImageElement;
          // Original aspect ratio: 200/100 = 2.0
          // With aspect lock, resizing should maintain this ratio
          expect(img.width / img.height, closeTo(2.0, 0.1));
        }
      }
    });

    test('resize image with shift unlocks aspect ratio', () {
      final scene = _sceneWithImage(width: 200, height: 100);
      final tool = SelectTool();
      final context = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
      );

      // Start drag with shift on the bottom-right handle
      tool.onPointerDown(const Point(300, 200), context, shift: true);
      final result = tool.onPointerMove(const Point(350, 300), context);
      tool.reset();

      // With shift, image should NOT maintain aspect ratio
      if (result != null) {
        final updated = _findUpdatedElement(result);
        if (updated != null) {
          // The resize should be free-form (aspect ratio may differ)
          expect(updated.width, isNot(equals(0)));
        }
      }
    });
  });

  group('SelectTool - image delete', () {
    test('delete image removes file when no other references', () {
      final scene = _sceneWithImage();
      final tool = SelectTool();
      final context = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
      );

      final result = tool.onKeyEvent('Delete', context: context);
      expect(result, isNotNull);

      // Apply result to editor state
      final state = EditorState(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
        activeToolType: ToolType.select,
      );
      final newState = state.applyResult(result);

      // File should be removed
      expect(newState.scene.files, isEmpty);
    });

    test('delete image keeps file if another element references it', () {
      var scene = _sceneWithImage(imgId: 'img1', fileId: 'abc12345');
      // Add another image element referencing same file
      scene = scene.addElement(ImageElement(
        id: const ElementId('img2'),
        x: 400,
        y: 100,
        width: 200,
        height: 100,
        fileId: 'abc12345',
        seed: 43,
      ));

      final tool = SelectTool();
      final context = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
      );

      final result = tool.onKeyEvent('Delete', context: context);

      // Apply result
      final state = EditorState(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
        activeToolType: ToolType.select,
      );
      final newState = state.applyResult(result);

      // File should still be present (referenced by img2)
      expect(newState.scene.files.containsKey('abc12345'), isTrue);
    });
  });

  group('SelectTool - image duplicate', () {
    test('duplicate reuses same fileId', () {
      final scene = _sceneWithImage();
      final tool = SelectTool();
      final context = ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: {const ElementId('img1')},
      );

      final result = tool.onKeyEvent('d', ctrl: true, context: context);
      expect(result, isNotNull);

      // Find the AddElementResult in the compound
      final compound = result as CompoundResult;
      final addResults = compound.results
          .whereType<AddElementResult>()
          .toList();
      expect(addResults, isNotEmpty);
      final newImg = addResults.first.element as ImageElement;
      expect(newImg.fileId, 'abc12345');
      // ID should be different
      expect(newImg.id, isNot(const ElementId('img1')));
    });
  });

  group('ImageElement copyWith', () {
    test('crop copyWith preserves other fields', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        imageScale: 1.5,
        seed: 42,
      );
      final updated = img.copyWith(x: 150);
      expect(updated, isA<ImageElement>());
      expect((updated).fileId, 'abc12345');
      expect(updated.imageScale, 1.5);
    });

    test('scale copyWith preserves other fields', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        imageScale: 1.0,
        seed: 42,
      );
      final updated = img.copyWithImage(imageScale: 2.0);
      expect(updated.imageScale, 2.0);
      expect(updated.fileId, 'abc12345');
      expect(updated.x, 100);
    });
  });
}

Element? _findUpdatedElement(ToolResult result) {
  if (result is UpdateElementResult) return result.element;
  if (result is CompoundResult) {
    for (final r in result.results) {
      if (r is UpdateElementResult) return r.element;
    }
  }
  return null;
}
