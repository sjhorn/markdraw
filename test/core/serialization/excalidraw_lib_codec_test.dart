import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/image_element.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/library/library_document.dart';
import 'package:markdraw/src/core/library/library_item.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';
import 'package:markdraw/src/core/serialization/excalidraw_lib_codec.dart';
import 'package:markdraw/src/core/serialization/parse_result.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

void main() {
  group('ExcalidrawLibCodec', () {
    group('parse v2', () {
      test('parses a single library item', () {
        final json = jsonEncode({
          'type': 'excalidrawlib',
          'version': 2,
          'libraryItems': [
            {
              'id': 'item-1',
              'status': 'published',
              'name': 'Blue Box',
              'created': 1708715821000,
              'elements': [
                {
                  'id': 'r1',
                  'type': 'rectangle',
                  'x': 0,
                  'y': 0,
                  'width': 100,
                  'height': 50,
                },
              ],
            },
          ],
        });

        final result = ExcalidrawLibCodec.parse(json);
        expect(result.value.items, hasLength(1));
        final item = result.value.items.first;
        expect(item.id, 'item-1');
        expect(item.name, 'Blue Box');
        expect(item.status, 'published');
        expect(item.created, 1708715821000);
        expect(item.elements, hasLength(1));
        expect(item.elements.first, isA<RectangleElement>());
      });

      test('parses multiple library items', () {
        final json = jsonEncode({
          'type': 'excalidrawlib',
          'version': 2,
          'libraryItems': [
            {
              'id': 'item-1',
              'name': 'Box',
              'elements': [
                {'id': 'r1', 'type': 'rectangle', 'x': 0, 'y': 0, 'width': 100, 'height': 50},
              ],
            },
            {
              'id': 'item-2',
              'name': 'Circle',
              'elements': [
                {'id': 'e1', 'type': 'ellipse', 'x': 0, 'y': 0, 'width': 80, 'height': 80},
              ],
            },
          ],
        });

        final result = ExcalidrawLibCodec.parse(json);
        expect(result.value.items, hasLength(2));
        expect(result.value.items[0].name, 'Box');
        expect(result.value.items[1].name, 'Circle');
      });

      test('parses item with image files', () {
        final imageBytes = Uint8List.fromList([137, 80, 78, 71]); // PNG header
        final b64 = base64Encode(imageBytes);
        final json = jsonEncode({
          'type': 'excalidrawlib',
          'version': 2,
          'libraryItems': [
            {
              'id': 'item-1',
              'name': 'Image Item',
              'elements': [
                {
                  'id': 'img1',
                  'type': 'image',
                  'x': 0,
                  'y': 0,
                  'width': 200,
                  'height': 150,
                  'fileId': 'file-abc',
                },
              ],
              'files': {
                'file-abc': {
                  'mimeType': 'image/png',
                  'id': 'file-abc',
                  'dataURL': 'data:image/png;base64,$b64',
                },
              },
            },
          ],
        });

        final result = ExcalidrawLibCodec.parse(json);
        final item = result.value.items.first;
        expect(item.files, hasLength(1));
        expect(item.files['file-abc']!.mimeType, 'image/png');
        expect(item.files['file-abc']!.bytes, imageBytes);
      });
    });

    group('parse v1 legacy', () {
      test('parses array-of-arrays into LibraryItems', () {
        final json = jsonEncode({
          'type': 'excalidrawlib',
          'version': 1,
          'library': [
            [
              {'id': 'r1', 'type': 'rectangle', 'x': 0, 'y': 0, 'width': 100, 'height': 50},
            ],
            [
              {'id': 'e1', 'type': 'ellipse', 'x': 10, 'y': 10, 'width': 60, 'height': 60},
              {'id': 'r2', 'type': 'rectangle', 'x': 80, 'y': 10, 'width': 40, 'height': 40},
            ],
          ],
        });

        final result = ExcalidrawLibCodec.parse(json);
        expect(result.value.items, hasLength(2));
        expect(result.value.items[0].id, 'v1-item-0');
        expect(result.value.items[0].elements, hasLength(1));
        expect(result.value.items[1].id, 'v1-item-1');
        expect(result.value.items[1].elements, hasLength(2));
      });
    });

    group('parse error handling', () {
      test('returns empty doc with warning for invalid JSON', () {
        final result = ExcalidrawLibCodec.parse('not json');
        expect(result.value.items, isEmpty);
        expect(result.hasWarnings, isTrue);
      });

      test('returns empty doc with warning for missing fields', () {
        final result = ExcalidrawLibCodec.parse('{}');
        expect(result.value.items, isEmpty);
        expect(result.hasWarnings, isTrue);
      });
    });

    group('serialize v2', () {
      test('serializes a single item', () {
        final doc = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Test',
            status: 'published',
            created: 1000,
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

        final json = ExcalidrawLibCodec.serialize(doc);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['type'], 'excalidrawlib');
        expect(decoded['version'], 2);
        expect(decoded['source'], 'markdraw');
        final items = decoded['libraryItems'] as List;
        expect(items, hasLength(1));
        expect(items[0]['id'], 'item-1');
        expect(items[0]['name'], 'Test');
        expect(items[0]['status'], 'published');
        expect(items[0]['elements'], hasLength(1));
      });

      test('serializes multiple items', () {
        final doc = LibraryDocument(items: [
          LibraryItem(id: '1', name: 'A', elements: [
            RectangleElement(id: const ElementId('r1'), x: 0, y: 0, width: 100, height: 50),
          ]),
          LibraryItem(id: '2', name: 'B', elements: [
            EllipseElement(id: const ElementId('e1'), x: 0, y: 0, width: 80, height: 80),
          ]),
        ]);

        final json = ExcalidrawLibCodec.serialize(doc);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final items = decoded['libraryItems'] as List;
        expect(items, hasLength(2));
      });

      test('serializes item with files', () {
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

        final json = ExcalidrawLibCodec.serialize(doc);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final items = decoded['libraryItems'] as List;
        expect(items[0]['files'], isNotNull);
        expect(items[0]['files']['file-abc']['mimeType'], 'image/png');
      });
    });

    group('round-trip', () {
      test('serialize then parse preserves items', () {
        final original = LibraryDocument(items: [
          LibraryItem(
            id: 'item-1',
            name: 'Box',
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

        final json = ExcalidrawLibCodec.serialize(original);
        final result = ExcalidrawLibCodec.parse(json);
        final roundTripped = result.value;

        expect(roundTripped.items, hasLength(1));
        final item = roundTripped.items.first;
        expect(item.id, 'item-1');
        expect(item.name, 'Box');
        expect(item.status, 'published');
        expect(item.created, 12345);
        expect(item.elements.first, isA<RectangleElement>());
        expect(item.elements.first.x, 10);
        expect(item.elements.first.strokeColor, '#ff0000');
      });

      test('round-trip preserves files', () {
        final imageBytes = Uint8List.fromList([10, 20, 30, 40]);
        final original = LibraryDocument(items: [
          LibraryItem(
            id: 'img-item',
            name: 'With Image',
            elements: [
              ImageElement(
                id: const ElementId('img1'),
                x: 0,
                y: 0,
                width: 200,
                height: 150,
                fileId: 'file-1',
              ),
            ],
            files: {
              'file-1': ImageFile(mimeType: 'image/jpeg', bytes: imageBytes),
            },
          ),
        ]);

        final json = ExcalidrawLibCodec.serialize(original);
        final result = ExcalidrawLibCodec.parse(json);
        final item = result.value.items.first;
        expect(item.files['file-1']!.mimeType, 'image/jpeg');
        expect(item.files['file-1']!.bytes, imageBytes);
      });
    });

    test('item with grouped elements preserves groupIds', () {
      final doc = LibraryDocument(items: [
        LibraryItem(
          id: 'grouped',
          name: 'Grouped',
          elements: [
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              groupIds: ['group-a'],
            ),
            RectangleElement(
              id: const ElementId('r2'),
              x: 110,
              y: 0,
              width: 100,
              height: 50,
              groupIds: ['group-a'],
            ),
          ],
        ),
      ]);

      final json = ExcalidrawLibCodec.serialize(doc);
      final result = ExcalidrawLibCodec.parse(json);
      final item = result.value.items.first;
      expect(item.elements[0].groupIds, ['group-a']);
      expect(item.elements[1].groupIds, ['group-a']);
    });
  });

  group('ExcalidrawJsonCodec exposed methods', () {
    test('elementToJson produces valid JSON for rectangle', () {
      final el = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final json = ExcalidrawJsonCodec.elementToJson(el);
      expect(json['id'], 'r1');
      expect(json['type'], 'rectangle');
      expect(json['x'], 10.0);
    });

    test('parseElement parses rectangle JSON', () {
      final raw = {
        'id': 'r1',
        'type': 'rectangle',
        'x': 10,
        'y': 20,
        'width': 100,
        'height': 50,
      };
      final warnings = <ParseWarning>[];
      final element = ExcalidrawJsonCodec.parseElement(raw, 'rectangle', 0, warnings);
      expect(element, isA<RectangleElement>());
      expect(element!.x, 10);
    });

    test('document serialize/parse still works (regression)', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ]),
        ],
      );
      final json = ExcalidrawJsonCodec.serialize(doc);
      final result = ExcalidrawJsonCodec.parse(json);
      expect(result.value.allElements, hasLength(1));
      expect(result.value.allElements.first, isA<RectangleElement>());
    });
  });
}
