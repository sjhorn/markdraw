import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('Element', () {
    Element createTestElement({
      ElementId? id,
      String type = 'rectangle',
      double x = 0.0,
      double y = 0.0,
      double width = 100.0,
      double height = 50.0,
    }) {
      return Element(
        id: id ?? const ElementId('test-id'),
        type: type,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }

    test('constructs with required properties', () {
      final e = createTestElement();
      expect(e.id, const ElementId('test-id'));
      expect(e.type, 'rectangle');
      expect(e.x, 0.0);
      expect(e.y, 0.0);
      expect(e.width, 100.0);
      expect(e.height, 50.0);
    });

    test('has sensible defaults for optional properties', () {
      final e = createTestElement();
      expect(e.angle, 0.0);
      expect(e.strokeColor, '#000000');
      expect(e.backgroundColor, 'transparent');
      expect(e.fillStyle, FillStyle.solid);
      expect(e.strokeWidth, 2.0);
      expect(e.strokeStyle, StrokeStyle.solid);
      expect(e.roughness, 1.0);
      expect(e.opacity, 1.0);
      expect(e.roundness, isNull);
      expect(e.seed, isNotNull);
      expect(e.version, 1);
      expect(e.versionNonce, isNotNull);
      expect(e.isDeleted, false);
      expect(e.groupIds, isEmpty);
      expect(e.frameId, isNull);
      expect(e.boundElements, isEmpty);
      expect(e.updated, isNotNull);
      expect(e.link, isNull);
      expect(e.locked, false);
      expect(e.index, isNull);
    });

    test('constructs with all optional properties', () {
      final e = Element(
        id: const ElementId('full-id'),
        type: 'rectangle',
        x: 10.0,
        y: 20.0,
        width: 200.0,
        height: 100.0,
        angle: 0.5,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        fillStyle: FillStyle.hachure,
        strokeWidth: 4.0,
        strokeStyle: StrokeStyle.dashed,
        roughness: 2.0,
        opacity: 0.8,
        roundness: const Roundness.adaptive(value: 10.0),
        seed: 42,
        version: 3,
        versionNonce: 99,
        isDeleted: true,
        groupIds: const ['g1', 'g2'],
        frameId: 'frame-1',
        boundElements: const [BoundElement(id: 'be-1', type: 'arrow')],
        updated: 1000,
        link: 'https://example.com',
        locked: true,
        index: 'a0',
      );

      expect(e.angle, 0.5);
      expect(e.strokeColor, '#ff0000');
      expect(e.backgroundColor, '#00ff00');
      expect(e.fillStyle, FillStyle.hachure);
      expect(e.strokeWidth, 4.0);
      expect(e.strokeStyle, StrokeStyle.dashed);
      expect(e.roughness, 2.0);
      expect(e.opacity, 0.8);
      expect(e.roundness, const Roundness.adaptive(value: 10.0));
      expect(e.seed, 42);
      expect(e.version, 3);
      expect(e.versionNonce, 99);
      expect(e.isDeleted, true);
      expect(e.groupIds, ['g1', 'g2']);
      expect(e.frameId, 'frame-1');
      expect(e.boundElements.length, 1);
      expect(e.updated, 1000);
      expect(e.link, 'https://example.com');
      expect(e.locked, true);
      expect(e.index, 'a0');
    });

    test('copyWith creates new instance with changed values', () {
      final original = createTestElement();
      final modified = original.copyWith(x: 50.0, y: 75.0);

      expect(modified.x, 50.0);
      expect(modified.y, 75.0);
      // Unchanged properties
      expect(modified.id, original.id);
      expect(modified.type, original.type);
      expect(modified.width, original.width);
    });

    test('copyWith with no arguments returns equal element', () {
      final original = createTestElement();
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.x, original.x);
      expect(copy.y, original.y);
    });

    test('bumpVersion increments version and updates nonce', () {
      final original = createTestElement();
      final bumped = original.bumpVersion();
      expect(bumped.version, original.version + 1);
      expect(bumped.versionNonce, isNot(equals(original.versionNonce)));
    });

    test('softDelete sets isDeleted to true', () {
      final original = createTestElement();
      expect(original.isDeleted, false);
      final deleted = original.softDelete();
      expect(deleted.isDeleted, true);
    });

    test('softDelete bumps version', () {
      final original = createTestElement();
      final deleted = original.softDelete();
      expect(deleted.version, original.version + 1);
    });

    test('equality based on id', () {
      final a = createTestElement(id: const ElementId('same'));
      final b = createTestElement(id: const ElementId('same'), x: 999.0);
      final c = createTestElement(id: const ElementId('different'));
      // Elements are equal if they have the same id
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on id', () {
      final a = createTestElement(id: const ElementId('same'));
      final b = createTestElement(id: const ElementId('same'), x: 999.0);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('BoundElement', () {
    test('constructs with id and type', () {
      const be = BoundElement(id: 'arrow-1', type: 'arrow');
      expect(be.id, 'arrow-1');
      expect(be.type, 'arrow');
    });

    test('equality', () {
      const a = BoundElement(id: 'a', type: 'arrow');
      const b = BoundElement(id: 'a', type: 'arrow');
      const c = BoundElement(id: 'b', type: 'arrow');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
