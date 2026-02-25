import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('SketchLineSerializer - image', () {
    final serializer = SketchLineSerializer();

    test('serializes image element', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        seed: 42,
      );
      final line = serializer.serialize(img, alias: 'photo');
      expect(line, contains('image'));
      expect(line, contains('id=photo'));
      expect(line, contains('at 100,200'));
      expect(line, contains('size 400x300'));
      expect(line, contains('file=abc12345'));
      expect(line, isNot(contains('crop=')));
      expect(line, isNot(contains('scale=')));
    });

    test('serializes image with crop and scale', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        fileId: 'abc12345',
        crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
        imageScale: 1.5,
        seed: 42,
      );
      final line = serializer.serialize(img, alias: 'photo');
      expect(line, contains('crop=0.1,0.2,0.8,0.6'));
      expect(line, contains('scale=1.5'));
    });

    test('omits crop when full image', () {
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
        crop: const ImageCrop(),
        seed: 42,
      );
      final line = serializer.serialize(img);
      expect(line, isNot(contains('crop=')));
    });
  });

  group('SketchLineParser - image', () {
    test('parses image element line', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'image id=photo at 100,200 size 400x300 file=abc12345 seed=42',
        1,
      );
      expect(result.value, isA<ImageElement>());
      final img = result.value! as ImageElement;
      expect(img.x, 100);
      expect(img.y, 200);
      expect(img.width, 400);
      expect(img.height, 300);
      expect(img.fileId, 'abc12345');
      expect(img.crop, isNull);
      expect(img.imageScale, 1.0);
    });

    test('parses image with crop and scale', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'image id=photo at 100,200 size 400x300 file=abc12345 crop=0.1,0.2,0.8,0.6 scale=1.5 seed=42',
        1,
      );
      final img = result.value! as ImageElement;
      expect(img.crop, const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6));
      expect(img.imageScale, 1.5);
    });

    test('parses image without crop or scale', () {
      final parser = SketchLineParser();
      final result = parser.parseLine(
        'image at 0,0 size 100x100 file=test123 seed=1',
        1,
      );
      final img = result.value! as ImageElement;
      expect(img.crop, isNull);
      expect(img.imageScale, 1.0);
    });
  });

  group('DocumentSerializer - files block', () {
    test('serializes files block', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 100,
              y: 200,
              width: 400,
              height: 300,
              fileId: 'abc12345',
              seed: 42,
            ),
          ]),
        ],
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        },
      );

      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('```files'));
      expect(output, contains('abc12345 image/png'));
      // base64 of [1,2,3] is AQID
      expect(output, contains('AQID'));
    });

    test('omits files block when no files', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 0,
              y: 0,
              width: 100,
              height: 100,
              fileId: 'abc12345',
              seed: 42,
            ),
          ]),
        ],
      );

      final output = DocumentSerializer.serialize(doc);
      expect(output, isNot(contains('```files')));
    });
  });

  group('DocumentParser - files block', () {
    test('parses files block', () {
      const input = '''```sketch
image at 100,200 size 400x300 file=abc12345 seed=42
```

```files
abc12345 image/png AQID
```''';

      final result = DocumentParser.parse(input);
      expect(result.warnings, isEmpty);
      expect(result.value.files.length, 1);
      expect(result.value.files['abc12345']!.mimeType, 'image/png');
      expect(result.value.files['abc12345']!.bytes, [1, 2, 3]);
    });

    test('parses multiple files', () {
      const input = '''```sketch
image at 0,0 size 100x100 file=abc12345 seed=42
image at 200,0 size 100x100 file=def67890 seed=43
```

```files
abc12345 image/png AQID
def67890 image/jpeg AgME
```''';

      final result = DocumentParser.parse(input);
      expect(result.value.files.length, 2);
      expect(result.value.files['abc12345']!.mimeType, 'image/png');
      expect(result.value.files['def67890']!.mimeType, 'image/jpeg');
    });
  });

  group('round-trip', () {
    test('image element with file data round-trips', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 100,
              y: 200,
              width: 400,
              height: 300,
              fileId: 'abc12345',
              seed: 42,
            ),
          ]),
        ],
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          ),
        },
      );

      final serialized = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(serialized);

      expect(parsed.warnings, isEmpty);
      final elements = parsed.value.allElements;
      expect(elements.length, 1);
      expect(elements.first, isA<ImageElement>());
      final img = elements.first as ImageElement;
      expect(img.fileId, 'abc12345');
      expect(img.x, 100);
      expect(img.y, 200);

      expect(parsed.value.files.length, 1);
      expect(parsed.value.files['abc12345']!.mimeType, 'image/png');
      expect(parsed.value.files['abc12345']!.bytes, [1, 2, 3, 4, 5]);
    });

    test('image with crop round-trips', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 50,
              y: 60,
              width: 200,
              height: 150,
              fileId: 'abc12345',
              crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
              imageScale: 2.0,
              seed: 42,
            ),
          ]),
        ],
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([10, 20, 30]),
          ),
        },
      );

      final serialized = DocumentSerializer.serialize(doc);
      final parsed = DocumentParser.parse(serialized);

      expect(parsed.warnings, isEmpty);
      final img = parsed.value.allElements.first as ImageElement;
      expect(img.crop, const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6));
      expect(img.imageScale, 2.0);
    });
  });
}
