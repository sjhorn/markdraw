import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/bindings/bound_text_utils.dart';
import 'package:markdraw/src/editor/tool_result.dart';

void main() {
  group('BoundTextUtils', () {
    group('isTextContainer', () {
      test('true for rectangle', () {
        final rect = RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(BoundTextUtils.isTextContainer(rect), isTrue);
      });

      test('true for ellipse', () {
        final ellipse = EllipseElement(
          id: const ElementId('e1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(BoundTextUtils.isTextContainer(ellipse), isTrue);
      });

      test('true for diamond', () {
        final diamond = DiamondElement(
          id: const ElementId('d1'),
          x: 0, y: 0, width: 100, height: 50,
        );
        expect(BoundTextUtils.isTextContainer(diamond), isTrue);
      });

      test('false for line', () {
        final line = LineElement(
          id: const ElementId('l1'),
          x: 0, y: 0, width: 100, height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
        );
        expect(BoundTextUtils.isTextContainer(line), isFalse);
      });

      test('false for arrow', () {
        final arrow = ArrowElement(
          id: const ElementId('a1'),
          x: 0, y: 0, width: 100, height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
        );
        expect(BoundTextUtils.isTextContainer(arrow), isFalse);
      });

      test('false for text', () {
        final text = TextElement(
          id: const ElementId('t1'),
          x: 0, y: 0, width: 100, height: 20,
          text: 'Hello',
        );
        expect(BoundTextUtils.isTextContainer(text), isFalse);
      });

      test('false for freedraw', () {
        final fd = FreedrawElement(
          id: const ElementId('f1'),
          x: 0, y: 0, width: 100, height: 50,
          points: [const Point(0, 0), const Point(100, 50)],
        );
        expect(BoundTextUtils.isTextContainer(fd), isFalse);
      });
    });

    group('findBoundText', () {
      test('returns matching text element', () {
        final scene = Scene()
            .addElement(RectangleElement(
              id: const ElementId('r1'),
              x: 0, y: 0, width: 100, height: 50,
            ))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 20,
              text: 'Label',
              containerId: 'r1',
            ));
        final found = BoundTextUtils.findBoundText(
            scene, const ElementId('r1'));
        expect(found, isNotNull);
        expect(found!.text, 'Label');
      });

      test('returns null when none exists', () {
        final scene = Scene().addElement(RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 50,
        ));
        final found = BoundTextUtils.findBoundText(
            scene, const ElementId('r1'));
        expect(found, isNull);
      });
    });

    group('updateBoundTextPositions', () {
      test('returns empty when no bound text', () {
        final scene = Scene().addElement(RectangleElement(
          id: const ElementId('r1'),
          x: 0, y: 0, width: 100, height: 50,
        ));
        final movedRect = RectangleElement(
          id: const ElementId('r1'),
          x: 50, y: 50, width: 100, height: 50,
        );
        final results =
            BoundTextUtils.updateBoundTextPositions(scene, [movedRect]);
        expect(results, isEmpty);
      });

      test('syncs x/y/width/height from parent', () {
        final scene = Scene()
            .addElement(RectangleElement(
              id: const ElementId('r1'),
              x: 0, y: 0, width: 100, height: 50,
            ))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 50,
              text: 'Label',
              containerId: 'r1',
            ));
        final movedRect = RectangleElement(
          id: const ElementId('r1'),
          x: 200, y: 300, width: 150, height: 80,
        );
        final results =
            BoundTextUtils.updateBoundTextPositions(scene, [movedRect]);
        expect(results, hasLength(1));
        final update = results.first as UpdateElementResult;
        expect(update.element.x, 200);
        expect(update.element.y, 300);
        expect(update.element.width, 150);
        expect(update.element.height, 80);
      });

      test('handles multiple parents', () {
        final scene = Scene()
            .addElement(RectangleElement(
              id: const ElementId('r1'),
              x: 0, y: 0, width: 100, height: 50,
            ))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 50,
              text: 'Label 1',
              containerId: 'r1',
            ))
            .addElement(EllipseElement(
              id: const ElementId('e1'),
              x: 200, y: 200, width: 80, height: 80,
            ))
            .addElement(TextElement(
              id: const ElementId('t2'),
              x: 200, y: 200, width: 80, height: 80,
              text: 'Label 2',
              containerId: 'e1',
            ));
        final movedRect = RectangleElement(
          id: const ElementId('r1'),
          x: 10, y: 10, width: 100, height: 50,
        );
        final movedEllipse = EllipseElement(
          id: const ElementId('e1'),
          x: 210, y: 210, width: 80, height: 80,
        );
        final results = BoundTextUtils.updateBoundTextPositions(
            scene, [movedRect, movedEllipse]);
        expect(results, hasLength(2));
      });

      test('skips parent with no bound text', () {
        final scene = Scene()
            .addElement(RectangleElement(
              id: const ElementId('r1'),
              x: 0, y: 0, width: 100, height: 50,
            ))
            .addElement(RectangleElement(
              id: const ElementId('r2'),
              x: 200, y: 200, width: 100, height: 50,
            ))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 50,
              text: 'Label',
              containerId: 'r1',
            ));
        final movedR1 = RectangleElement(
          id: const ElementId('r1'), x: 10, y: 10, width: 100, height: 50,
        );
        final movedR2 = RectangleElement(
          id: const ElementId('r2'), x: 210, y: 210, width: 100, height: 50,
        );
        final results = BoundTextUtils.updateBoundTextPositions(
            scene, [movedR1, movedR2]);
        expect(results, hasLength(1));
      });

      test('preserves text content', () {
        final scene = Scene()
            .addElement(RectangleElement(
              id: const ElementId('r1'),
              x: 0, y: 0, width: 100, height: 50,
            ))
            .addElement(TextElement(
              id: const ElementId('t1'),
              x: 0, y: 0, width: 100, height: 50,
              text: 'Important text',
              containerId: 'r1',
            ));
        final movedRect = RectangleElement(
          id: const ElementId('r1'),
          x: 50, y: 50, width: 100, height: 50,
        );
        final results =
            BoundTextUtils.updateBoundTextPositions(scene, [movedRect]);
        final update = results.first as UpdateElementResult;
        final text = update.element as TextElement;
        expect(text.text, 'Important text');
        expect(text.containerId, 'r1');
      });
    });
  });
}
