import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' as core show TextElement;
import 'package:markdraw/markdraw.dart' hide TextElement;

void main() {
  group('cullElements', () {
    const canvasSize = Size(800, 600);
    const defaultViewport = ViewportState();

    test('all visible elements returned', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 100, y: 100, width: 200, height: 100,
        ),
        EllipseElement(
          id: const ElementId('e1'),
          x: 400, y: 200, width: 150, height: 100,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result.length, 2);
    });

    test('off-screen elements filtered out', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 100, y: 100, width: 200, height: 100,
        ),
        RectangleElement(
          id: const ElementId('r2'),
          x: 2000, y: 2000, width: 100, height: 100,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result.length, 1);
      expect(result[0].id, const ElementId('r1'));
    });

    test('partial overlap included', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: -50, y: -30, width: 100, height: 100,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result.length, 1);
    });

    test('deleted elements excluded', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 100, y: 100, width: 200, height: 100,
          isDeleted: true,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result, isEmpty);
    });

    test('bound text excluded', () {
      final elements = [
        core.TextElement(
          id: const ElementId('t1'),
          x: 100, y: 100, width: 200, height: 40,
          text: 'Bound text',
          containerId: 'r1',
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result, isEmpty);
    });

    test('margin includes near-edge elements', () {
      // Element is just off-screen to the right (at x=800)
      // but within the default 50px margin
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 810, y: 100, width: 100, height: 100,
        ),
      ];

      // Without margin, this would be filtered (visible rect is 0..800)
      // With margin=50, expanded rect is -50..850 in scene coords
      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result.length, 1);
    });

    test('element beyond margin is filtered', () {
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 900, y: 100, width: 100, height: 100,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result, isEmpty);
    });

    test('zoom affects visibility', () {
      // At zoom 2.0, visible scene rect is 0..400 x 0..300
      const viewport = ViewportState(zoom: 2.0);
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 500, y: 100, width: 100, height: 100,
        ),
      ];

      final result = cullElements(elements, viewport, canvasSize);
      // 500 > 400 + 50/2 = 425, so off-screen even with margin
      expect(result, isEmpty);
    });

    test('pan shifts visible window', () {
      const viewport = ViewportState(offset: Offset(1000, 1000));
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 100, y: 100, width: 200, height: 100,
        ),
        RectangleElement(
          id: const ElementId('r2'),
          x: 1200, y: 1200, width: 200, height: 100,
        ),
      ];

      final result = cullElements(elements, viewport, canvasSize);
      // r1 is at 100,100 but viewport starts at 1000,1000 → off-screen
      // r2 is at 1200,1200 → visible (1000..1800 x 1000..1600)
      expect(result.length, 1);
      expect(result[0].id, const ElementId('r2'));
    });

    test('empty list returns empty', () {
      final result = cullElements([], defaultViewport, canvasSize);
      expect(result, isEmpty);
    });

    test('mixed visible and invisible', () {
      final elements = [
        RectangleElement(
          id: const ElementId('visible1'),
          x: 100, y: 100, width: 200, height: 100,
        ),
        RectangleElement(
          id: const ElementId('invisible1'),
          x: 5000, y: 5000, width: 100, height: 100,
        ),
        EllipseElement(
          id: const ElementId('visible2'),
          x: 300, y: 200, width: 150, height: 80,
        ),
        RectangleElement(
          id: const ElementId('invisible2'),
          x: -500, y: -500, width: 100, height: 100,
        ),
      ];

      final result = cullElements(elements, defaultViewport, canvasSize);
      expect(result.length, 2);
      expect(result.map((e) => e.id.value), containsAll(['visible1', 'visible2']));
    });

    test('custom margin value', () {
      // Element is at x=860, just beyond default 50px margin (visible rect 0..800 + 50 = 850)
      final elements = [
        RectangleElement(
          id: const ElementId('r1'),
          x: 860, y: 100, width: 100, height: 100,
        ),
      ];

      // With margin=0, filtered (860 > 800)
      final noMargin = cullElements(
        elements, defaultViewport, canvasSize, margin: 0,
      );
      expect(noMargin, isEmpty);

      // With margin=100, included (860 < 800 + 100 = 900)
      final bigMargin = cullElements(
        elements, defaultViewport, canvasSize, margin: 100,
      );
      expect(bigMargin.length, 1);
    });
  });
}
