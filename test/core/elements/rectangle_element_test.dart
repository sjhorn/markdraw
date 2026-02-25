import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('RectangleElement', () {
    RectangleElement createRect({
      ElementId? id,
      double x = 0.0,
      double y = 0.0,
      double width = 100.0,
      double height = 50.0,
      Roundness? roundness,
    }) {
      return RectangleElement(
        id: id ?? const ElementId('rect-1'),
        x: x,
        y: y,
        width: width,
        height: height,
        roundness: roundness,
      );
    }

    test('constructs with type rectangle', () {
      final r = createRect();
      expect(r.type, 'rectangle');
    });

    test('supports roundness property', () {
      final r = createRect(
        roundness: const Roundness.adaptive(value: 10.0),
      );
      expect(r.roundness, const Roundness.adaptive(value: 10.0));
    });

    test('copyWith preserves rectangle type', () {
      final r = createRect();
      final modified = r.copyWith(x: 50.0);
      expect(modified, isA<RectangleElement>());
      expect(modified.type, 'rectangle');
      expect(modified.x, 50.0);
    });

    test('copyWith can change roundness', () {
      final r = createRect();
      final modified = r.copyWith(
        roundness: const Roundness.proportional(value: 0.5),
      );
      expect(modified.roundness, const Roundness.proportional(value: 0.5));
    });

    test('bumpVersion returns RectangleElement', () {
      final r = createRect();
      final bumped = r.bumpVersion();
      expect(bumped, isA<RectangleElement>());
      expect(bumped.version, r.version + 1);
    });

    test('softDelete returns RectangleElement', () {
      final r = createRect();
      final deleted = r.softDelete();
      expect(deleted, isA<RectangleElement>());
      expect(deleted.isDeleted, true);
    });
  });
}
