import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/frame_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/export/export_bounds.dart';
import 'package:markdraw/src/rendering/export/svg_element_renderer.dart';
import 'package:markdraw/src/rendering/export/svg_exporter.dart';

void main() {
  group('SvgElementRenderer — frame', () {
    test('renders frame as rect with stroke and label', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        label: 'Section A',
        seed: 42,
      );
      final svg = SvgElementRenderer.render(frame);
      expect(svg, contains('<rect'));
      expect(svg, contains('x="100"'));
      expect(svg, contains('y="200"'));
      expect(svg, contains('width="400"'));
      expect(svg, contains('height="300"'));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('<text'));
      expect(svg, contains('Section A'));
    });

    test('renders frame without label when label is empty', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        label: '',
        seed: 1,
      );
      final svg = SvgElementRenderer.render(frame);
      expect(svg, contains('<rect'));
      expect(svg, isNot(contains('<text')));
    });
  });

  group('SvgExporter — frame clip paths', () {
    test('emits clipPath defs for frame elements', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 400,
        height: 300,
        label: 'Frame',
        seed: 1,
      );
      final child = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        frameId: 'f1',
        seed: 2,
      );
      final scene = Scene().addElement(frame).addElement(child);
      final svg = SvgExporter.export(scene, embedMarkdraw: false);
      expect(svg, contains('<clipPath id="clip-f1"'));
      expect(svg, contains('clip-path="url(#clip-f1)"'));
    });

    test('children without frameId are not clipped', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 400,
        height: 300,
        label: 'Frame',
        seed: 1,
      );
      final unrelated = RectangleElement(
        id: const ElementId('r2'),
        x: 500,
        y: 500,
        width: 50,
        height: 50,
        seed: 3,
      );
      final scene = Scene().addElement(frame).addElement(unrelated);
      final svg = SvgExporter.export(scene, embedMarkdraw: false);
      // Only one clipPath for the frame, unrelated rect not in clip group
      expect(svg, contains('<clipPath id="clip-f1"'));
      // Count clip-path references — should not be on unrelated element
      final clipRefs = RegExp(r'clip-path=').allMatches(svg);
      expect(clipRefs, isEmpty);
    });
  });

  group('ExportBounds — frames', () {
    test('includes frame children when frame is in selection', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 400,
        height: 300,
        label: 'Frame',
        seed: 1,
      );
      final child = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 380,
        height: 280,
        frameId: 'f1',
        seed: 2,
      );
      final scene = Scene().addElement(frame).addElement(child);
      // Select only the frame — child should be included in bounds
      final bounds = ExportBounds.compute(
        scene,
        selectedIds: {const ElementId('f1')},
        padding: 0,
      );
      expect(bounds, isNotNull);
      // Bounds should encompass both frame and child
      expect(bounds!.left, 0);
      expect(bounds.top, 0);
    });

    test('includes frame when child is in selection', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 400,
        height: 300,
        label: 'Frame',
        seed: 1,
      );
      final child = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        frameId: 'f1',
        seed: 2,
      );
      final scene = Scene().addElement(frame).addElement(child);
      // Select only the child — frame should be included in bounds
      final bounds = ExportBounds.compute(
        scene,
        selectedIds: {const ElementId('r1')},
        padding: 0,
      );
      expect(bounds, isNotNull);
      // Bounds should encompass the frame (larger)
      expect(bounds!.size.width, 400);
      expect(bounds.size.height, 300);
    });
  });
}
