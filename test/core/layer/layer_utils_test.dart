import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  RectangleElement makeRect(String id, {String? index}) => RectangleElement(
        id: ElementId(id),
        x: 0, y: 0, width: 100, height: 100,
        index: index,
      );

  group('LayerUtils.ensureIndices', () {
    test('assigns indices to elements without them', () {
      final scene = Scene()
          .addElement(makeRect('a'))
          .addElement(makeRect('b'));
      final updated = LayerUtils.ensureIndices(scene);
      expect(updated, hasLength(2));
      expect(updated[0].index, isNotNull);
      expect(updated[1].index, isNotNull);
      expect(updated[0].index!.compareTo(updated[1].index!), lessThan(0));
    });

    test('preserves existing indices', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'M'))
          .addElement(makeRect('b'));
      final updated = LayerUtils.ensureIndices(scene);
      expect(updated, hasLength(1));
      expect(updated[0].id, const ElementId('b'));
      expect(updated[0].index!.compareTo('M'), greaterThan(0));
    });

    test('returns empty when all have indices', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'));
      final updated = LayerUtils.ensureIndices(scene);
      expect(updated, isEmpty);
    });
  });

  group('LayerUtils.bringToFront', () {
    test('moves element above all others', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final updated =
          LayerUtils.bringToFront(scene, {const ElementId('a')});
      expect(updated, hasLength(1));
      expect(updated[0].id, const ElementId('a'));
      expect(updated[0].index!.compareTo('C'), greaterThan(0));
    });

    test('returns empty for empty selection', () {
      final scene = Scene().addElement(makeRect('a', index: 'A'));
      final updated = LayerUtils.bringToFront(scene, {});
      expect(updated, isEmpty);
    });

    test('moves multiple elements preserving relative order', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'))
          .addElement(makeRect('d', index: 'D'));
      final updated = LayerUtils.bringToFront(
          scene, {const ElementId('a'), const ElementId('b')});
      expect(updated, hasLength(2));
      // Both should be above D
      for (final e in updated) {
        expect(e.index!.compareTo('D'), greaterThan(0));
      }
      // a should be before b
      expect(updated[0].index!.compareTo(updated[1].index!), lessThan(0));
    });
  });

  group('LayerUtils.sendToBack', () {
    test('moves element below all others', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final updated =
          LayerUtils.sendToBack(scene, {const ElementId('c')});
      expect(updated, hasLength(1));
      expect(updated[0].id, const ElementId('c'));
      expect(updated[0].index!.compareTo('A'), lessThan(0));
    });

    test('returns empty for empty selection', () {
      final scene = Scene().addElement(makeRect('a', index: 'A'));
      final updated = LayerUtils.sendToBack(scene, {});
      expect(updated, isEmpty);
    });
  });

  group('LayerUtils.bringForward', () {
    test('swaps element with one above', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final updated =
          LayerUtils.bringForward(scene, {const ElementId('a')});
      expect(updated, hasLength(2));
      // a should now have b's old index, b should have a's old index
      final aResult = updated.firstWhere((e) => e.id == const ElementId('a'));
      final bResult = updated.firstWhere((e) => e.id == const ElementId('b'));
      expect(aResult.index, 'B');
      expect(bResult.index, 'A');
    });

    test('returns empty when already at top', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'));
      final updated =
          LayerUtils.bringForward(scene, {const ElementId('b')});
      expect(updated, isEmpty);
    });
  });

  group('LayerUtils.sendBackward', () {
    test('swaps element with one below', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final updated =
          LayerUtils.sendBackward(scene, {const ElementId('c')});
      expect(updated, hasLength(2));
      final cResult = updated.firstWhere((e) => e.id == const ElementId('c'));
      final bResult = updated.firstWhere((e) => e.id == const ElementId('b'));
      expect(cResult.index, 'B');
      expect(bResult.index, 'C');
    });

    test('returns empty when already at bottom', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'));
      final updated =
          LayerUtils.sendBackward(scene, {const ElementId('a')});
      expect(updated, isEmpty);
    });

    test('returns empty for empty selection', () {
      final scene = Scene().addElement(makeRect('a', index: 'A'));
      final updated = LayerUtils.sendBackward(scene, {});
      expect(updated, isEmpty);
    });
  });
}
