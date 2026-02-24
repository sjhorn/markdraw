import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/math/point.dart';

void main() {
  group('ArrowElement', () {
    ArrowElement createArrow({
      PointBinding? startBinding,
      PointBinding? endBinding,
    }) {
      return ArrowElement(
        id: const ElementId('arrow-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
        points: const [Point(0, 0), Point(100, 100)],
        endArrowhead: Arrowhead.arrow,
        startBinding: startBinding,
        endBinding: endBinding,
      );
    }

    test('constructs with type arrow', () {
      final a = createArrow();
      expect(a.type, 'arrow');
    });

    test('is a LineElement', () {
      final a = createArrow();
      expect(a, isA<LineElement>());
    });

    test('defaults endArrowhead to arrow', () {
      final a = createArrow();
      expect(a.endArrowhead, Arrowhead.arrow);
    });

    test('supports start and end bindings', () {
      final a = createArrow(
        startBinding: const PointBinding(
          elementId: 'rect-1',
          fixedPoint: Point(0.5, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'rect-2',
          fixedPoint: Point(0.0, 0.5),
        ),
      );
      expect(a.startBinding!.elementId, 'rect-1');
      expect(a.endBinding!.elementId, 'rect-2');
      expect(a.endBinding!.fixedPoint, const Point(0.0, 0.5));
    });

    test('bindings default to null', () {
      final a = createArrow();
      expect(a.startBinding, isNull);
      expect(a.endBinding, isNull);
    });

    test('copyWith preserves arrow type', () {
      final a = createArrow(
        startBinding: const PointBinding(
          elementId: 'rect-1',
          fixedPoint: Point(0.5, 0.5),
        ),
      );
      final modified = a.copyWith(x: 50.0);
      expect(modified.type, 'arrow');
      expect(modified.startBinding!.elementId, 'rect-1');
    });

    test('copyWithArrow changes arrow-specific properties', () {
      final a = createArrow();
      final modified = a.copyWithArrow(
        startBinding: const PointBinding(
          elementId: 'ell-1',
          fixedPoint: Point(1.0, 0.5),
        ),
      );
      expect(modified.startBinding!.elementId, 'ell-1');
    });

    test('copyWithLine returns ArrowElement preserving bindings', () {
      final a = createArrow(
        startBinding: const PointBinding(
          elementId: 'rect-1',
          fixedPoint: Point(0.5, 0.5),
        ),
      );
      final modified = a.copyWithLine(
        points: [const Point(10, 20), const Point(200, 300)],
      );
      expect(modified, isA<ArrowElement>());
      expect(modified.type, 'arrow');
      expect(modified.points, [const Point(10, 20), const Point(200, 300)]);
      expect(
        (modified).startBinding!.elementId,
        'rect-1',
      );
    });

    test('bumpVersion returns ArrowElement', () {
      final a = createArrow();
      expect(a.bumpVersion(), isA<ArrowElement>());
    });

    test('elbowed defaults to false', () {
      final a = createArrow();
      expect(a.elbowed, isFalse);
    });

    test('copyWith preserves elbowed', () {
      final a = ArrowElement(
        id: const ElementId('arrow-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
        points: const [Point(0, 0), Point(100, 100)],
        elbowed: true,
      );
      final modified = a.copyWith(x: 50.0);
      expect(modified.elbowed, isTrue);
    });

    test('copyWithLine preserves elbowed', () {
      final a = ArrowElement(
        id: const ElementId('arrow-1'),
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 100.0,
        points: const [Point(0, 0), Point(100, 100)],
        elbowed: true,
      );
      final modified = a.copyWithLine(
        points: [const Point(10, 20), const Point(200, 300)],
      );
      expect(modified.elbowed, isTrue);
    });

    test('copyWithArrow can change elbowed', () {
      final a = createArrow();
      expect(a.elbowed, isFalse);
      final modified = a.copyWithArrow(elbowed: true);
      expect(modified.elbowed, isTrue);
    });
  });

  group('PointBinding', () {
    test('constructs with elementId and fixedPoint', () {
      const b = PointBinding(
        elementId: 'rect-1',
        fixedPoint: Point(0.5, 0.5),
      );
      expect(b.elementId, 'rect-1');
      expect(b.fixedPoint, const Point(0.5, 0.5));
    });

    test('equality', () {
      const a = PointBinding(elementId: 'x', fixedPoint: Point(0, 0));
      const b = PointBinding(elementId: 'x', fixedPoint: Point(0, 0));
      const c = PointBinding(elementId: 'y', fixedPoint: Point(0, 0));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
