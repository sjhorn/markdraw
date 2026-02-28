import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  SelectTool tool = SelectTool();

  ToolContext makeCtx(Scene scene, Set<ElementId> selectedIds) => ToolContext(
        scene: scene,
        viewport: const ViewportState(),
        selectedIds: selectedIds,
        clipboard: const [],
      );

  RectangleElement makeRect(String id, {String? index, bool locked = false}) =>
      RectangleElement(
        id: ElementId(id),
        x: 0, y: 0, width: 100, height: 100,
        index: index,
        locked: locked,
      );

  setUp(() {
    tool = SelectTool();
  });

  group('SelectTool layer shortcuts', () {
    test('Ctrl+] brings forward', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final ctx = makeCtx(scene, {const ElementId('a')});
      final result = tool.onKeyEvent(']', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;
      expect(compound.results, hasLength(2));
    });

    test('Ctrl+Shift+] brings to front', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final ctx = makeCtx(scene, {const ElementId('a')});
      final result =
          tool.onKeyEvent(']', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;
      final updated = (compound.results[0] as UpdateElementResult).element;
      expect(updated.index!.compareTo('C'), greaterThan(0));
    });

    test('Ctrl+[ sends backward', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final ctx = makeCtx(scene, {const ElementId('c')});
      final result = tool.onKeyEvent('[', ctrl: true, context: ctx);
      expect(result, isA<CompoundResult>());
    });

    test('Ctrl+Shift+[ sends to back', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'))
          .addElement(makeRect('c', index: 'C'));
      final ctx = makeCtx(scene, {const ElementId('c')});
      final result =
          tool.onKeyEvent('[', ctrl: true, shift: true, context: ctx);
      expect(result, isA<CompoundResult>());
      final compound = result as CompoundResult;
      final updated = (compound.results[0] as UpdateElementResult).element;
      expect(updated.index!.compareTo('A'), lessThan(0));
    });

    test('returns null on empty selection', () {
      final scene = Scene().addElement(makeRect('a', index: 'A'));
      final ctx = makeCtx(scene, {});
      expect(tool.onKeyEvent(']', ctrl: true, context: ctx), isNull);
      expect(tool.onKeyEvent('[', ctrl: true, context: ctx), isNull);
    });

    test('returns null for locked elements', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A', locked: true))
          .addElement(makeRect('b', index: 'B'));
      final ctx = makeCtx(scene, {const ElementId('a')});
      expect(tool.onKeyEvent(']', ctrl: true, context: ctx), isNull);
      expect(tool.onKeyEvent('[', ctrl: true, context: ctx), isNull);
    });

    test('returns null when already at top (bring forward)', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'));
      final ctx = makeCtx(scene, {const ElementId('b')});
      expect(tool.onKeyEvent(']', ctrl: true, context: ctx), isNull);
    });

    test('returns null when already at bottom (send backward)', () {
      final scene = Scene()
          .addElement(makeRect('a', index: 'A'))
          .addElement(makeRect('b', index: 'B'));
      final ctx = makeCtx(scene, {const ElementId('a')});
      expect(tool.onKeyEvent('[', ctrl: true, context: ctx), isNull);
    });
  });
}
