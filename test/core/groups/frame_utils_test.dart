import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/frame_element.dart';
import 'package:markdraw/src/core/groups/frame_utils.dart';
import 'package:markdraw/src/core/scene/scene.dart';

FrameElement _frame({
  required String id,
  double x = 0,
  double y = 0,
  double w = 400,
  double h = 300,
  String label = 'Frame',
}) =>
    FrameElement(
      id: ElementId(id),
      x: x,
      y: y,
      width: w,
      height: h,
      label: label,
    );

Element _rect({
  required String id,
  double x = 0,
  double y = 0,
  double w = 50,
  double h = 50,
  String? frameId,
}) =>
    Element(
      id: ElementId(id),
      type: 'rectangle',
      x: x,
      y: y,
      width: w,
      height: h,
      frameId: frameId,
    );

void main() {
  group('findFrameChildren', () {
    test('returns empty for no children', () {
      final scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_rect(id: 'r1'));
      expect(FrameUtils.findFrameChildren(scene, const ElementId('f1')),
          isEmpty);
    });

    test('finds elements with matching frameId', () {
      final scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_rect(id: 'r1', frameId: 'f1'))
          .addElement(_rect(id: 'r2', frameId: 'f1'))
          .addElement(_rect(id: 'r3'));
      final children =
          FrameUtils.findFrameChildren(scene, const ElementId('f1'));
      expect(children, hasLength(2));
      expect(children.map((e) => e.id.value), containsAll(['r1', 'r2']));
    });

    test('skips deleted elements', () {
      var scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_rect(id: 'r1', frameId: 'f1'))
          .addElement(_rect(id: 'r2', frameId: 'f1'));
      scene = scene.softDeleteElement(const ElementId('r2'));
      final children =
          FrameUtils.findFrameChildren(scene, const ElementId('f1'));
      expect(children, hasLength(1));
      expect(children.first.id.value, 'r1');
    });

    test('does not return elements from different frame', () {
      final scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_frame(id: 'f2'))
          .addElement(_rect(id: 'r1', frameId: 'f2'));
      expect(FrameUtils.findFrameChildren(scene, const ElementId('f1')),
          isEmpty);
    });
  });

  group('isInsideFrame', () {
    test('returns true when element is fully inside frame', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final rect = _rect(id: 'r1', x: 10, y: 10, w: 50, h: 50);
      expect(FrameUtils.isInsideFrame(rect, frame), isTrue);
    });

    test('returns true when element exactly matches frame bounds', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final rect = _rect(id: 'r1', x: 0, y: 0, w: 400, h: 300);
      expect(FrameUtils.isInsideFrame(rect, frame), isTrue);
    });

    test('returns false when element extends beyond frame right edge', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final rect = _rect(id: 'r1', x: 380, y: 10, w: 50, h: 50);
      expect(FrameUtils.isInsideFrame(rect, frame), isFalse);
    });

    test('returns false when element is completely outside frame', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final rect = _rect(id: 'r1', x: 500, y: 500, w: 50, h: 50);
      expect(FrameUtils.isInsideFrame(rect, frame), isFalse);
    });
  });

  group('assignToFrame', () {
    test('sets frameId on elements', () {
      final elements = [_rect(id: 'r1'), _rect(id: 'r2')];
      final assigned =
          FrameUtils.assignToFrame(elements, const ElementId('f1'));
      expect(assigned[0].frameId, 'f1');
      expect(assigned[1].frameId, 'f1');
    });

    test('overwrites existing frameId', () {
      final elements = [_rect(id: 'r1', frameId: 'f1')];
      final assigned =
          FrameUtils.assignToFrame(elements, const ElementId('f2'));
      expect(assigned[0].frameId, 'f2');
    });

    test('does not mutate originals', () {
      final original = _rect(id: 'r1');
      FrameUtils.assignToFrame([original], const ElementId('f1'));
      expect(original.frameId, isNull);
    });
  });

  group('removeFromFrame', () {
    test('clears frameId on elements', () {
      final elements = [
        _rect(id: 'r1', frameId: 'f1'),
        _rect(id: 'r2', frameId: 'f1'),
      ];
      final removed = FrameUtils.removeFromFrame(elements);
      expect(removed[0].frameId, isNull);
      expect(removed[1].frameId, isNull);
    });

    test('works on elements with no frameId', () {
      final elements = [_rect(id: 'r1')];
      final removed = FrameUtils.removeFromFrame(elements);
      expect(removed[0].frameId, isNull);
    });

    test('does not mutate originals', () {
      final original = _rect(id: 'r1', frameId: 'f1');
      FrameUtils.removeFromFrame([original]);
      expect(original.frameId, 'f1');
    });
  });

  group('findContainingFrame', () {
    test('finds frame that contains element', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final rect = _rect(id: 'r1', x: 10, y: 10, w: 50, h: 50);
      final scene = Scene().addElement(frame).addElement(rect);
      final result = FrameUtils.findContainingFrame(scene, rect);
      expect(result, isNotNull);
      expect(result!.id, const ElementId('f1'));
    });

    test('returns null when no frame contains element', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 100, h: 100);
      final rect = _rect(id: 'r1', x: 500, y: 500, w: 50, h: 50);
      final scene = Scene().addElement(frame).addElement(rect);
      expect(FrameUtils.findContainingFrame(scene, rect), isNull);
    });

    test('returns smallest frame when nested', () {
      final outer = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final inner = _frame(id: 'f2', x: 10, y: 10, w: 200, h: 150);
      final rect = _rect(id: 'r1', x: 20, y: 20, w: 50, h: 50);
      final scene =
          Scene().addElement(outer).addElement(inner).addElement(rect);
      final result = FrameUtils.findContainingFrame(scene, rect);
      expect(result!.id, const ElementId('f2'));
    });

    test('does not match frame with itself', () {
      final frame = _frame(id: 'f1', x: 0, y: 0, w: 400, h: 300);
      final scene = Scene().addElement(frame);
      expect(FrameUtils.findContainingFrame(scene, frame), isNull);
    });
  });

  group('releaseFrameChildren', () {
    test('clears frameId on all children', () {
      final scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_rect(id: 'r1', frameId: 'f1'))
          .addElement(_rect(id: 'r2', frameId: 'f1'));
      final released =
          FrameUtils.releaseFrameChildren(scene, const ElementId('f1'));
      expect(released, hasLength(2));
      expect(released[0].frameId, isNull);
      expect(released[1].frameId, isNull);
    });

    test('returns empty when no children', () {
      final scene = Scene().addElement(_frame(id: 'f1'));
      final released =
          FrameUtils.releaseFrameChildren(scene, const ElementId('f1'));
      expect(released, isEmpty);
    });

    test('does not affect elements in other frames', () {
      final scene = Scene()
          .addElement(_frame(id: 'f1'))
          .addElement(_frame(id: 'f2'))
          .addElement(_rect(id: 'r1', frameId: 'f1'))
          .addElement(_rect(id: 'r2', frameId: 'f2'));
      final released =
          FrameUtils.releaseFrameChildren(scene, const ElementId('f1'));
      expect(released, hasLength(1));
      expect(released[0].id.value, 'r1');
    });
  });
}
