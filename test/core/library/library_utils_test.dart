import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('LibraryUtils.createFromElements', () {
    test('single element normalized to origin', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 100,
        width: 80,
        height: 40,
      );

      final item = LibraryUtils.createFromElements(
        elements: [rect],
        name: 'Test',
      );

      expect(item.name, 'Test');
      expect(item.elements, hasLength(1));
      expect(item.elements.first.x, 0);
      expect(item.elements.first.y, 0);
      expect(item.elements.first.width, 80);
    });

    test('multi-element preserves relative positions', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 50,
        height: 50,
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 300,
        width: 50,
        height: 50,
      );

      final item = LibraryUtils.createFromElements(
        elements: [r1, r2],
        name: 'Multi',
      );

      expect(item.elements[0].x, 0);
      expect(item.elements[0].y, 0);
      expect(item.elements[1].x, 100);
      expect(item.elements[1].y, 100);
    });

    test('includes bound text from scene', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 100,
        height: 50,
        boundElements: [const BoundElement(id: 't1', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('t1'),
        x: 55,
        y: 60,
        width: 90,
        height: 20,
        text: 'Hello',
        containerId: 'r1',
      );

      final item = LibraryUtils.createFromElements(
        elements: [rect],
        name: 'With Text',
        allSceneElements: [rect, boundText],
      );

      expect(item.elements, hasLength(2));
      final text = item.elements.whereType<TextElement>().first;
      expect(text.text, 'Hello');
      expect(text.containerId, 'r1');
    });

    test('includes image files from scene', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final img = ImageElement(
        id: const ElementId('img1'),
        x: 10,
        y: 10,
        width: 200,
        height: 150,
        fileId: 'file-abc',
      );

      final item = LibraryUtils.createFromElements(
        elements: [img],
        name: 'Image',
        sceneFiles: {
          'file-abc': ImageFile(mimeType: 'image/png', bytes: imageBytes),
        },
      );

      expect(item.files, hasLength(1));
      expect(item.files['file-abc']!.bytes, imageBytes);
    });

    test('preserves groupIds', () {
      final r1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
        groupIds: ['group-a'],
      );
      final r2 = RectangleElement(
        id: const ElementId('r2'),
        x: 60,
        y: 0,
        width: 50,
        height: 50,
        groupIds: ['group-a'],
      );

      final item = LibraryUtils.createFromElements(
        elements: [r1, r2],
        name: 'Grouped',
      );

      expect(item.elements[0].groupIds, ['group-a']);
      expect(item.elements[1].groupIds, ['group-a']);
    });
  });

  group('LibraryUtils.instantiate', () {
    test('single element placed at position', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(200, 300),
      );

      final adds = _extractAdds(result);
      expect(adds, hasLength(1));
      // Centered: 200 - 100/2 = 150, 300 - 50/2 = 275
      expect(adds.first.x, 150);
      expect(adds.first.y, 275);
    });

    test('multi-element centered at position', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 50,
          height: 50,
        ),
        RectangleElement(
          id: const ElementId('r2'),
          x: 100,
          y: 100,
          width: 50,
          height: 50,
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(300, 400),
      );

      final adds = _extractAdds(result);
      expect(adds, hasLength(2));
      // Item bounds: 0,0 to 150,150 → center offset: 300-75=225, 400-75=325
      expect(adds[0].x, 225);
      expect(adds[0].y, 325);
      expect(adds[1].x, 325);
      expect(adds[1].y, 425);
    });

    test('generates fresh IDs', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final adds = _extractAdds(result);
      expect(adds.first.id, isNot(const ElementId('r1')));
    });

    test('remaps groupIds', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 50,
          height: 50,
          groupIds: ['group-a'],
        ),
        RectangleElement(
          id: const ElementId('r2'),
          x: 60,
          y: 0,
          width: 50,
          height: 50,
          groupIds: ['group-a'],
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final adds = _extractAdds(result);
      // Both should share a new groupId (not 'group-a')
      expect(adds[0].groupIds, hasLength(1));
      expect(adds[0].groupIds.first, isNot('group-a'));
      expect(adds[0].groupIds, equals(adds[1].groupIds));
    });

    test('remaps frameIds', () {
      final item = _makeItem([
        FrameElement(
          id: const ElementId('frame-1'),
          x: 0,
          y: 0,
          width: 200,
          height: 200,
          label: 'Frame',
        ),
        RectangleElement(
          id: const ElementId('r1'),
          x: 10,
          y: 10,
          width: 50,
          height: 50,
          frameId: 'frame-1',
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final adds = _extractAdds(result);
      final frameAdd = adds.firstWhere((e) => e is FrameElement);
      final rectAdd = adds.firstWhere((e) => e is RectangleElement);
      // frameId should be remapped to the new frame's ID
      expect(rectAdd.frameId, frameAdd.id.value);
      expect(rectAdd.frameId, isNot('frame-1'));
    });

    test('remaps bound text containerId', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          boundElements: [const BoundElement(id: 't1', type: 'text')],
        ),
        TextElement(
          id: const ElementId('t1'),
          x: 5,
          y: 5,
          width: 90,
          height: 20,
          text: 'Label',
          containerId: 'r1',
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final adds = _extractAdds(result);
      final rectAdd = adds.firstWhere((e) => e is RectangleElement);
      final textAdd = adds.whereType<TextElement>().first;
      expect(textAdd.containerId, rectAdd.id.value);
      expect(textAdd.containerId, isNot('r1'));
      // boundElements should also be remapped
      expect(rectAdd.boundElements.first.id, textAdd.id.value);
    });

    test('includes AddFileResult for images', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final item = _makeItem(
        [
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
          'file-abc': ImageFile(mimeType: 'image/png', bytes: imageBytes),
        },
      );

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final compound = result as CompoundResult;
      final fileResults =
          compound.results.whereType<AddFileResult>().toList();
      expect(fileResults, hasLength(1));
      expect(fileResults.first.fileId, 'file-abc');
      expect(fileResults.first.file.bytes, imageBytes);
    });

    test('selects placed elements (excluding bound text)', () {
      final item = _makeItem([
        RectangleElement(
          id: const ElementId('r1'),
          x: 0,
          y: 0,
          width: 100,
          height: 50,
          boundElements: [const BoundElement(id: 't1', type: 'text')],
        ),
        TextElement(
          id: const ElementId('t1'),
          x: 5,
          y: 5,
          width: 90,
          height: 20,
          text: 'Label',
          containerId: 'r1',
        ),
      ]);

      final result = LibraryUtils.instantiate(
        item: item,
        position: const Point(0, 0),
      );

      final compound = result as CompoundResult;
      final selectionResult =
          compound.results.whereType<SetSelectionResult>().first;
      // Only the rectangle should be selected, not the bound text
      expect(selectionResult.selectedIds, hasLength(1));
    });
  });
}

LibraryItem _makeItem(
  List<Element> elements, {
  Map<String, ImageFile> files = const {},
}) {
  return LibraryItem(
    id: 'test-item',
    name: 'Test',
    elements: elements,
    files: files,
  );
}

List<Element> _extractAdds(ToolResult result) {
  final compound = result as CompoundResult;
  return compound.results
      .whereType<AddElementResult>()
      .map((r) => r.element)
      .toList();
}
