import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FractionalIndex', () {
    test('generateAfter null returns midpoint', () {
      final key = FractionalIndex.generateAfter(null);
      expect(key, 'V');
    });

    test('generateAfter appends midpoint', () {
      final key = FractionalIndex.generateAfter('V');
      expect(key, 'VV');
      expect('V'.compareTo(key), lessThan(0));
    });

    test('generateBefore null returns midpoint', () {
      final key = FractionalIndex.generateBefore(null);
      expect(key, 'V');
    });

    test('generateBefore produces key less than input', () {
      final key = FractionalIndex.generateBefore('V');
      expect(key.compareTo('V'), lessThan(0));
    });

    test('generateBetween produces key between a and b', () {
      final key = FractionalIndex.generateBetween('A', 'Z');
      expect(key.compareTo('A'), greaterThan(0));
      expect(key.compareTo('Z'), lessThan(0));
    });

    test('generateBetween with adjacent characters goes deeper', () {
      final key = FractionalIndex.generateBetween('A', 'B');
      expect(key.compareTo('A'), greaterThan(0));
      expect(key.compareTo('B'), lessThan(0));
    });

    test('generateNKeys returns n sorted keys', () {
      final keys = FractionalIndex.generateNKeys(5, after: 'A');
      expect(keys, hasLength(5));
      for (var i = 0; i < keys.length - 1; i++) {
        expect(keys[i].compareTo(keys[i + 1]), lessThan(0),
            reason: 'keys[$i] "${keys[i]}" should be < keys[${i + 1}] "${keys[i + 1]}"');
      }
      // All should be after 'A'
      for (final k in keys) {
        expect(k.compareTo('A'), greaterThan(0));
      }
    });

    test('generateNKeys with before constraint', () {
      final keys = FractionalIndex.generateNKeys(3, before: 'Z');
      expect(keys, hasLength(3));
      for (final k in keys) {
        expect(k.compareTo('Z'), lessThan(0));
      }
    });

    test('generateNKeys with both constraints', () {
      final keys =
          FractionalIndex.generateNKeys(3, after: 'A', before: 'z');
      expect(keys, hasLength(3));
      for (final k in keys) {
        expect(k.compareTo('A'), greaterThan(0));
        expect(k.compareTo('z'), lessThan(0));
      }
    });

    test('generateNKeys zero returns empty', () {
      final keys = FractionalIndex.generateNKeys(0);
      expect(keys, isEmpty);
    });

    test('generateNKeys one returns single key', () {
      final keys = FractionalIndex.generateNKeys(1);
      expect(keys, hasLength(1));
    });
  });
}
