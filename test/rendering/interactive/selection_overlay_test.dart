import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('HandleType', () {
    test('has 9 values (8 resize + 1 rotation)', () {
      expect(HandleType.values.length, 9);
    });

    test('contains all expected types', () {
      expect(HandleType.values, containsAll([
        HandleType.topLeft,
        HandleType.topCenter,
        HandleType.topRight,
        HandleType.middleLeft,
        HandleType.middleRight,
        HandleType.bottomLeft,
        HandleType.bottomCenter,
        HandleType.bottomRight,
        HandleType.rotation,
      ]));
    });
  });

  group('Handle', () {
    test('stores type and position', () {
      const handle = Handle(
        type: HandleType.topLeft,
        position: Point(10, 20),
      );
      expect(handle.type, HandleType.topLeft);
      expect(handle.position, const Point(10, 20));
    });

    test('equality by type and position', () {
      const a = Handle(type: HandleType.topLeft, position: Point(10, 20));
      const b = Handle(type: HandleType.topLeft, position: Point(10, 20));
      const c = Handle(type: HandleType.topRight, position: Point(10, 20));
      const d = Handle(type: HandleType.topLeft, position: Point(30, 40));

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      const a = Handle(type: HandleType.topLeft, position: Point(10, 20));
      const b = Handle(type: HandleType.topLeft, position: Point(10, 20));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SelectionOverlay', () {
    test('computeHandles returns 9 handles', () {
      final bounds = Bounds.fromLTWH(100, 200, 300, 150);
      final handles = SelectionOverlay.computeHandles(bounds);
      expect(handles.length, 9);
    });

    test('corner handles match bounds corners', () {
      final bounds = Bounds.fromLTWH(100, 200, 300, 150);
      final handles = SelectionOverlay.computeHandles(bounds);
      final byType = {for (final h in handles) h.type: h.position};

      expect(byType[HandleType.topLeft], const Point(100, 200));
      expect(byType[HandleType.topRight], const Point(400, 200));
      expect(byType[HandleType.bottomLeft], const Point(100, 350));
      expect(byType[HandleType.bottomRight], const Point(400, 350));
    });

    test('midpoint handles match edge midpoints', () {
      final bounds = Bounds.fromLTWH(100, 200, 300, 150);
      final handles = SelectionOverlay.computeHandles(bounds);
      final byType = {for (final h in handles) h.type: h.position};

      expect(byType[HandleType.topCenter], const Point(250, 200));
      expect(byType[HandleType.bottomCenter], const Point(250, 350));
      expect(byType[HandleType.middleLeft], const Point(100, 275));
      expect(byType[HandleType.middleRight], const Point(400, 275));
    });

    test('rotation handle positioned above top-center', () {
      final bounds = Bounds.fromLTWH(100, 200, 300, 150);
      final handles = SelectionOverlay.computeHandles(bounds);
      final byType = {for (final h in handles) h.type: h.position};

      final rotation = byType[HandleType.rotation]!;
      final topCenter = byType[HandleType.topCenter]!;

      // Same x as top-center
      expect(rotation.x, topCenter.x);
      // Above top-center (lower y value)
      expect(rotation.y, lessThan(topCenter.y));
    });

    test('fromElements with single element matches element bounds', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 100,
        width: 200,
        height: 150,
      );

      final overlay = SelectionOverlay.fromElements([element]);
      expect(overlay, isNotNull);
      expect(overlay!.bounds, Bounds.fromLTWH(50, 100, 200, 150));
    });

    test('fromElements with multiple elements uses union bounds', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 100,
        width: 100,
        height: 80,
      );
      final e2 = EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 50,
        width: 150,
        height: 200,
      );

      final overlay = SelectionOverlay.fromElements([e1, e2]);
      expect(overlay, isNotNull);
      // Union: left=50, top=50, right=350, bottom=250
      expect(overlay!.bounds, Bounds.fromLTWH(50, 50, 300, 200));
    });

    test('fromElements with empty list returns null', () {
      final overlay = SelectionOverlay.fromElements([]);
      expect(overlay, isNull);
    });

    test('stores angle property', () {
      final bounds = Bounds.fromLTWH(0, 0, 100, 100);
      final handles = SelectionOverlay.computeHandles(bounds);
      final overlay = SelectionOverlay(
        bounds: bounds,
        handles: handles,
        angle: 0.5,
      );
      expect(overlay.angle, 0.5);
    });

    test('fromElements defaults angle to 0 for multiple elements', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 200,
        width: 100,
        height: 100,
      );

      final overlay = SelectionOverlay.fromElements([e1, e2]);
      expect(overlay!.angle, 0.0);
    });

    test('fromElements with single rotated element preserves angle', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 100,
        width: 200,
        height: 150,
        angle: 1.2,
      );

      final overlay = SelectionOverlay.fromElements([element]);
      expect(overlay!.angle, 1.2);
    });

    test('equality by value', () {
      final bounds = Bounds.fromLTWH(0, 0, 100, 100);
      final handles = SelectionOverlay.computeHandles(bounds);
      final a = SelectionOverlay(bounds: bounds, handles: handles, angle: 0);
      final b = SelectionOverlay(bounds: bounds, handles: handles, angle: 0);
      final c = SelectionOverlay(bounds: bounds, handles: handles, angle: 0.5);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
