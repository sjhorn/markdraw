import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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

  group('ViewportState.screenToScene', () {
    test('identity at default state', () {
      const state = ViewportState();
      final result = state.screenToScene(const Offset(100, 200));
      expect(result, const Offset(100, 200));
    });

    test('accounts for zoom', () {
      const state = ViewportState(zoom: 2.0);
      final result = state.screenToScene(const Offset(200, 100));
      expect(result, const Offset(100, 50));
    });

    test('accounts for offset', () {
      const state = ViewportState(offset: Offset(50, 30));
      final result = state.screenToScene(const Offset(100, 100));
      expect(result, const Offset(150, 130));
    });

    test('accounts for offset and zoom combined', () {
      const state = ViewportState(offset: Offset(50, 30), zoom: 2.0);
      final result = state.screenToScene(const Offset(200, 100));
      // 200/2 + 50 = 150, 100/2 + 30 = 80
      expect(result, const Offset(150, 80));
    });
  });

  group('ViewportState.sceneToScreen', () {
    test('identity at default state', () {
      const state = ViewportState();
      final result = state.sceneToScreen(const Offset(100, 200));
      expect(result, const Offset(100, 200));
    });

    test('accounts for zoom', () {
      const state = ViewportState(zoom: 2.0);
      final result = state.sceneToScreen(const Offset(100, 50));
      expect(result, const Offset(200, 100));
    });

    test('accounts for offset', () {
      const state = ViewportState(offset: Offset(50, 30));
      final result = state.sceneToScreen(const Offset(150, 130));
      expect(result, const Offset(100, 100));
    });

    test('round-trip screenToScene and sceneToScreen', () {
      const state = ViewportState(offset: Offset(73, 42), zoom: 1.7);
      const original = Offset(300, 250);
      final scene = state.screenToScene(original);
      final back = state.sceneToScreen(scene);
      expect(back.dx, closeTo(original.dx, 1e-10));
      expect(back.dy, closeTo(original.dy, 1e-10));
    });
  });

  group('ViewportState.pan', () {
    test('pan at zoom 1.0', () {
      const state = ViewportState();
      final panned = state.pan(const Offset(100, 50));
      // Screen delta 100,50 at zoom 1.0 → scene delta 100,50
      expect(panned.offset, const Offset(-100, -50));
      expect(panned.zoom, 1.0);
    });

    test('pan at zoom 2.0 scales delta', () {
      const state = ViewportState(zoom: 2.0);
      final panned = state.pan(const Offset(100, 50));
      // Screen delta 100,50 at zoom 2.0 → scene delta 50,25
      expect(panned.offset, const Offset(-50, -25));
      expect(panned.zoom, 2.0);
    });

    test('pan accumulates from existing offset', () {
      const state = ViewportState(offset: Offset(200, 100));
      final panned = state.pan(const Offset(50, 30));
      expect(panned.offset, const Offset(150, 70));
      expect(panned.zoom, 1.0);
    });

    test('pan preserves zoom', () {
      const state = ViewportState(zoom: 3.0);
      final panned = state.pan(const Offset(10, 10));
      expect(panned.zoom, 3.0);
    });
  });

  group('ViewportState.zoomAt', () {
    test('zoom in preserves anchor point', () {
      const state = ViewportState();
      const anchor = Offset(400, 300);
      final zoomed = state.zoomAt(2.0, anchor);
      // The scene point under the anchor should be the same before and after
      final sceneBefore = state.screenToScene(anchor);
      final sceneAfter = zoomed.screenToScene(anchor);
      expect(sceneAfter.dx, closeTo(sceneBefore.dx, 1e-10));
      expect(sceneAfter.dy, closeTo(sceneBefore.dy, 1e-10));
    });

    test('zoom out preserves anchor point', () {
      const state = ViewportState(zoom: 2.0, offset: Offset(100, 50));
      const anchor = Offset(300, 200);
      final zoomed = state.zoomAt(0.5, anchor);
      final sceneBefore = state.screenToScene(anchor);
      final sceneAfter = zoomed.screenToScene(anchor);
      expect(sceneAfter.dx, closeTo(sceneBefore.dx, 1e-10));
      expect(sceneAfter.dy, closeTo(sceneBefore.dy, 1e-10));
    });

    test('clamps to minZoom', () {
      const state = ViewportState(zoom: 0.2);
      final zoomed = state.zoomAt(0.1, Offset.zero, minZoom: 0.1);
      expect(zoomed.zoom, 0.1);
    });

    test('clamps to maxZoom', () {
      const state = ViewportState(zoom: 9.0);
      final zoomed = state.zoomAt(2.0, Offset.zero, maxZoom: 10.0);
      expect(zoomed.zoom, 10.0);
    });

    test('default clamp range is 0.1 to 10.0', () {
      const state = ViewportState(zoom: 1.0);
      final zoomedWayIn = state.zoomAt(100.0, Offset.zero);
      expect(zoomedWayIn.zoom, 10.0);

      final zoomedWayOut = state.zoomAt(0.001, Offset.zero);
      expect(zoomedWayOut.zoom, closeTo(0.1, 0.01));
    });

    test('zoom at corner preserves corner anchor', () {
      const state = ViewportState();
      const anchor = Offset.zero; // top-left corner
      final zoomed = state.zoomAt(3.0, anchor);
      // At origin with zero offset, zooming should keep origin fixed
      expect(zoomed.offset.dx, closeTo(0, 1e-10));
      expect(zoomed.offset.dy, closeTo(0, 1e-10));
      expect(zoomed.zoom, 3.0);
    });
  });

  group('ViewportState.fitToBounds', () {
    test('null bounds returns default state', () {
      final fitted = const ViewportState(zoom: 2.0, offset: Offset(100, 50))
          .fitToBounds(null, const Size(800, 600));
      expect(fitted.offset, Offset.zero);
      expect(fitted.zoom, 1.0);
    });

    test('fits wide content horizontally', () {
      // Content is 1000x100, canvas is 800x600
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(0, 0, 1000, 100),
        const Size(800, 600),
      );
      // Zoom limited by width: 800/1000 = 0.8
      expect(fitted.zoom, closeTo(0.8, 1e-10));
    });

    test('fits tall content vertically', () {
      // Content is 100x1000, canvas is 800x600
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(0, 0, 100, 1000),
        const Size(800, 600),
      );
      // Zoom limited by height: 600/1000 = 0.6
      expect(fitted.zoom, closeTo(0.6, 1e-10));
    });

    test('centers content in canvas', () {
      // Content 400x200 in 800x600 canvas → zoom=1.0 (limited by height if padding=0? no, fits)
      // Actually zoom = min(800/400, 600/200) = min(2, 3) = 2.0
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(100, 100, 400, 200),
        const Size(800, 600),
      );
      // zoom = 2.0, content center at (300, 200), canvas center at (400, 300)
      // offset.x = contentCenter.x - canvasCenter.x / zoom = 300 - 400/2 = 100
      // offset.y = contentCenter.y - canvasCenter.y / zoom = 200 - 300/2 = 50
      expect(fitted.zoom, 2.0);
      expect(fitted.offset.dx, closeTo(100, 1e-10));
      expect(fitted.offset.dy, closeTo(50, 1e-10));
    });

    test('applies padding', () {
      // Content 800x600 in 800x600 canvas with 40px padding
      // Effective canvas: 720x520
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(0, 0, 800, 600),
        const Size(800, 600),
        padding: 40,
      );
      // zoom = min(720/800, 520/600) = min(0.9, 0.8667) = 0.8667
      expect(fitted.zoom, closeTo(520 / 600, 1e-10));
    });

    test('zero-size canvas returns default state', () {
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(0, 0, 100, 100),
        Size.zero,
      );
      expect(fitted.offset, Offset.zero);
      expect(fitted.zoom, 1.0);
    });

    test('zero-size bounds returns centered at bounds origin', () {
      // A point element at (50, 50) with zero dimensions
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(50, 50, 0, 0),
        const Size(800, 600),
      );
      // Can't compute zoom from zero-size bounds, default to zoom 1.0
      // Center at (50, 50)
      expect(fitted.zoom, 1.0);
      expect(fitted.offset.dx, closeTo(50 - 400, 1e-10)); // -350
      expect(fitted.offset.dy, closeTo(50 - 300, 1e-10)); // -250
    });

    test('content with negative coordinates', () {
      final fitted = const ViewportState().fitToBounds(
        Bounds.fromLTWH(-200, -100, 400, 200),
        const Size(800, 600),
      );
      // zoom = min(800/400, 600/200) = min(2, 3) = 2.0
      // content center = (0, 0)
      // offset = center - canvasCenter/zoom = (0 - 200, 0 - 150) = (-200, -150)
      expect(fitted.zoom, 2.0);
      expect(fitted.offset.dx, closeTo(-200, 1e-10));
      expect(fitted.offset.dy, closeTo(-150, 1e-10));
    });
  });
}
