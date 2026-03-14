import 'package:flutter_test/flutter_test.dart';
import 'package:rough_flutter/rough_flutter.dart';

import 'package:markdraw/src/rendering/rough/rough_path_cache.dart';

Generator _makeGenerator() {
  final config = DrawConfig.build(roughness: 1, seed: 42);
  final filler = HachureFiller(FillerConfig.build(drawConfig: config));
  return Generator(config, filler);
}

void main() {
  group('RoughPathCache', () {
    test('returns null on cache miss', () {
      final cache = RoughPathCache();
      expect(cache.get('elem1', 42), isNull);
    });

    test('returns cached drawable on hit', () {
      final cache = RoughPathCache();
      final generator = _makeGenerator();
      final drawable = generator.rectangle(0, 0, 100, 100);
      cache.put('elem1', 42, drawable);
      expect(cache.get('elem1', 42), same(drawable));
    });

    test('returns null when hash changes (element modified)', () {
      final cache = RoughPathCache();
      final generator = _makeGenerator();
      final drawable = generator.rectangle(0, 0, 100, 100);
      cache.put('elem1', 42, drawable);
      expect(cache.get('elem1', 99), isNull);
    });

    test('evicts oldest entries when exceeding maxSize', () {
      final cache = RoughPathCache(maxSize: 2);
      final generator = _makeGenerator();
      final d1 = generator.rectangle(0, 0, 10, 10);
      final d2 = generator.rectangle(0, 0, 20, 20);
      final d3 = generator.rectangle(0, 0, 30, 30);

      cache.put('e1', 1, d1);
      cache.put('e2', 2, d2);
      expect(cache.length, 2);

      cache.put('e3', 3, d3);
      expect(cache.length, 2);
      expect(cache.get('e1', 1), isNull); // evicted
      expect(cache.get('e2', 2), same(d2));
      expect(cache.get('e3', 3), same(d3));
    });

    test('invalidates old hash when element changes', () {
      final cache = RoughPathCache();
      final generator = _makeGenerator();
      final d1 = generator.rectangle(0, 0, 100, 100);
      final d2 = generator.rectangle(0, 0, 200, 200);

      cache.put('elem1', 42, d1);
      expect(cache.get('elem1', 42), same(d1));

      // Element modified — new hash
      cache.put('elem1', 99, d2);
      expect(cache.get('elem1', 42), isNull); // old hash cleared
      expect(cache.get('elem1', 99), same(d2));
    });

    test('LRU order updates on get', () {
      final cache = RoughPathCache(maxSize: 2);
      final generator = _makeGenerator();
      final d1 = generator.rectangle(0, 0, 10, 10);
      final d2 = generator.rectangle(0, 0, 20, 20);
      final d3 = generator.rectangle(0, 0, 30, 30);

      cache.put('e1', 1, d1);
      cache.put('e2', 2, d2);

      // Access e1 to make it most recently used
      cache.get('e1', 1);

      // Adding e3 should evict e2 (least recently used), not e1
      cache.put('e3', 3, d3);
      expect(cache.get('e1', 1), same(d1));
      expect(cache.get('e2', 2), isNull); // evicted
    });

    test('clear removes all entries', () {
      final cache = RoughPathCache();
      final generator = _makeGenerator();
      cache.put('e1', 1, generator.rectangle(0, 0, 10, 10));
      cache.put('e2', 2, generator.rectangle(0, 0, 20, 20));
      expect(cache.length, 2);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('e1', 1), isNull);
    });
  });
}
