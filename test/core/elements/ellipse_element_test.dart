import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('EllipseElement', () {
    test('constructs with type ellipse', () {
      final e = EllipseElement(
        id: const ElementId('ell-1'),
        x: 10.0,
        y: 20.0,
        width: 100.0,
        height: 80.0,
      );
      expect(e.type, 'ellipse');
      expect(e.x, 10.0);
      expect(e.y, 20.0);
      expect(e.width, 100.0);
      expect(e.height, 80.0);
    });

    test('copyWith preserves ellipse type', () {
      final e = EllipseElement(
        id: const ElementId('ell-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
      );
      final modified = e.copyWith(width: 200.0);
      expect(modified, isA<EllipseElement>());
      expect(modified.type, 'ellipse');
      expect(modified.width, 200.0);
    });

    test('bumpVersion returns EllipseElement', () {
      final e = EllipseElement(
        id: const ElementId('ell-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
      );
      expect(e.bumpVersion(), isA<EllipseElement>());
    });
  });
}
