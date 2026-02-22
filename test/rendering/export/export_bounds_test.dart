import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/export/export_bounds.dart';

void main() {
  group('ExportBounds', () {
    test('returns null for empty scene', () {
      final scene = Scene();
      final bounds = ExportBounds.compute(scene);
      expect(bounds, isNull);
    });

    test('returns padded bounds for single element', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 50,
        height: 30,
      ));
      final bounds = ExportBounds.compute(scene);
      expect(bounds, isNotNull);
      // 100-20=80, 200-20=180, right=150+20=170, bottom=230+20=250
      expect(bounds!.left, 80);
      expect(bounds.top, 180);
      expect(bounds.size.width, 90); // 50 + 40 padding
      expect(bounds.size.height, 70); // 30 + 40 padding
    });

    test('returns union bounds for multiple elements', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 300,
        width: 100,
        height: 80,
      ));
      final bounds = ExportBounds.compute(scene);
      expect(bounds, isNotNull);
      // Union: 0,0 → 300,380; padded: -20,-20 → 320,400
      expect(bounds!.left, -20);
      expect(bounds.top, -20);
      expect(bounds.size.width, 340); // 300 + 40
      expect(bounds.size.height, 420); // 380 + 40
    });

    test('respects selection subset', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      ));
      scene = scene.addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 200,
        y: 300,
        width: 100,
        height: 80,
      ));
      final bounds = ExportBounds.compute(
        scene,
        selectedIds: {const ElementId('e1')},
      );
      expect(bounds, isNotNull);
      // Only e1: 200,300 → 300,380; padded: 180,280 → 320,400
      expect(bounds!.left, 180);
      expect(bounds.top, 280);
      expect(bounds.size.width, 140); // 100 + 40
      expect(bounds.size.height, 120); // 80 + 40
    });

    test('applies custom padding', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 50,
        height: 50,
      ));
      final bounds = ExportBounds.compute(scene, padding: 10);
      expect(bounds, isNotNull);
      expect(bounds!.left, 90);
      expect(bounds.top, 90);
      expect(bounds.size.width, 70); // 50 + 20
      expect(bounds.size.height, 70);
    });

    test('includes bound text when parent is in selection', () {
      var scene = Scene();
      final rectId = const ElementId('r1');
      scene = scene.addElement(RectangleElement(
        id: rectId,
        x: 100,
        y: 100,
        width: 200,
        height: 100,
      ));
      // Bound text outside parent bounds (positioned elsewhere)
      scene = scene.addElement(TextElement(
        id: const ElementId('t1'),
        x: 500,
        y: 500,
        width: 50,
        height: 20,
        text: 'Label',
        containerId: rectId.value,
      ));
      // Selection includes only parent — bound text should be included
      final bounds = ExportBounds.compute(
        scene,
        selectedIds: {rectId},
      );
      expect(bounds, isNotNull);
      // Union: 100,100 → 550,520; padded
      expect(bounds!.left, 80); // min(100,500) - 20
      expect(bounds.top, 80); // min(100,500) - 20
    });

    test('excludes deleted elements', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      ));
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r2'),
        x: 500,
        y: 500,
        width: 50,
        height: 50,
        isDeleted: true,
      ));
      final bounds = ExportBounds.compute(scene);
      expect(bounds, isNotNull);
      // Only r1 (non-deleted): 0,0 → 50,50; padded: -20,-20 → 70,70
      expect(bounds!.left, -20);
      expect(bounds.top, -20);
      expect(bounds.size.width, 90);
      expect(bounds.size.height, 90);
    });

    test('handles zero-size elements', () {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 0,
        height: 0,
      ));
      final bounds = ExportBounds.compute(scene);
      expect(bounds, isNotNull);
      // 0-size element at 100,100; padded: 80,80 → 120,120
      expect(bounds!.left, 80);
      expect(bounds.top, 80);
      expect(bounds.size.width, 40); // 0 + 40
      expect(bounds.size.height, 40);
    });

    test('returns null when selection is empty set', () {
      var scene = Scene();
      scene = scene.addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 100,
        width: 50,
        height: 50,
      ));
      final bounds = ExportBounds.compute(
        scene,
        selectedIds: {},
      );
      expect(bounds, isNull);
    });
  });
}
