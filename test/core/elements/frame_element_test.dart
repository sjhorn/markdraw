import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/frame_element.dart';

void main() {
  group('FrameElement', () {
    test('constructor sets type to frame', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 20,
        width: 400,
        height: 300,
        label: 'Section A',
      );
      expect(frame.type, 'frame');
    });

    test('constructor sets all fields', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 20,
        width: 400,
        height: 300,
        label: 'Section A',
        seed: 42,
      );
      expect(frame.id, const ElementId('f1'));
      expect(frame.x, 10);
      expect(frame.y, 20);
      expect(frame.width, 400);
      expect(frame.height, 300);
      expect(frame.label, 'Section A');
      expect(frame.seed, 42);
    });

    test('default label is Frame', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      expect(frame.label, 'Frame');
    });

    test('copyWith preserves label when not explicitly changed', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 20,
        width: 400,
        height: 300,
        label: 'Section A',
      );
      final moved = frame.copyWith(x: 50, y: 60);
      expect(moved.x, 50);
      expect(moved.y, 60);
      expect(moved.label, 'Section A');
      expect(moved.type, 'frame');
      expect(moved, isA<FrameElement>());
    });

    test('copyWith returns FrameElement type', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        label: 'Test',
      );
      final copy = frame.copyWith(width: 200);
      expect(copy, isA<FrameElement>());
      expect((copy as FrameElement).label, 'Test');
    });

    test('copyWithLabel changes only the label', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 20,
        width: 400,
        height: 300,
        label: 'Old Label',
        seed: 42,
      );
      final renamed = frame.copyWithLabel('New Label');
      expect(renamed.label, 'New Label');
      expect(renamed.x, 10);
      expect(renamed.y, 20);
      expect(renamed.width, 400);
      expect(renamed.height, 300);
      expect(renamed.id, const ElementId('f1'));
      expect(renamed.seed, 42);
      expect(renamed.type, 'frame');
    });

    test('identity equality by id', () {
      final a = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      final b = FrameElement(
        id: const ElementId('f1'),
        x: 999,
        y: 999,
        width: 1,
        height: 1,
      );
      expect(a, equals(b));
    });
  });
}
