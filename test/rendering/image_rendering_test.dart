import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('ImageElementCache', () {
    test('starts empty', () {
      final cache = ImageElementCache();
      expect(cache.length, 0);
      expect(cache.contains('abc'), isFalse);
      cache.dispose();
    });

    test('peek returns null for uncached', () {
      final cache = ImageElementCache();
      expect(cache.peek('abc'), isNull);
      cache.dispose();
    });
  });

  group('SvgElementRenderer - image', () {
    test('renders image with data URI when file provided', () {
      final element = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        seed: 42,
      );
      final files = {
        'abc12345': ImageFile(
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      };

      final svg = SvgElementRenderer.render(element, files: files);
      expect(svg, contains('<image'));
      expect(svg, contains('x="100"'));
      expect(svg, contains('y="200"'));
      expect(svg, contains('width="400"'));
      expect(svg, contains('height="300"'));
      expect(svg, contains('data:image/png;base64,'));
    });

    test('renders placeholder rect when file missing', () {
      final element = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'missing',
        seed: 42,
      );

      final svg = SvgElementRenderer.render(element);
      expect(svg, contains('<rect'));
      expect(svg, contains('#E0E0E0'));
      expect(svg, isNot(contains('<image')));
    });

    test('renders image with opacity wrapping', () {
      final element = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
        opacity: 0.5,
        seed: 42,
      );
      final files = {
        'abc12345': ImageFile(
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      };

      final svg = SvgElementRenderer.render(element, files: files);
      expect(svg, contains('opacity="0.5"'));
      expect(svg, contains('<image'));
    });
  });

  group('SvgExporter - image', () {
    test('exports image with embedded data URI', () {
      var scene = Scene();
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      scene = scene.addFile('abc12345', file);
      scene = scene.addElement(ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        seed: 42,
      ));

      final svg = SvgExporter.export(scene, embedMarkdraw: false);
      expect(svg, contains('<image'));
      expect(svg, contains('data:image/png;base64,'));
    });

    test('exports image with crop data preserved in markdraw embed', () {
      var scene = Scene();
      final file = ImageFile(
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([10, 20, 30]),
      );
      scene = scene.addFile('abc12345', file);
      scene = scene.addElement(ImageElement(
        id: const ElementId('img1'),
        x: 50,
        y: 60,
        width: 200,
        height: 150,
        fileId: 'abc12345',
        crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
        seed: 42,
      ));

      final svg = SvgExporter.export(scene, embedMarkdraw: true);
      expect(svg, contains('<image'));
      // The markdraw embed should contain the crop data
      expect(svg, contains('markdraw:base64:'));
    });
  });
}
