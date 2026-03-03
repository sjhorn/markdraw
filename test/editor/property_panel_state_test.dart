import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('PropertyPanelState.fromElements', () {
    test('empty list returns all-null style', () {
      final style = PropertyPanelState.fromElements([]);
      expect(style.strokeColor, isNull);
      expect(style.backgroundColor, isNull);
      expect(style.strokeWidth, isNull);
      expect(style.strokeStyle, isNull);
      expect(style.fillStyle, isNull);
      expect(style.roughness, isNull);
      expect(style.opacity, isNull);
      expect(style.roundness, isNull);
      expect(style.hasRoundness, isFalse);
      expect(style.hasText, isFalse);
      expect(style.fontSize, isNull);
      expect(style.fontFamily, isNull);
      expect(style.textAlign, isNull);
    });

    test('single element returns all properties', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        strokeWidth: 4.0,
        strokeStyle: StrokeStyle.dashed,
        fillStyle: FillStyle.hachure,
        roughness: 2.0,
        opacity: 0.8,
        roundness: const Roundness.adaptive(value: 5),
      );

      final style = PropertyPanelState.fromElements([element]);
      expect(style.strokeColor, '#ff0000');
      expect(style.backgroundColor, '#00ff00');
      expect(style.strokeWidth, 4.0);
      expect(style.strokeStyle, StrokeStyle.dashed);
      expect(style.fillStyle, FillStyle.hachure);
      expect(style.roughness, 2.0);
      expect(style.opacity, 0.8);
      expect(style.roundness, const Roundness.adaptive(value: 5));
      expect(style.hasRoundness, isTrue);
    });

    test('matching elements return common values', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#000000',
        opacity: 0.5,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 50, y: 50, width: 200, height: 200,
        strokeColor: '#000000',
        opacity: 0.5,
      );

      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.strokeColor, '#000000');
      expect(style.opacity, 0.5);
    });

    test('mixed strokeColor returns null', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#ff0000',
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#0000ff',
      );

      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.strokeColor, isNull);
    });

    test('mixed fillStyle returns null', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        fillStyle: FillStyle.solid,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 0, y: 0, width: 100, height: 100,
        fillStyle: FillStyle.hachure,
      );

      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.fillStyle, isNull);
    });

    test('includes text properties when TextElement present', () {
      final textEl = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        fontSize: 24.0,
        fontFamily: 'Helvetica',
        textAlign: TextAlign.center,
      );

      final style = PropertyPanelState.fromElements([textEl]);
      expect(style.hasText, isTrue);
      expect(style.fontSize, 24.0);
      expect(style.fontFamily, 'Helvetica');
      expect(style.textAlign, TextAlign.center);
    });

    test('text properties null when mixed text elements', () {
      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        fontSize: 24.0,
        fontFamily: 'Excalifont',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'World',
        fontSize: 16.0,
        fontFamily: 'Helvetica',
      );

      final style = PropertyPanelState.fromElements([t1, t2]);
      expect(style.hasText, isTrue);
      expect(style.fontSize, isNull);
      expect(style.fontFamily, isNull);
    });

    test('text properties null when no text elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );

      final style = PropertyPanelState.fromElements([rect]);
      expect(style.hasText, isFalse);
      expect(style.fontSize, isNull);
      expect(style.fontFamily, isNull);
      expect(style.textAlign, isNull);
    });

    test('mixed roundness: hasRoundness true, roundness null', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        roundness: const Roundness.adaptive(value: 5),
      );
      final e2 = EllipseElement(
        id: const ElementId('e1'),
        x: 0, y: 0, width: 100, height: 100,
        // no roundness
      );

      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.hasRoundness, isTrue);
      expect(style.roundness, isNull);
    });
  });

  group('PropertyPanelState.applyStyle', () {
    test('produces UpdateElementResult with changed strokeColor', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#000000',
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(strokeColor: '#ff0000'),
      );

      expect(result, isA<UpdateElementResult>());
      final updated = (result as UpdateElementResult).element;
      expect(updated.strokeColor, '#ff0000');
    });

    test('produces UpdateElementResult with changed fillStyle', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        fillStyle: FillStyle.solid,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(fillStyle: FillStyle.crossHatch),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.fillStyle, FillStyle.crossHatch);
    });

    test('produces UpdateElementResult with changed strokeWidth', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeWidth: 2.0,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(strokeWidth: 6.0),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.strokeWidth, 6.0);
    });

    test('produces UpdateElementResult with changed strokeStyle', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeStyle: StrokeStyle.solid,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(strokeStyle: StrokeStyle.dotted),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.strokeStyle, StrokeStyle.dotted);
    });

    test('produces UpdateElementResult with changed roughness', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        roughness: 1.0,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(roughness: 2.5),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.roughness, 2.5);
    });

    test('produces UpdateElementResult with changed opacity', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        opacity: 1.0,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(opacity: 0.5),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.opacity, 0.5);
    });

    test('produces UpdateElementResult for TextElement fontSize', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        fontSize: 20.0,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(hasText: true, fontSize: 28.0),
      );

      final updated = (result as UpdateElementResult).element as TextElement;
      expect(updated.fontSize, 28.0);
      expect(updated.text, 'Hello'); // text preserved
    });

    test('produces CompoundResult for multiple elements', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 50, y: 50, width: 200, height: 200,
      );

      final result = PropertyPanelState.applyStyle(
        [e1, e2],
        const ElementStyle(strokeColor: '#ff0000'),
      );

      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;
      expect(compound.results, hasLength(2));
      expect(
        (compound.results[0] as UpdateElementResult).element.strokeColor,
        '#ff0000',
      );
      expect(
        (compound.results[1] as UpdateElementResult).element.strokeColor,
        '#ff0000',
      );
    });

    test('skips null values (only applies non-null changes)', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#000000',
        backgroundColor: '#ffffff',
        strokeWidth: 2.0,
      );

      // Only change strokeColor, leave others as-is
      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(strokeColor: '#ff0000'),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.strokeColor, '#ff0000');
      expect(updated.backgroundColor, '#ffffff'); // unchanged
      expect(updated.strokeWidth, 2.0); // unchanged
    });

    test('applyStyle on text element preserves text content', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Important text',
        fontSize: 20.0,
        fontFamily: 'Excalifont',
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(strokeColor: '#ff0000'),
      );

      final updated = (result as UpdateElementResult).element as TextElement;
      expect(updated.text, 'Important text');
      expect(updated.fontSize, 20.0);
      expect(updated.fontFamily, 'Excalifont');
      expect(updated.strokeColor, '#ff0000');
    });

    test('roundness on rectangle element', () {
      final element = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(
          roundness: Roundness.adaptive(value: 10),
          hasRoundness: true,
        ),
      );

      final updated = (result as UpdateElementResult).element;
      expect(updated.roundness, const Roundness.adaptive(value: 10));
    });

    test('text fontFamily and textAlign via copyWithText', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        fontFamily: 'Excalifont',
        textAlign: TextAlign.left,
      );

      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(
          hasText: true,
          fontFamily: 'Cascadia',
          textAlign: TextAlign.center,
        ),
      );

      final updated = (result as UpdateElementResult).element as TextElement;
      expect(updated.fontFamily, 'Cascadia');
      expect(updated.textAlign, TextAlign.center);
    });

    test('mixed elements: text and non-text', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        strokeColor: '#000000',
      );
      final text = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        strokeColor: '#000000',
        fontSize: 20.0,
      );

      final result = PropertyPanelState.applyStyle(
        [rect, text],
        const ElementStyle(
          strokeColor: '#ff0000',
          hasText: true,
          fontSize: 28.0,
        ),
      );

      final compound = result as CompoundResult;
      expect(compound.results, hasLength(2));

      // Rectangle: strokeColor changed, no fontSize
      final updatedRect = (compound.results[0] as UpdateElementResult).element;
      expect(updatedRect.strokeColor, '#ff0000');

      // TextElement: strokeColor changed + fontSize changed
      final updatedText =
          (compound.results[1] as UpdateElementResult).element as TextElement;
      expect(updatedText.strokeColor, '#ff0000');
      expect(updatedText.fontSize, 28.0);
      expect(updatedText.text, 'Hello');
    });
  });

  group('PropertyPanelState elbowed arrow', () {
    final elbowArrow = ArrowElement(
      id: const ElementId('ea1'),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: const [Point(0, 0), Point(0, 100), Point(100, 100)],
      endArrowhead: Arrowhead.arrow,
      arrowType: ArrowType.sharpElbow,
    );

    final regularArrow = ArrowElement(
      id: const ElementId('ra1'),
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      points: const [Point(0, 0), Point(100, 100)],
      endArrowhead: Arrowhead.arrow,
    );

    test('fromElements extracts arrowType=sharpElbow', () {
      final style = PropertyPanelState.fromElements([elbowArrow]);
      expect(style.hasArrows, isTrue);
      expect(style.arrowType, ArrowType.sharpElbow);
    });

    test('fromElements extracts arrowType=sharp', () {
      final style = PropertyPanelState.fromElements([regularArrow]);
      expect(style.hasArrows, isTrue);
      expect(style.arrowType, ArrowType.sharp);
    });

    test('fromElements returns null for mixed arrowType', () {
      final style =
          PropertyPanelState.fromElements([elbowArrow, regularArrow]);
      expect(style.hasArrows, isTrue);
      expect(style.arrowType, isNull);
    });

    test('fromElements returns hasArrows false for non-arrows', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      final style = PropertyPanelState.fromElements([rect]);
      expect(style.hasArrows, isFalse);
      expect(style.arrowType, isNull);
    });

    test('applyStyle regular to elbowed re-routes points', () {
      final result = PropertyPanelState.applyStyle(
        [regularArrow],
        const ElementStyle(hasArrows: true, arrowType: ArrowType.sharpElbow),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.elbowed, isTrue);
      // Should have more than 2 points (routed path)
      expect(updated.points.length, greaterThan(2));
      // First point and approximate last point preserved
      expect(updated.points.first, const Point(0, 0));
      expect(updated.angle, 0);
    });

    test('applyStyle elbowed to regular simplifies to 2 points', () {
      final result = PropertyPanelState.applyStyle(
        [elbowArrow],
        const ElementStyle(hasArrows: true, arrowType: ArrowType.sharp),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.elbowed, isFalse);
      expect(updated.points.length, 2);
      expect(updated.points.first, elbowArrow.points.first);
      expect(updated.points.last, elbowArrow.points.last);
    });

    test('applyStyle elbowed on non-arrow is ignored', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      final result = PropertyPanelState.applyStyle(
        [rect],
        const ElementStyle(hasArrows: true, arrowType: ArrowType.sharpElbow),
      );
      final updated = (result as UpdateElementResult).element;
      // Should still be a rectangle, unchanged by elbowed
      expect(updated, isA<RectangleElement>());
    });

    test('applyStyle elbowed with undo-compatible result', () {
      // Verify result is an UpdateElementResult (can be pushed to undo stack)
      final result = PropertyPanelState.applyStyle(
        [regularArrow],
        const ElementStyle(hasArrows: true, arrowType: ArrowType.sharpElbow),
      );
      expect(result, isA<UpdateElementResult>());
    });
  });

  group('PropertyPanelState locked property', () {
    test('fromElements with all locked returns locked == true', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        locked: true,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 50, y: 50, width: 100, height: 100,
        locked: true,
      );
      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.locked, isTrue);
    });

    test('fromElements with all unlocked returns locked == false', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 50, y: 50, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.locked, isFalse);
    });

    test('fromElements with mixed returns locked == null', () {
      final e1 = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        locked: true,
      );
      final e2 = RectangleElement(
        id: const ElementId('r2'),
        x: 50, y: 50, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements([e1, e2]);
      expect(style.locked, isNull);
    });

    test('fromElements empty returns locked == null', () {
      final style = PropertyPanelState.fromElements([]);
      expect(style.locked, isNull);
    });

    test('applyStyle with locked: true updates elements', () {
      final e = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final result = PropertyPanelState.applyStyle(
        [e],
        const ElementStyle(locked: true),
      );
      final updated = (result as UpdateElementResult).element;
      expect(updated.locked, isTrue);
    });

    test('applyStyle with locked: false updates elements', () {
      final e = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        locked: true,
      );
      final result = PropertyPanelState.applyStyle(
        [e],
        const ElementStyle(locked: false),
      );
      final updated = (result as UpdateElementResult).element;
      expect(updated.locked, isFalse);
    });
  });

  group('PropertyPanelState.fromElements with bound text', () {
    test('shape with bound text surfaces text properties', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        boundElements: const [BoundElement(id: 'bt1', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('bt1'),
        x: 0, y: 0, width: 80, height: 20,
        text: 'Label',
        fontSize: 24.0,
        fontFamily: 'Nunito',
        textAlign: TextAlign.center,
        verticalAlign: VerticalAlign.top,
        containerId: 'r1',
      );
      final style = PropertyPanelState.fromElements(
        [rect],
        boundTextElements: [boundText],
      );
      expect(style.hasText, isTrue);
      expect(style.hasShapeBoundText, isTrue);
      expect(style.hasArrowBoundText, isFalse);
      expect(style.fontSize, 24.0);
      expect(style.fontFamily, 'Nunito');
      expect(style.textAlign, TextAlign.center);
      expect(style.verticalAlign, VerticalAlign.top);
    });

    test('arrow with bound text surfaces only fontSize', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 0,
        points: const [Point(0, 0), Point(100, 0)],
        endArrowhead: Arrowhead.arrow,
        boundElements: const [BoundElement(id: 'bt2', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('bt2'),
        x: 0, y: 0, width: 50, height: 20,
        text: 'Label',
        fontSize: 16.0,
        fontFamily: 'Excalifont',
        containerId: 'a1',
      );
      final style = PropertyPanelState.fromElements(
        [arrow],
        boundTextElements: [boundText],
      );
      expect(style.hasText, isTrue);
      expect(style.hasArrowBoundText, isTrue);
      expect(style.hasShapeBoundText, isFalse);
      expect(style.fontSize, 16.0);
    });

    test('mixed shape bound text and direct text merges values', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        boundElements: const [BoundElement(id: 'bt1', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('bt1'),
        x: 0, y: 0, width: 80, height: 20,
        text: 'Label',
        fontSize: 24.0,
        containerId: 'r1',
      );
      final directText = TextElement(
        id: const ElementId('t1'),
        x: 50, y: 50, width: 100, height: 20,
        text: 'Standalone',
        fontSize: 24.0,
      );
      final style = PropertyPanelState.fromElements(
        [rect, directText],
        boundTextElements: [boundText],
      );
      expect(style.hasText, isTrue);
      expect(style.fontSize, 24.0); // same → not null
    });

    test('mixed bound text and direct text with different sizes → null', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
        boundElements: const [BoundElement(id: 'bt1', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('bt1'),
        x: 0, y: 0, width: 80, height: 20,
        text: 'Label',
        fontSize: 24.0,
        containerId: 'r1',
      );
      final directText = TextElement(
        id: const ElementId('t1'),
        x: 50, y: 50, width: 100, height: 20,
        text: 'Standalone',
        fontSize: 16.0,
      );
      final style = PropertyPanelState.fromElements(
        [rect, directText],
        boundTextElements: [boundText],
      );
      expect(style.hasText, isTrue);
      expect(style.fontSize, isNull); // different → mixed
    });

    test('no bound text and no direct text → hasText false', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements(
        [rect],
        boundTextElements: [],
      );
      expect(style.hasText, isFalse);
    });

    test('verticalAlign from direct TextElement', () {
      final textEl = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        verticalAlign: VerticalAlign.bottom,
      );
      final style = PropertyPanelState.fromElements([textEl]);
      expect(style.verticalAlign, VerticalAlign.bottom);
    });

    test('verticalAlign null when mixed', () {
      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
        verticalAlign: VerticalAlign.top,
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'World',
        verticalAlign: VerticalAlign.bottom,
      );
      final style = PropertyPanelState.fromElements([t1, t2]);
      expect(style.verticalAlign, isNull);
    });
  });

  group('PropertyPanelState.applyStyle verticalAlign', () {
    test('applies verticalAlign to TextElement', () {
      final element = TextElement(
        id: const ElementId('t1'),
        x: 0, y: 0, width: 100, height: 24,
        text: 'Hello',
      );
      final result = PropertyPanelState.applyStyle(
        [element],
        const ElementStyle(hasText: true, verticalAlign: VerticalAlign.top),
      );
      final updated = (result as UpdateElementResult).element as TextElement;
      expect(updated.verticalAlign, VerticalAlign.top);
    });
  });

  group('PropertyPanelState arrowhead', () {
    final lineWithArrows = LineElement(
      id: const ElementId('l1'),
      x: 0, y: 0, width: 100, height: 0,
      points: const [Point(0, 0), Point(100, 0)],
      startArrowhead: Arrowhead.bar,
      endArrowhead: Arrowhead.triangle,
    );

    final lineNoArrows = LineElement(
      id: const ElementId('l2'),
      x: 0, y: 0, width: 100, height: 0,
      points: const [Point(0, 0), Point(100, 0)],
    );

    final arrow = ArrowElement(
      id: const ElementId('a1'),
      x: 0, y: 0, width: 100, height: 0,
      points: const [Point(0, 0), Point(100, 0)],
      endArrowhead: Arrowhead.arrow,
    );

    test('fromElements single line with arrowheads', () {
      final style = PropertyPanelState.fromElements([lineWithArrows]);
      expect(style.hasLines, isTrue);
      expect(style.startArrowhead, Arrowhead.bar);
      expect(style.startArrowheadNone, isFalse);
      expect(style.endArrowhead, Arrowhead.triangle);
      expect(style.endArrowheadNone, isFalse);
    });

    test('fromElements single line without arrowheads', () {
      final style = PropertyPanelState.fromElements([lineNoArrows]);
      expect(style.hasLines, isTrue);
      expect(style.startArrowhead, isNull);
      expect(style.startArrowheadNone, isTrue);
      expect(style.endArrowhead, isNull);
      expect(style.endArrowheadNone, isTrue);
    });

    test('fromElements mixed arrowheads returns null', () {
      final style =
          PropertyPanelState.fromElements([lineWithArrows, lineNoArrows]);
      expect(style.hasLines, isTrue);
      expect(style.startArrowhead, isNull);
      expect(style.startArrowheadNone, isFalse);
      expect(style.endArrowhead, isNull);
      expect(style.endArrowheadNone, isFalse);
    });

    test('fromElements matching arrowheads', () {
      final l2 = LineElement(
        id: const ElementId('l3'),
        x: 0, y: 0, width: 50, height: 0,
        points: const [Point(0, 0), Point(50, 0)],
        startArrowhead: Arrowhead.bar,
        endArrowhead: Arrowhead.triangle,
      );
      final style = PropertyPanelState.fromElements([lineWithArrows, l2]);
      expect(style.startArrowhead, Arrowhead.bar);
      expect(style.endArrowhead, Arrowhead.triangle);
    });

    test('fromElements arrow element contributes to hasLines', () {
      final style = PropertyPanelState.fromElements([arrow]);
      expect(style.hasLines, isTrue);
      expect(style.endArrowhead, Arrowhead.arrow);
      expect(style.startArrowhead, isNull);
      expect(style.startArrowheadNone, isTrue);
    });

    test('fromElements non-line returns hasLines false', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements([rect]);
      expect(style.hasLines, isFalse);
    });

    test('applyStyle sets start arrowhead on line', () {
      final result = PropertyPanelState.applyStyle(
        [lineNoArrows],
        const ElementStyle(
          hasLines: true,
          startArrowhead: Arrowhead.dot,
        ),
      );
      final updated = (result as UpdateElementResult).element as LineElement;
      expect(updated.startArrowhead, Arrowhead.dot);
      expect(updated.endArrowhead, isNull); // unchanged
    });

    test('applyStyle clears start arrowhead', () {
      final result = PropertyPanelState.applyStyle(
        [lineWithArrows],
        const ElementStyle(hasLines: true, startArrowheadNone: true),
      );
      final updated = (result as UpdateElementResult).element as LineElement;
      expect(updated.startArrowhead, isNull);
      expect(updated.endArrowhead, Arrowhead.triangle); // unchanged
    });

    test('applyStyle sets end arrowhead on arrow', () {
      final result = PropertyPanelState.applyStyle(
        [arrow],
        const ElementStyle(
          hasLines: true,
          endArrowhead: Arrowhead.triangle,
        ),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.endArrowhead, Arrowhead.triangle);
    });

    test('fromElements extracts roundness from arrows but hasRoundness false', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        roundness: const Roundness.proportional(value: 32),
      );
      final style = PropertyPanelState.fromElements([arrow]);
      expect(style.roundness, const Roundness.proportional(value: 32));
      // hasRoundness only true for rectangles and diamonds (corner rounding)
      expect(style.hasRoundness, isFalse);
    });

    test('fromElements hasRoundness false when no roundness', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
      );
      final style = PropertyPanelState.fromElements([arrow]);
      expect(style.roundness, isNull);
      expect(style.hasRoundness, isFalse);
    });

    test('applyStyle sets roundness for curved arrow', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
      );
      final result = PropertyPanelState.applyStyle(
        [arrow],
        const ElementStyle(
          roundness: Roundness.proportional(value: 32),
          hasRoundness: true,
        ),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.roundness, const Roundness.proportional(value: 32));
    });

    test('applyStyle clears roundness for sharp arrow', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 0,
        points: [const Point(0, 0), const Point(100, 0)],
        roundness: const Roundness.proportional(value: 32),
      );
      final result = PropertyPanelState.applyStyle(
        [arrow],
        const ElementStyle(hasRoundness: true),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.roundness, isNull);
    });

    test('applyStyle elbowed to curved simplifies points and sets roundness', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 50,
        points: [
          const Point(0, 0),
          const Point(50, 0),
          const Point(50, 50),
          const Point(100, 50),
        ],
        arrowType: ArrowType.sharpElbow,
      );
      final result = PropertyPanelState.applyStyle(
        [arrow],
        const ElementStyle(
          arrowType: ArrowType.sharp,
          roundness: Roundness.proportional(value: 32),
          hasRoundness: true,
        ),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      expect(updated.elbowed, isFalse);
      expect(updated.points.length, 2); // simplified to first and last
      expect(updated.roundness, const Roundness.proportional(value: 32));
    });

    test('applyStyle arrowhead ignored on non-line', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final result = PropertyPanelState.applyStyle(
        [rect],
        const ElementStyle(
          hasLines: true,
          startArrowhead: Arrowhead.arrow,
        ),
      );
      final updated = (result as UpdateElementResult).element;
      expect(updated, isA<RectangleElement>());
    });
  });

  group('PropertyPanelState canBreakPolygon', () {
    test('canBreakPolygon true for closed line with 3+ points', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
      );
      final style = PropertyPanelState.fromElements([line]);
      expect(style.canBreakPolygon, isTrue);
    });

    test('canBreakPolygon true for closed line with exactly 3 points', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
        closed: true,
      );
      final style = PropertyPanelState.fromElements([line]);
      expect(style.canBreakPolygon, isTrue);
    });

    test('canBreakPolygon false for open line', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 0,
        points: const [Point(0, 0), Point(100, 0)],
      );
      final style = PropertyPanelState.fromElements([line]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('canBreakPolygon false for arrow elements even when closed', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
        endArrowhead: Arrowhead.arrow,
      );
      final style = PropertyPanelState.fromElements([arrow]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('canBreakPolygon false for rectangles', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements([rect]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('canBreakPolygon false for mix of closed and open lines', () {
      final closed = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
      );
      final open = LineElement(
        id: const ElementId('l2'),
        x: 0, y: 0, width: 100, height: 0,
        points: const [Point(0, 0), Point(100, 0)],
      );
      final style = PropertyPanelState.fromElements([closed, open]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('canBreakPolygon false for mix of line and non-line elements', () {
      final closedLine = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
      );
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final style = PropertyPanelState.fromElements([closedLine, rect]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('canBreakPolygon true for multiple closed polygons', () {
      final l1 = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
      );
      final l2 = LineElement(
        id: const ElementId('l2'),
        x: 200, y: 200, width: 50, height: 50,
        points: const [
          Point(0, 0),
          Point(50, 0),
          Point(50, 50),
        ],
        closed: true,
      );
      final style = PropertyPanelState.fromElements([l1, l2]);
      expect(style.canBreakPolygon, isTrue);
    });

    test('canBreakPolygon false for closed line with fewer than 3 points', () {
      final line = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 0,
        points: const [Point(0, 0), Point(100, 0)],
        closed: true,
      );
      final style = PropertyPanelState.fromElements([line]);
      expect(style.canBreakPolygon, isFalse);
    });

    test('applyStyle with canBreakPolygon keeps all points and opens line',
        () {
      final polygon = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0), // closing point kept as-is
        ],
        closed: true,
        backgroundColor: '#ff0000',
      );
      final result = PropertyPanelState.applyStyle(
        [polygon],
        const ElementStyle(canBreakPolygon: true),
      );
      final updated = (result as UpdateElementResult).element as LineElement;
      expect(updated.closed, isFalse);
      expect(updated.points.length, 4); // all points preserved
      expect(updated.points[0], const Point(0, 0));
      expect(updated.points[1], const Point(100, 0));
      expect(updated.points[2], const Point(100, 100));
      expect(updated.points[3], const Point(0, 0));
      expect(updated.backgroundColor, 'transparent');
    });

    test('applyStyle with canBreakPolygon on non-duplicate closing point keeps all points',
        () {
      final polygon = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(50, 100),
        ],
        closed: true,
        backgroundColor: '#00ff00',
      );
      final result = PropertyPanelState.applyStyle(
        [polygon],
        const ElementStyle(canBreakPolygon: true),
      );
      final updated = (result as UpdateElementResult).element as LineElement;
      expect(updated.closed, isFalse);
      expect(updated.points.length, 3); // no closing duplicate to remove
      expect(updated.backgroundColor, 'transparent');
    });

    test('applyStyle with canBreakPolygon on multiple polygons', () {
      final p1 = LineElement(
        id: const ElementId('l1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
        backgroundColor: '#ff0000',
      );
      final p2 = LineElement(
        id: const ElementId('l2'),
        x: 200, y: 200, width: 50, height: 50,
        points: const [
          Point(0, 0),
          Point(50, 0),
          Point(50, 50),
          Point(0, 0),
        ],
        closed: true,
        backgroundColor: '#00ff00',
      );
      final result = PropertyPanelState.applyStyle(
        [p1, p2],
        const ElementStyle(canBreakPolygon: true),
      );
      final compound = result as CompoundResult;
      expect(compound.results.length, 2);

      final u1 = (compound.results[0] as UpdateElementResult).element as LineElement;
      expect(u1.closed, isFalse);
      expect(u1.points.length, 4); // all points preserved
      expect(u1.backgroundColor, 'transparent');

      final u2 = (compound.results[1] as UpdateElementResult).element as LineElement;
      expect(u2.closed, isFalse);
      expect(u2.points.length, 4); // all points preserved
      expect(u2.backgroundColor, 'transparent');
    });

    test('applyStyle with canBreakPolygon skips non-line elements', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 100,
      );
      final result = PropertyPanelState.applyStyle(
        [rect],
        const ElementStyle(canBreakPolygon: true),
      );
      final updated = (result as UpdateElementResult).element;
      expect(updated, isA<RectangleElement>());
    });

    test('applyStyle with canBreakPolygon skips arrow elements', () {
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 0, y: 0, width: 100, height: 100,
        points: const [
          Point(0, 0),
          Point(100, 0),
          Point(100, 100),
          Point(0, 0),
        ],
        closed: true,
        endArrowhead: Arrowhead.arrow,
      );
      final result = PropertyPanelState.applyStyle(
        [arrow],
        const ElementStyle(canBreakPolygon: true),
      );
      final updated = (result as UpdateElementResult).element as ArrowElement;
      // Arrow should not be broken
      expect(updated.closed, isTrue);
    });
  });
}
