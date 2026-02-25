import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('DiamondElement', () {
    test('constructs with type diamond', () {
      final d = DiamondElement(
        id: const ElementId('dia-1'),
        x: 10.0,
        y: 20.0,
        width: 100.0,
        height: 80.0,
      );
      expect(d.type, 'diamond');
    });

    test('copyWith preserves diamond type', () {
      final d = DiamondElement(
        id: const ElementId('dia-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
      );
      final modified = d.copyWith(height: 50.0);
      expect(modified, isA<DiamondElement>());
      expect(modified.type, 'diamond');
      expect(modified.height, 50.0);
    });

    test('bumpVersion returns DiamondElement', () {
      final d = DiamondElement(
        id: const ElementId('dia-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
      );
      expect(d.bumpVersion(), isA<DiamondElement>());
    });
  });
}
