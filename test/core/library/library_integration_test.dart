import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('Library integration', () {
    test('create elements → add to library → instantiate → verify on canvas', () {
      // Create some elements on a "canvas"
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 80,
        height: 40,
        strokeColor: '#ff0000',
      );
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 250,
        width: 60,
        height: 60,
        backgroundColor: '#00ff00',
      );

      // Add to library
      final item = LibraryUtils.createFromElements(
        elements: [rect, ellipse],
        name: 'My Shapes',
      );

      expect(item.name, 'My Shapes');
      expect(item.elements, hasLength(2));
      // Positions normalized to origin
      expect(item.elements[0].x, 0);
      expect(item.elements[0].y, 0);

      // Instantiate at a position
      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(500, 500),
      );

      // Apply to scene
      var scene = Scene();
      final compound = result as CompoundResult;
      for (final r in compound.results) {
        if (r is AddElementResult) {
          scene = scene.addElement(r.element);
        }
      }

      expect(scene.activeElements, hasLength(2));
      // Elements have fresh IDs
      expect(
        scene.activeElements.every((e) =>
            e.id != const ElementId('r1') && e.id != const ElementId('e1')),
        isTrue,
      );
      // Styles preserved
      final placedRect = scene.activeElements
          .firstWhere((e) => e is RectangleElement) as RectangleElement;
      expect(placedRect.strokeColor, '#ff0000');
    });

    test('instantiate then verify elements are independent', () {
      final item = LibraryItem(
        id: 'test',
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
      );

      // Instantiate twice
      final result1 = LibraryUtils.instantiate(
        item: item,
        position: const Point(100, 100),
      );
      final result2 = LibraryUtils.instantiate(
        item: item,
        position: const Point(300, 300),
      );

      final adds1 = _extractAdds(result1);
      final adds2 = _extractAdds(result2);

      // Different IDs
      expect(adds1.first.id, isNot(adds2.first.id));
      // Different positions
      expect(adds1.first.x, isNot(adds2.first.x));
    });

    test('library item round-trip via .markdrawlib', () {
      final item = LibraryUtils.createFromElements(
        elements: [
          RectangleElement(
            id: const ElementId('r1'),
            x: 50,
            y: 50,
            width: 100,
            height: 50,
            strokeColor: '#0000ff',
          ),
        ],
        name: 'Blue Box',
      );

      final doc = LibraryDocument(items: [item]);
      final serialized = LibraryCodec.serialize(doc);
      final parsed = LibraryCodec.parse(serialized);

      expect(parsed.value.items, hasLength(1));
      final roundTripped = parsed.value.items.first;
      expect(roundTripped.name, 'Blue Box');
      expect(roundTripped.elements.first, isA<RectangleElement>());
    });

    test('library item round-trip via .excalidrawlib', () {
      final item = LibraryUtils.createFromElements(
        elements: [
          EllipseElement(
            id: const ElementId('e1'),
            x: 0,
            y: 0,
            width: 80,
            height: 80,
            backgroundColor: '#ffff00',
          ),
        ],
        name: 'Yellow Circle',
      );

      final doc = LibraryDocument(items: [item]);
      final serialized = ExcalidrawLibCodec.serialize(doc);
      final parsed = ExcalidrawLibCodec.parse(serialized);

      expect(parsed.value.items, hasLength(1));
      final roundTripped = parsed.value.items.first;
      expect(roundTripped.name, 'Yellow Circle');
      expect(roundTripped.elements.first, isA<EllipseElement>());
      expect(roundTripped.elements.first.backgroundColor, '#ffff00');
    });

    test('instantiate preserves styles and properties', () {
      final item = LibraryItem(
        id: 'styled',
        name: 'Styled',
        elements: [
          RectangleElement(
            id: const ElementId('r1'),
            x: 0,
            y: 0,
            width: 100,
            height: 50,
            strokeColor: '#123456',
            backgroundColor: '#abcdef',
            strokeWidth: 3.0,
            roughness: 2.0,
            opacity: 0.8,
          ),
        ],
      );

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final adds = _extractAdds(result);
      expect(adds.first.strokeColor, '#123456');
      expect(adds.first.backgroundColor, '#abcdef');
      expect(adds.first.strokeWidth, 3.0);
      expect(adds.first.roughness, 2.0);
      expect(adds.first.opacity, 0.8);
    });

    test('instantiate places at specified position', () {
      final item = LibraryItem(
        id: 'pos',
        name: 'Position Test',
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

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(500, 400),
      );

      final adds = _extractAdds(result);
      // Centered: 500 - 50 = 450, 400 - 25 = 375
      expect(adds.first.x, 450);
      expect(adds.first.y, 375);
    });

    test('add-to-library with grouped elements', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
        groupIds: ['g1'],
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 60,
        y: 0,
        width: 50,
        height: 50,
        groupIds: ['g1'],
      );

      final item = LibraryUtils.createFromElements(
        elements: [r1, r2],
        name: 'Grouped',
      );

      // Instantiate and verify group structure preserved (with remapped IDs)
      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );
      final adds = _extractAdds(result);
      expect(adds[0].groupIds, hasLength(1));
      expect(adds[0].groupIds.first, isNot('g1'));
      expect(adds[0].groupIds, equals(adds[1].groupIds));
    });

    test('add-to-library with image elements and files', () {
      final imageBytes = Uint8List.fromList([10, 20, 30]);
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 100,
        y: 100,
        width: 200,
        height: 150,
        fileId: 'file-xyz',
      );

      final item = LibraryUtils.createFromElements(
        elements: [img],
        name: 'Image Item',
        sceneFiles: {
          'file-xyz': ImageFile(mimeType: 'image/png', bytes: imageBytes),
        },
      );

      expect(item.files, hasLength(1));
      expect(item.files['file-xyz']!.bytes, imageBytes);

      // Instantiate includes file result
      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );
      final compound = result as CompoundResult;
      final fileResults =
          compound.results.whereType<AddFileResult>().toList();
      expect(fileResults, hasLength(1));
      expect(fileResults.first.file.bytes, imageBytes);
    });
  });
}

List<Element> _extractAdds(ToolResult result) {
  final compound = result as CompoundResult;
  return compound.results
      .whereType<AddElementResult>()
      .map((r) => r.element)
      .toList();
}
