import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  RectangleElement makeRect(String id, double x, double y,
          {double w = 50, double h = 50}) =>
      RectangleElement(
        id: ElementId(id),
        x: x, y: y, width: w, height: h,
      );

  group('AlignmentUtils align', () {
    test('alignLeft aligns to leftmost x', () {
      final elements = [makeRect('a', 10, 0), makeRect('b', 50, 0), makeRect('c', 100, 0)];
      final result = AlignmentUtils.alignLeft(elements);
      expect(result, hasLength(3));
      for (final e in result) {
        expect(e.x, 10);
      }
    });

    test('alignRight aligns right edges', () {
      final elements = [makeRect('a', 0, 0, w: 30), makeRect('b', 50, 0, w: 100)];
      final result = AlignmentUtils.alignRight(elements);
      // Union right = 50 + 100 = 150
      expect(result[0].x, 150 - 30);
      expect(result[1].x, 150 - 100);
    });

    test('alignCenterH aligns horizontal centers', () {
      final elements = [makeRect('a', 0, 0, w: 20), makeRect('b', 80, 0, w: 20)];
      final result = AlignmentUtils.alignCenterH(elements);
      // Union left=0, right=100, center=50
      expect(result[0].x, 50 - 10); // 40
      expect(result[1].x, 50 - 10); // 40
    });

    test('alignTop aligns to topmost y', () {
      final elements = [makeRect('a', 0, 20), makeRect('b', 0, 80)];
      final result = AlignmentUtils.alignTop(elements);
      for (final e in result) {
        expect(e.y, 20);
      }
    });

    test('alignBottom aligns bottom edges', () {
      final elements = [makeRect('a', 0, 0, h: 30), makeRect('b', 0, 50, h: 100)];
      final result = AlignmentUtils.alignBottom(elements);
      // Union bottom = 50 + 100 = 150
      expect(result[0].y, 150 - 30);
      expect(result[1].y, 150 - 100);
    });

    test('alignCenterV aligns vertical centers', () {
      final elements = [makeRect('a', 0, 0, h: 20), makeRect('b', 0, 80, h: 20)];
      final result = AlignmentUtils.alignCenterV(elements);
      // Union top=0, bottom=100, center=50
      expect(result[0].y, 50 - 10); // 40
      expect(result[1].y, 50 - 10); // 40
    });

    test('returns empty for single element', () {
      final elements = [makeRect('a', 0, 0)];
      expect(AlignmentUtils.alignLeft(elements), isEmpty);
      expect(AlignmentUtils.alignTop(elements), isEmpty);
    });

    test('returns empty for empty list', () {
      expect(AlignmentUtils.alignLeft([]), isEmpty);
    });
  });

  group('AlignmentUtils distribute', () {
    test('distributeH spaces elements evenly', () {
      // Three elements: first at x=0 w=20, second at x=10 w=20, third at x=100 w=20
      // Total width = 120 (0 to 120), elem widths = 60, gaps = 60/2 = 30
      final elements = [
        makeRect('a', 0, 0, w: 20),
        makeRect('b', 10, 0, w: 20),
        makeRect('c', 100, 0, w: 20),
      ];
      final result = AlignmentUtils.distributeH(elements);
      expect(result, hasLength(3));
      // Sorted by x: a(0), b(10), c(100)
      // First stays at 0, gap = (120-60)/2 = 30
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.x.compareTo(b.x));
      expect(sorted[0].x, 0);
      expect(sorted[1].x, closeTo(50, 0.01)); // 0+20+30
      expect(sorted[2].x, closeTo(100, 0.01)); // 50+20+30
    });

    test('distributeV spaces elements evenly', () {
      final elements = [
        makeRect('a', 0, 0, h: 20),
        makeRect('b', 0, 10, h: 20),
        makeRect('c', 0, 100, h: 20),
      ];
      final result = AlignmentUtils.distributeV(elements);
      expect(result, hasLength(3));
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.y.compareTo(b.y));
      expect(sorted[0].y, 0);
      expect(sorted[1].y, closeTo(50, 0.01));
      expect(sorted[2].y, closeTo(100, 0.01));
    });

    test('distributeH returns empty for fewer than 3', () {
      final elements = [makeRect('a', 0, 0), makeRect('b', 100, 0)];
      expect(AlignmentUtils.distributeH(elements), isEmpty);
    });

    test('distributeV returns empty for fewer than 3', () {
      final elements = [makeRect('a', 0, 0), makeRect('b', 0, 100)];
      expect(AlignmentUtils.distributeV(elements), isEmpty);
    });

    test('distributeH with 4 elements', () {
      final elements = [
        makeRect('a', 0, 0, w: 10),
        makeRect('b', 20, 0, w: 10),
        makeRect('c', 40, 0, w: 10),
        makeRect('d', 90, 0, w: 10),
      ];
      final result = AlignmentUtils.distributeH(elements);
      expect(result, hasLength(4));
      // Total = 100, elem widths = 40, gaps = 60/3 = 20
      final sorted = List<Element>.of(result)
        ..sort((a, b) => a.x.compareTo(b.x));
      expect(sorted[0].x, 0);
      expect(sorted[1].x, closeTo(30, 0.01));
      expect(sorted[2].x, closeTo(60, 0.01));
      expect(sorted[3].x, closeTo(90, 0.01));
    });
  });
}
