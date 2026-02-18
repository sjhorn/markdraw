import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  group('ViewportState', () {
    test('default state has zero offset and zoom 1.0', () {
      const state = ViewportState();
      expect(state.offset, Offset.zero);
      expect(state.zoom, 1.0);
    });

    test('accepts custom offset and zoom', () {
      const state = ViewportState(offset: Offset(100, 200), zoom: 2.0);
      expect(state.offset, const Offset(100, 200));
      expect(state.zoom, 2.0);
    });

    test('visibleRect at zoom 1.0 equals full canvas', () {
      const state = ViewportState();
      final rect = state.visibleRect(const Size(800, 600));
      expect(rect, const Rect.fromLTWH(0, 0, 800, 600));
    });

    test('visibleRect at zoom 2.0 shows half canvas area', () {
      const state = ViewportState(zoom: 2.0);
      final rect = state.visibleRect(const Size(800, 600));
      // At zoom 2x, we see half the scene in each dimension
      expect(rect.width, 400.0);
      expect(rect.height, 300.0);
      expect(rect.left, 0.0);
      expect(rect.top, 0.0);
    });

    test('visibleRect at zoom 0.5 shows double canvas area', () {
      const state = ViewportState(zoom: 0.5);
      final rect = state.visibleRect(const Size(800, 600));
      expect(rect.width, 1600.0);
      expect(rect.height, 1200.0);
    });

    test('visibleRect with offset shifts the visible area', () {
      const state = ViewportState(offset: Offset(100, 50));
      final rect = state.visibleRect(const Size(800, 600));
      expect(rect.left, 100.0);
      expect(rect.top, 50.0);
      expect(rect.width, 800.0);
      expect(rect.height, 600.0);
    });

    test('visibleRect with offset and zoom combined', () {
      const state = ViewportState(offset: Offset(100, 50), zoom: 2.0);
      final rect = state.visibleRect(const Size(800, 600));
      expect(rect.left, 100.0);
      expect(rect.top, 50.0);
      expect(rect.width, 400.0);
      expect(rect.height, 300.0);
    });

    test('equality by value', () {
      const a = ViewportState(offset: Offset(10, 20), zoom: 1.5);
      const b = ViewportState(offset: Offset(10, 20), zoom: 1.5);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality when different', () {
      const a = ViewportState(offset: Offset(10, 20), zoom: 1.5);
      const b = ViewportState(offset: Offset(10, 20), zoom: 2.0);
      expect(a, isNot(equals(b)));
    });
  });
}
