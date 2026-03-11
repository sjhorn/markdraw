import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('buildObjectSnapCache', () {
    test('collects positions from elements', () {
      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100,
            y: 200,
            width: 50,
            height: 30,
          ))
          .addElement(EllipseElement(
            id: const ElementId('e1'),
            x: 300,
            y: 400,
            width: 60,
            height: 40,
          ));

      final cache = buildObjectSnapCache(scene, {});

      // r1: left=100, center=125, right=150, top=200, center=215, bottom=230
      // e1: left=300, center=330, right=360, top=400, center=420, bottom=440
      expect(cache.xPositions, containsAll([100, 125, 150, 300, 330, 360]));
      expect(cache.yPositions, containsAll([200, 215, 230, 400, 420, 440]));
      expect(cache.sourceBounds, hasLength(2));
    });

    test('excludes specified IDs', () {
      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100,
            y: 200,
            width: 50,
            height: 30,
          ))
          .addElement(EllipseElement(
            id: const ElementId('e1'),
            x: 300,
            y: 400,
            width: 60,
            height: 40,
          ));

      final cache =
          buildObjectSnapCache(scene, {const ElementId('r1')});

      // Only e1 positions
      expect(cache.xPositions, hasLength(3));
      expect(cache.yPositions, hasLength(3));
      expect(cache.xPositions, containsAll([300, 330, 360]));
    });

    test('excludes bound text elements', () {
      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 100,
            y: 200,
            width: 50,
            height: 30,
          ))
          .addElement(TextElement(
            id: const ElementId('t1'),
            x: 100,
            y: 200,
            width: 50,
            height: 30,
            text: 'bound',
            containerId: 'r1',
          ));

      final cache = buildObjectSnapCache(scene, {});

      // Only r1 positions (t1 is bound text, excluded)
      expect(cache.xPositions, hasLength(3));
      expect(cache.sourceBounds, hasLength(1));
    });

    test('empty scene produces empty cache', () {
      final cache = buildObjectSnapCache(Scene(), {});

      expect(cache.xPositions, isEmpty);
      expect(cache.yPositions, isEmpty);
      expect(cache.sourceBounds, isEmpty);
    });
  });

  group('snapToObjects', () {
    late ObjectSnapCache cache;

    setUp(() {
      // Reference element at (100, 200) size 50x30
      // left=100, center=125, right=150
      // top=200, center=215, bottom=230
      cache = const ObjectSnapCache(
        xPositions: [100, 125, 150],
        yPositions: [200, 215, 230],
        sourceBounds: [
          Bounds(Point(100, 200), DrawSize(50, 30)),
        ],
      );
    });

    test('snaps left edge to right edge of reference', () {
      // Moving bounds: left=147, right=197 → left should snap to 150
      final moving = Bounds.fromLTWH(147, 300, 50, 30);
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.dx, 3.0); // 150 - 147
      expect(result.dy, 0.0); // no Y snap within threshold
    });

    test('snaps center to center', () {
      // Moving bounds center at 127 → should snap to 125
      final moving = Bounds.fromLTWH(102, 300, 50, 30);
      // center.x = 102 + 25 = 127, closest reference x is 125
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.dx, -2.0); // 125 - 127
    });

    test('no snap beyond threshold', () {
      // Moving bounds too far from any reference
      final moving = Bounds.fromLTWH(500, 500, 50, 30);
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.dx, 0.0);
      expect(result.dy, 0.0);
      expect(result.snapLines, isEmpty);
    });

    test('snaps axes independently', () {
      // Close to right (150) on X, close to bottom (230) on Y
      final moving = Bounds.fromLTWH(148, 227, 50, 30);
      // left=148, closest x=150, dx=+2
      // top=227, closest y=230, dy=+3
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.dx, 2.0);
      expect(result.dy, 3.0);
      expect(result.snapLines, hasLength(2));
    });

    test('generates correct snap lines', () {
      // Moving bounds: left=147 → snaps to 150 (vertical line)
      final moving = Bounds.fromLTWH(147, 250, 50, 30);
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.snapLines, hasLength(1));
      final line = result.snapLines.first;
      expect(line.orientation, SnapLineOrientation.vertical);
      expect(line.position, 150.0);
      // Vertical line should span from min(ref.top, moving.top+dy) to
      // max(ref.bottom, moving.bottom+dy)
      expect(line.start, 200.0); // ref top is 200, moving top is 250
      expect(line.end, 280.0); // moving bottom = 250+30 = 280
    });

    test('no adjustment when already aligned', () {
      // Moving bounds left is exactly on reference right
      final moving = Bounds.fromLTWH(150, 300, 50, 30);
      final result = snapToObjects(moving, cache, 8.0);

      expect(result.dx, 0.0); // already aligned
    });
  });
}
