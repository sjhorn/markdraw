import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('Scene.sceneBounds', () {
    test('empty scene returns null', () {
      final scene = Scene();
      expect(scene.sceneBounds(), isNull);
    });

    test('single element returns its bounds', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      ));

      final bounds = scene.sceneBounds();
      expect(bounds, isNotNull);
      expect(bounds, equals(Bounds.fromLTWH(10, 20, 100, 50)));
    });

    test('multiple elements returns union bounds', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 100,
        width: 80,
        height: 60,
      ));

      final bounds = scene.sceneBounds();
      expect(bounds, isNotNull);
      // Union: left=0, top=0, right=280, bottom=160
      expect(bounds!.left, 0);
      expect(bounds.top, 0);
      expect(bounds.right, 280);
      expect(bounds.bottom, 160);
    });

    test('deleted elements excluded', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 500,
        y: 500,
        width: 200,
        height: 200,
        isDeleted: true,
      ));

      final bounds = scene.sceneBounds();
      expect(bounds, isNotNull);
      // Only the rectangle should be included
      expect(bounds, equals(Bounds.fromLTWH(0, 0, 100, 50)));
    });

    test('mixed element types all included', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
      ));
      scene = scene.addElement(LineElement(
        id: const ElementId('l1'),
        x: 200,
        y: 200,
        width: 100,
        height: 0,
        points: [const Point(200, 200), const Point(300, 200)],
      ));
      scene = scene.addElement(FreedrawElement(
        id: const ElementId('f1'),
        x: -50,
        y: -20,
        width: 30,
        height: 15,
        points: [const Point(0, 0), const Point(30, 15)],
      ));

      final bounds = scene.sceneBounds();
      expect(bounds, isNotNull);
      // Union: left=-50, top=-20, right=300, bottom=200
      expect(bounds!.left, -50);
      expect(bounds.top, -20);
      expect(bounds.right, 300);
      expect(bounds.bottom, 200);
    });

    test('all deleted returns null', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        isDeleted: true,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 100,
        width: 80,
        height: 60,
        isDeleted: true,
      ));

      expect(scene.sceneBounds(), isNull);
    });
  });
}
