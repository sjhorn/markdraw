import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/library/library_document.dart';
import 'package:markdraw/src/core/library/library_item.dart';

void main() {
  group('LibraryItem', () {
    test('constructs with required properties', () {
      final item = LibraryItem(
        id: 'item-1',
        name: 'Test Item',
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
      );

      expect(item.id, 'item-1');
      expect(item.name, 'Test Item');
      expect(item.status, 'published');
      expect(item.created, 1708715821000);
      expect(item.elements, hasLength(1));
      expect(item.files, isEmpty);
    });

    test('copyWith creates a modified copy', () {
      final item = LibraryItem(id: 'item-1', name: 'Original');
      final copy = item.copyWith(name: 'Updated', status: 'published');

      expect(copy.id, 'item-1');
      expect(copy.name, 'Updated');
      expect(copy.status, 'published');
      // Original unchanged
      expect(item.name, 'Original');
      expect(item.status, 'unpublished');
    });

    test('equality is based on id only', () {
      final a = LibraryItem(id: 'item-1', name: 'A');
      final b = LibraryItem(id: 'item-1', name: 'B');
      final c = LibraryItem(id: 'item-2', name: 'A');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('LibraryDocument', () {
    test('constructs with items list', () {
      final doc = LibraryDocument(items: [
        LibraryItem(id: '1', name: 'Item 1'),
        LibraryItem(id: '2', name: 'Item 2'),
      ]);

      expect(doc.items, hasLength(2));
    });

    test('addItem appends a new item', () {
      final doc = LibraryDocument(items: [
        LibraryItem(id: '1', name: 'Item 1'),
      ]);
      final updated = doc.addItem(LibraryItem(id: '2', name: 'Item 2'));

      expect(updated.items, hasLength(2));
      expect(updated.items[1].name, 'Item 2');
      // Original unchanged
      expect(doc.items, hasLength(1));
    });

    test('removeItem removes by id', () {
      final doc = LibraryDocument(items: [
        LibraryItem(id: '1', name: 'Item 1'),
        LibraryItem(id: '2', name: 'Item 2'),
        LibraryItem(id: '3', name: 'Item 3'),
      ]);
      final updated = doc.removeItem('2');

      expect(updated.items, hasLength(2));
      expect(updated.items.map((i) => i.id), ['1', '3']);
      // Original unchanged
      expect(doc.items, hasLength(3));
    });

    test('defaults to empty items', () {
      final doc = LibraryDocument();
      expect(doc.items, isEmpty);
    });

    test('item with files stores associated image data', () {
      final item = LibraryItem(
        id: 'img-item',
        name: 'Image Item',
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        },
      );

      expect(item.files, hasLength(1));
      expect(item.files['abc12345']!.mimeType, 'image/png');
    });
  });
}
