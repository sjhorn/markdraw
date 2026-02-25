import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('Scene', () {
    Element createRect({
      String id = 'r1',
      double x = 0.0,
      double y = 0.0,
      double width = 100.0,
      double height = 50.0,
      String? index,
      bool isDeleted = false,
    }) {
      return RectangleElement(
        id: ElementId(id),
        x: x,
        y: y,
        width: width,
        height: height,
        index: index,
        isDeleted: isDeleted,
      );
    }

    test('starts empty', () {
      final scene = Scene();
      expect(scene.elements, isEmpty);
    });

    test('addElement adds to scene', () {
      final scene = Scene();
      final rect = createRect();
      final updated = scene.addElement(rect);
      expect(updated.elements.length, 1);
      expect(updated.elements.first.id, const ElementId('r1'));
    });

    test('addElement does not mutate original scene', () {
      final scene = Scene();
      final rect = createRect();
      scene.addElement(rect);
      expect(scene.elements, isEmpty);
    });

    test('removeElement removes by id', () {
      final scene = Scene()
          .addElement(createRect(id: 'r1'))
          .addElement(createRect(id: 'r2'));
      final updated = scene.removeElement(const ElementId('r1'));
      expect(updated.elements.length, 1);
      expect(updated.elements.first.id, const ElementId('r2'));
    });

    test('removeElement with non-existent id returns same scene', () {
      final scene = Scene().addElement(createRect(id: 'r1'));
      final updated = scene.removeElement(const ElementId('nonexistent'));
      expect(updated.elements.length, 1);
    });

    test('updateElement replaces element with same id', () {
      final original = createRect(id: 'r1', x: 0.0);
      final scene = Scene().addElement(original);
      final modified = original.copyWith(x: 50.0);
      final updated = scene.updateElement(modified);
      expect(updated.elements.first.x, 50.0);
    });

    test('updateElement bumps version', () {
      final original = createRect(id: 'r1');
      final scene = Scene().addElement(original);
      final modified = original.copyWith(x: 50.0);
      final updated = scene.updateElement(modified);
      expect(updated.elements.first.version, original.version + 1);
    });

    test('getElementById finds element by id', () {
      final scene = Scene()
          .addElement(createRect(id: 'r1'))
          .addElement(createRect(id: 'r2'));
      final found = scene.getElementById(const ElementId('r2'));
      expect(found, isNotNull);
      expect(found!.id, const ElementId('r2'));
    });

    test('getElementById returns null for missing id', () {
      final scene = Scene().addElement(createRect(id: 'r1'));
      expect(scene.getElementById(const ElementId('missing')), isNull);
    });

    test('ordering by fractional index', () {
      final scene = Scene()
          .addElement(createRect(id: 'r3', index: 'c'))
          .addElement(createRect(id: 'r1', index: 'a'))
          .addElement(createRect(id: 'r2', index: 'b'));
      final ordered = scene.orderedElements;
      expect(ordered[0].id, const ElementId('r1'));
      expect(ordered[1].id, const ElementId('r2'));
      expect(ordered[2].id, const ElementId('r3'));
    });

    test('ordering puts null index at end', () {
      final scene = Scene()
          .addElement(createRect(id: 'r2', index: 'b'))
          .addElement(createRect(id: 'r3'))
          .addElement(createRect(id: 'r1', index: 'a'));
      final ordered = scene.orderedElements;
      expect(ordered[0].id, const ElementId('r1'));
      expect(ordered[1].id, const ElementId('r2'));
      expect(ordered[2].id, const ElementId('r3'));
    });

    test('soft deletion marks element as deleted', () {
      final rect = createRect(id: 'r1');
      final scene = Scene().addElement(rect);
      final updated = scene.softDeleteElement(const ElementId('r1'));
      final deleted = updated.getElementById(const ElementId('r1'));
      expect(deleted!.isDeleted, true);
    });

    test('soft deletion bumps version', () {
      final rect = createRect(id: 'r1');
      final scene = Scene().addElement(rect);
      final updated = scene.softDeleteElement(const ElementId('r1'));
      final deleted = updated.getElementById(const ElementId('r1'));
      expect(deleted!.version, rect.version + 1);
    });

    test('activeElements excludes soft-deleted elements', () {
      final scene = Scene()
          .addElement(createRect(id: 'r1'))
          .addElement(createRect(id: 'r2'))
          .softDeleteElement(const ElementId('r1'));
      expect(scene.activeElements.length, 1);
      expect(scene.activeElements.first.id, const ElementId('r2'));
    });

    test('getElementAtPoint returns element containing point', () {
      final scene = Scene()
          .addElement(createRect(id: 'r1', x: 0, y: 0, width: 100, height: 50))
          .addElement(
              createRect(id: 'r2', x: 200, y: 200, width: 100, height: 50));
      final hit = scene.getElementAtPoint(const Point(50.0, 25.0));
      expect(hit, isNotNull);
      expect(hit!.id, const ElementId('r1'));
    });

    test('getElementAtPoint returns null when no hit', () {
      final scene = Scene().addElement(
          createRect(id: 'r1', x: 0, y: 0, width: 100, height: 50));
      final hit = scene.getElementAtPoint(const Point(500.0, 500.0));
      expect(hit, isNull);
    });

    test('getElementAtPoint skips deleted elements', () {
      final scene = Scene()
          .addElement(createRect(id: 'r1', x: 0, y: 0, width: 100, height: 50))
          .softDeleteElement(const ElementId('r1'));
      final hit = scene.getElementAtPoint(const Point(50.0, 25.0));
      expect(hit, isNull);
    });

    test('getElementAtPoint returns topmost (last ordered) element on overlap',
        () {
      final scene = Scene()
          .addElement(createRect(
              id: 'r1', x: 0, y: 0, width: 100, height: 100, index: 'a'))
          .addElement(createRect(
              id: 'r2', x: 50, y: 50, width: 100, height: 100, index: 'b'));
      final hit = scene.getElementAtPoint(const Point(75.0, 75.0));
      expect(hit!.id, const ElementId('r2'));
    });

    test('multiple add and remove operations', () {
      var scene = Scene();
      scene = scene.addElement(createRect(id: 'r1'));
      scene = scene.addElement(createRect(id: 'r2'));
      scene = scene.addElement(createRect(id: 'r3'));
      expect(scene.elements.length, 3);
      scene = scene.removeElement(const ElementId('r2'));
      expect(scene.elements.length, 2);
      expect(scene.getElementById(const ElementId('r2')), isNull);
    });

    group('findBoundText', () {
      test('returns matching text element', () {
        final scene = Scene()
            .addElement(createRect(id: 'r1'))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 20,
              text: 'Label',
              containerId: 'r1',
            ));
        final found = scene.findBoundText(const ElementId('r1'));
        expect(found, isNotNull);
        expect(found!.id, const ElementId('t1'));
        expect(found.text, 'Label');
      });

      test('returns null when none exists', () {
        final scene = Scene().addElement(createRect(id: 'r1'));
        final found = scene.findBoundText(const ElementId('r1'));
        expect(found, isNull);
      });

      test('skips deleted bound text', () {
        final scene = Scene()
            .addElement(createRect(id: 'r1'))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 20,
              text: 'Label',
              containerId: 'r1',
            ))
            .softDeleteElement(const ElementId('t1'));
        final found = scene.findBoundText(const ElementId('r1'));
        expect(found, isNull);
      });
    });

    group('getElementAtPoint skips bound text', () {
      test('skips bound text and returns parent shape', () {
        final scene = Scene()
            .addElement(createRect(
                id: 'r1', x: 0, y: 0, width: 100, height: 100, index: 'a'))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 10, y: 10, width: 80, height: 20,
              text: 'Label',
              containerId: 'r1',
              index: 'b',
            ));
        final hit = scene.getElementAtPoint(const Point(50.0, 15.0));
        expect(hit, isNotNull);
        expect(hit!.id, const ElementId('r1'));
      });

      test('returns null when only bound text at point', () {
        // Bound text exists at the point, but no parent overlaps
        final scene = Scene().addElement(TextElement(
          id: const ElementId('t1'),
          x: 0, y: 0, width: 100, height: 20,
          text: 'Orphan',
          containerId: 'r1',
        ));
        final hit = scene.getElementAtPoint(const Point(50.0, 10.0));
        expect(hit, isNull);
      });
    });
  });
}
