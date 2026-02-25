import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('LibraryCodec', () {
    group('serialize', () {
      test('serializes a single item', () {
        final doc = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Blue Box',
            status: 'published',
            created: 1708715821000,
            elements: [
              RectangleElement(
                id: const ElementId('r1'),
                x: 0,
                y: 0,
                width: 100,
                height: 50,
              ),
            ],
          ),
        ]);

        final output = LibraryCodec.serialize(doc);
        expect(output, contains('library-item: item-1'));
        expect(output, contains('name: "Blue Box"'));
        expect(output, contains('status: published'));
        expect(output, contains('created: 1708715821000'));
        expect(output, contains('```sketch'));
        expect(output, contains('rect'));
      });

      test('serializes multiple items', () {
        final doc = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Box',
            elements: [
              RectangleElement(
                id: const ElementId('r1'),
                x: 0,
                y: 0,
                width: 100,
                height: 50,
              ),
            ],
          ),
          LibraryItem(
            id: 'item-2',
            name: 'Circle',
            elements: [
              EllipseElement(
                id: const ElementId('e1'),
                x: 0,
                y: 0,
                width: 80,
                height: 80,
              ),
            ],
          ),
        ]);

        final output = LibraryCodec.serialize(doc);
        expect(output, contains('library-item: item-1'));
        expect(output, contains('library-item: item-2'));
        expect(output, contains('name: "Box"'));
        expect(output, contains('name: "Circle"'));
      });

      test('serializes item with image files', () {
        final doc = LibraryDocument(items: [
          LibraryItem(
            id: 'img-item',
            name: 'Image',
            elements: [
              ImageElement(
                id: const ElementId('img1'),
                x: 0,
                y: 0,
                width: 200,
                height: 150,
                fileId: 'file-abc',
              ),
            ],
            files: {
              'file-abc': ImageFile(
                mimeType: 'image/png',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
            },
          ),
        ]);

        final output = LibraryCodec.serialize(doc);
        expect(output, contains('```files'));
        expect(output, contains('file-abc image/png'));
      });
    });

    group('parse', () {
      test('parses a single item', () {
        const input = '''---
library-item: item-1
name: "Blue Box"
status: published
created: 1708715821000
---

```sketch
rect at 0,0 size 100x50
```''';

        final result = LibraryCodec.parse(input);
        expect(result.value.items, hasLength(1));
        final item = result.value.items.first;
        expect(item.id, 'item-1');
        expect(item.name, 'Blue Box');
        expect(item.status, 'published');
        expect(item.created, 1708715821000);
        expect(item.elements, hasLength(1));
        expect(item.elements.first, isA<RectangleElement>());
      });

      test('parses multiple items', () {
        const input = '''---
library-item: item-1
name: "Box"
status: unpublished
created: 0
---

```sketch
rect at 0,0 size 100x50
```

---
library-item: item-2
name: "Circle"
status: unpublished
created: 0
---

```sketch
ellipse at 0,0 size 80x80
```''';

        final result = LibraryCodec.parse(input);
        expect(result.value.items, hasLength(2));
        expect(result.value.items[0].id, 'item-1');
        expect(result.value.items[1].id, 'item-2');
        expect(result.value.items[0].elements.first, isA<RectangleElement>());
        expect(result.value.items[1].elements.first, isA<EllipseElement>());
      });

      test('parses item with files block', () {
        const input = '''---
library-item: img-item
name: "Image"
status: unpublished
created: 0
---

```sketch
image at 0,0 size 200x150 file=file-abc
```

```files
file-abc image/png AQID
```''';

        final result = LibraryCodec.parse(input);
        final item = result.value.items.first;
        expect(item.files, hasLength(1));
        expect(item.files['file-abc']!.mimeType, 'image/png');
      });

      test('returns empty document for empty input', () {
        final result = LibraryCodec.parse('');
        expect(result.value.items, isEmpty);
      });
    });

    group('round-trip', () {
      test('serialize then parse preserves items', () {
        final original = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Test Box',
            status: 'published',
            created: 12345,
            elements: [
              RectangleElement(
                id: const ElementId('r1'),
                x: 10,
                y: 20,
                width: 100,
                height: 50,
                strokeColor: '#ff0000',
              ),
            ],
          ),
        ]);

        final serialized = LibraryCodec.serialize(original);
        final result = LibraryCodec.parse(serialized);
        final roundTripped = result.value;

        expect(roundTripped.items, hasLength(1));
        final item = roundTripped.items.first;
        expect(item.id, 'item-1');
        expect(item.name, 'Test Box');
        expect(item.status, 'published');
        expect(item.created, 12345);
        expect(item.elements, hasLength(1));
        expect(item.elements.first, isA<RectangleElement>());
      });

      test('round-trip preserves multiple items with different element types', () {
        final original = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Box',
            elements: [
              RectangleElement(
                id: const ElementId('r1'),
                x: 0,
                y: 0,
                width: 100,
                height: 50,
              ),
            ],
          ),
          LibraryItem(
            id: 'item-2',
            name: 'Circle',
            elements: [
              EllipseElement(
                id: const ElementId('e1'),
                x: 0,
                y: 0,
                width: 80,
                height: 80,
              ),
            ],
          ),
        ]);

        final serialized = LibraryCodec.serialize(original);
        final result = LibraryCodec.parse(serialized);

        expect(result.value.items, hasLength(2));
        expect(result.value.items[0].elements.first, isA<RectangleElement>());
        expect(result.value.items[1].elements.first, isA<EllipseElement>());
      });
    });
  });

  group('DocumentFormat.detectFormat', () {
    test('detects .markdrawlib format', () {
      expect(
        DocumentService.detectFormat('my-library.markdrawlib'),
        DocumentFormat.markdrawLibrary,
      );
    });

    test('detects .excalidrawlib format', () {
      expect(
        DocumentService.detectFormat('shapes.excalidrawlib'),
        DocumentFormat.excalidrawLibrary,
      );
    });
  });

  group('DocumentService library methods', () {
    late Map<String, String> fileSystem;
    late DocumentService service;

    setUp(() {
      fileSystem = {};
      service = DocumentService(
        readFile: (path) async => fileSystem[path]!,
        writeFile: (path, content) async => fileSystem[path] = content,
      );
    });

    test('loadLibrary loads markdrawlib file', () async {
      final doc = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Test',
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);
      fileSystem['lib.markdrawlib'] = LibraryCodec.serialize(doc);

      final result = await service.loadLibrary('lib.markdrawlib');
      expect(result.value.items, hasLength(1));
      expect(result.value.items.first.name, 'Test');
    });

    test('loadLibrary loads excalidrawlib file', () async {
      final doc = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Test',
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);
      fileSystem['lib.excalidrawlib'] = ExcalidrawLibCodec.serialize(doc);

      final result = await service.loadLibrary('lib.excalidrawlib');
      expect(result.value.items, hasLength(1));
      expect(result.value.items.first.name, 'Test');
    });

    test('saveLibrary saves markdrawlib file', () async {
      final doc = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Saved',
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);

      await service.saveLibrary(doc, 'output.markdrawlib');
      expect(fileSystem['output.markdrawlib'], isNotNull);
      expect(fileSystem['output.markdrawlib']!, contains('library-item'));
    });

    test('saveLibrary saves excalidrawlib file', () async {
      final doc = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Saved',
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);

      await service.saveLibrary(doc, 'output.excalidrawlib');
      expect(fileSystem['output.excalidrawlib'], isNotNull);
      expect(fileSystem['output.excalidrawlib']!, contains('excalidrawlib'));
    });

    test('loadLibrary + saveLibrary round-trip via markdrawlib', () async {
      final original = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Round Trip',
          status: 'published',
          created: 99999,
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);

      await service.saveLibrary(original, 'rt.markdrawlib');
      final result = await service.loadLibrary('rt.markdrawlib');
      expect(result.value.items, hasLength(1));
      expect(result.value.items.first.name, 'Round Trip');
    });

    test('loadLibrary + saveLibrary round-trip via excalidrawlib', () async {
      final original = LibraryDocument(items: [
        LibraryItem(
          id: 'item-1',
          name: 'Round Trip',
          status: 'published',
          created: 99999,
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
        ),
      ]);

      await service.saveLibrary(original, 'rt.excalidrawlib');
      final result = await service.loadLibrary('rt.excalidrawlib');
      expect(result.value.items, hasLength(1));
      expect(result.value.items.first.name, 'Round Trip');
    });
  });
}
