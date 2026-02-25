import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('ElementId', () {
    test('generate produces unique values', () {
      final a = ElementId.generate();
      final b = ElementId.generate();
      expect(a, isNot(equals(b)));
    });

    test('constructs from string value', () {
      const id = ElementId('test-id-123');
      expect(id.value, 'test-id-123');
    });

    test('equality based on value', () {
      const a = ElementId('abc');
      const b = ElementId('abc');
      const c = ElementId('xyz');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = ElementId('abc');
      const b = ElementId('abc');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns the value', () {
      const id = ElementId('my-id');
      expect(id.toString(), 'my-id');
    });
  });
}
