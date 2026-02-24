import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/image_crop.dart';
import 'package:markdraw/src/core/elements/image_element.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/scene/scene.dart';

void main() {
  group('ImageCrop', () {
    test('constructor with defaults', () {
      const crop = ImageCrop();
      expect(crop.x, 0);
      expect(crop.y, 0);
      expect(crop.width, 1);
      expect(crop.height, 1);
      expect(crop.isFullImage, isTrue);
    });

    test('constructor with custom values', () {
      const crop = ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6);
      expect(crop.x, 0.1);
      expect(crop.y, 0.2);
      expect(crop.width, 0.8);
      expect(crop.height, 0.6);
      expect(crop.isFullImage, isFalse);
    });

    test('equality', () {
      const a = ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6);
      const b = ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6);
      const c = ImageCrop(x: 0.3, y: 0.2, width: 0.8, height: 0.6);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith', () {
      const crop = ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6);
      final updated = crop.copyWith(x: 0.3);
      expect(updated.x, 0.3);
      expect(updated.y, 0.2);
      expect(updated.width, 0.8);
      expect(updated.height, 0.6);
    });
  });

  group('ImageFile', () {
    test('constructor holds data', () {
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(file.mimeType, 'image/png');
      expect(file.bytes, [1, 2, 3]);
    });

    test('equality', () {
      final a = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final b = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final c = ImageFile(
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('ImageElement', () {
    test('constructor sets type to image', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
      );
      expect(img.type, 'image');
    });

    test('constructor sets all fields', () {
      const crop = ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6);
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        mimeType: 'image/png',
        crop: crop,
        imageScale: 1.5,
        seed: 42,
      );
      expect(img.id, const ElementId('img1'));
      expect(img.x, 100);
      expect(img.y, 200);
      expect(img.width, 400);
      expect(img.height, 300);
      expect(img.fileId, 'abc12345');
      expect(img.mimeType, 'image/png');
      expect(img.crop, crop);
      expect(img.imageScale, 1.5);
      expect(img.seed, 42);
    });

    test('default values', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
      );
      expect(img.mimeType, isNull);
      expect(img.crop, isNull);
      expect(img.imageScale, 1.0);
    });

    test('copyWith preserves image-specific fields', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        mimeType: 'image/png',
        crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
        imageScale: 1.5,
      );
      final moved = img.copyWith(x: 50, y: 60);
      expect(moved.x, 50);
      expect(moved.y, 60);
      expect(moved, isA<ImageElement>());
      final movedImg = moved;
      expect(movedImg.fileId, 'abc12345');
      expect(movedImg.mimeType, 'image/png');
      expect(movedImg.crop, const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6));
      expect(movedImg.imageScale, 1.5);
    });

    test('copyWith returns ImageElement type', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
      );
      final copy = img.copyWith(width: 200);
      expect(copy, isA<ImageElement>());
    });

    test('copyWithImage changes image fields', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        mimeType: 'image/png',
        imageScale: 1.0,
      );
      final updated = img.copyWithImage(
        fileId: 'def67890',
        mimeType: 'image/jpeg',
        crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
        imageScale: 2.0,
      );
      expect(updated.fileId, 'def67890');
      expect(updated.mimeType, 'image/jpeg');
      expect(updated.crop, const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6));
      expect(updated.imageScale, 2.0);
      // Position preserved
      expect(updated.x, 100);
      expect(updated.y, 200);
    });

    test('copyWithImage clearCrop', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
        crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
      );
      final updated = img.copyWithImage(clearCrop: true);
      expect(updated.crop, isNull);
    });

    test('identity equality by id', () {
      final a = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
      );
      final b = ImageElement(
        id: const ElementId('img1'),
        x: 999,
        y: 999,
        width: 1,
        height: 1,
        fileId: 'different',
      );
      expect(a, equals(b));
    });
  });

  group('Scene.files', () {
    test('default files is empty', () {
      final scene = Scene();
      expect(scene.files, isEmpty);
    });

    test('addFile adds file to store', () {
      final scene = Scene();
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final updated = scene.addFile('abc12345', file);
      expect(updated.files.length, 1);
      expect(updated.files['abc12345'], file);
    });

    test('removeFile removes file from store', () {
      final scene = Scene();
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final withFile = scene.addFile('abc12345', file);
      final removed = withFile.removeFile('abc12345');
      expect(removed.files, isEmpty);
    });

    test('files preserved through element operations', () {
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      var scene = Scene().addFile('abc12345', file);

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );

      scene = scene.addElement(rect);
      expect(scene.files['abc12345'], file);

      scene = scene.updateElement(rect.copyWith(x: 50));
      expect(scene.files['abc12345'], file);

      scene = scene.removeElement(const ElementId('r1'));
      expect(scene.files['abc12345'], file);
    });

    test('files preserved through softDeleteElement', () {
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      var scene = Scene().addFile('abc12345', file).addElement(rect);
      scene = scene.softDeleteElement(const ElementId('r1'));
      expect(scene.files['abc12345'], file);
    });
  });
}
