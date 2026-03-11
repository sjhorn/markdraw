import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

void main() {
  group('updateFindQuery', () {
    test('matches TextElement.text case-insensitively', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Hello World',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 200,
        y: 0,
        width: 100,
        height: 20,
        text: 'Goodbye',
      );
      controller.loadScene(Scene().addElement(t1).addElement(t2));

      controller.openFind();
      controller.updateFindQuery('hello');

      expect(controller.findResults, hasLength(1));
      expect(controller.findResults.first, const ElementId('t1'));
      expect(controller.findCurrentIndex, 0);
    });

    test('matches FrameElement.label case-insensitively', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 200,
        height: 200,
        label: 'Login Screen',
      );
      controller.loadScene(Scene().addElement(frame));

      controller.openFind();
      controller.updateFindQuery('login');

      expect(controller.findResults, hasLength(1));
      expect(controller.findResults.first, const ElementId('f1'));
    });

    test('excludes non-text/non-frame elements', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
      );
      controller.loadScene(Scene().addElement(rect));

      controller.openFind();
      controller.updateFindQuery('rect');

      expect(controller.findResults, isEmpty);
      expect(controller.findCurrentIndex, -1);
    });

    test('handles empty query', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Hello',
      );
      controller.loadScene(Scene().addElement(t1));

      controller.openFind();
      controller.updateFindQuery('Hello');
      expect(controller.findResults, hasLength(1));

      controller.updateFindQuery('');
      expect(controller.findResults, isEmpty);
      expect(controller.findCurrentIndex, -1);
    });

    test('bound text match returns parent container ID', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0,
        y: 0,
        width: 100,
        height: 50,
        boundElements: [const BoundElement(id: 'bt1', type: 'text')],
      );
      final boundText = TextElement(
        id: const ElementId('bt1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Bound Label',
        containerId: 'r1',
      );
      controller.loadScene(Scene().addElement(rect).addElement(boundText));

      controller.openFind();
      controller.updateFindQuery('bound');

      expect(controller.findResults, hasLength(1));
      expect(controller.findResults.first, const ElementId('r1'));
    });

    test('selects first match automatically', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'alpha',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 200,
        y: 0,
        width: 100,
        height: 20,
        text: 'alpha beta',
      );
      controller.loadScene(Scene().addElement(t1).addElement(t2));

      controller.openFind();
      controller.updateFindQuery('alpha');

      expect(controller.findResults, hasLength(2));
      expect(controller.editorState.selectedIds, {const ElementId('t1')});
    });
  });

  group('findNext / findPrevious', () {
    test('findNext advances and wraps around', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'match',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 200,
        y: 0,
        width: 100,
        height: 20,
        text: 'match again',
      );
      final t3 = TextElement(
        id: const ElementId('t3'),
        x: 400,
        y: 0,
        width: 100,
        height: 20,
        text: 'match too',
      );
      controller.loadScene(
          Scene().addElement(t1).addElement(t2).addElement(t3));

      controller.openFind();
      controller.updateFindQuery('match');
      expect(controller.findCurrentIndex, 0);

      const canvasSize = Size(800, 600);

      controller.findNext(canvasSize);
      expect(controller.findCurrentIndex, 1);
      expect(controller.editorState.selectedIds, {const ElementId('t2')});

      controller.findNext(canvasSize);
      expect(controller.findCurrentIndex, 2);
      expect(controller.editorState.selectedIds, {const ElementId('t3')});

      // Wraps around
      controller.findNext(canvasSize);
      expect(controller.findCurrentIndex, 0);
      expect(controller.editorState.selectedIds, {const ElementId('t1')});
    });

    test('findPrevious decrements and wraps around', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'match',
      );
      final t2 = TextElement(
        id: const ElementId('t2'),
        x: 200,
        y: 0,
        width: 100,
        height: 20,
        text: 'match again',
      );
      controller.loadScene(Scene().addElement(t1).addElement(t2));

      controller.openFind();
      controller.updateFindQuery('match');
      expect(controller.findCurrentIndex, 0);

      const canvasSize = Size(800, 600);

      // Previous from 0 wraps to last
      controller.findPrevious(canvasSize);
      expect(controller.findCurrentIndex, 1);
      expect(controller.editorState.selectedIds, {const ElementId('t2')});

      controller.findPrevious(canvasSize);
      expect(controller.findCurrentIndex, 0);
      expect(controller.editorState.selectedIds, {const ElementId('t1')});
    });

    test('does nothing when no results', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      controller.openFind();
      controller.updateFindQuery('nothing');

      const canvasSize = Size(800, 600);
      controller.findNext(canvasSize);
      expect(controller.findCurrentIndex, -1);

      controller.findPrevious(canvasSize);
      expect(controller.findCurrentIndex, -1);
    });
  });

  group('openFind / closeFind', () {
    test('openFind sets isFindOpen', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      expect(controller.isFindOpen, isFalse);
      controller.openFind();
      expect(controller.isFindOpen, isTrue);
    });

    test('closeFind clears all find state', () {
      final controller = MarkdrawController();
      addTearDown(controller.dispose);

      final t1 = TextElement(
        id: const ElementId('t1'),
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        text: 'Hello',
      );
      controller.loadScene(Scene().addElement(t1));

      controller.openFind();
      controller.updateFindQuery('Hello');
      expect(controller.findResults, isNotEmpty);
      expect(controller.findCurrentIndex, 0);

      controller.closeFind();
      expect(controller.isFindOpen, isFalse);
      expect(controller.findQuery, isEmpty);
      expect(controller.findResults, isEmpty);
      expect(controller.findCurrentIndex, -1);
    });
  });
}
