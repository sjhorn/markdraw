import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';
import 'package:markdraw/src/editor/tools/frame_tool.dart';

void main() {
  group('frame opacity propagation', () {
    late MarkdrawController controller;

    setUp(() {
      controller = MarkdrawController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('adjusting frame opacity updates children opacity', () {
      // Create a rectangle
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 100,
        height: 80,
      );

      // Create a frame that contains the rectangle
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 10,
        width: 200,
        height: 200,
        label: 'Frame 1',
      );

      // Build the scene: add rect first, then frame
      var scene = Scene();
      scene = scene.addElement(rect);
      scene = scene.addElement(frame);

      // Assign the rect to the frame
      final rectInFrame = scene.getElementById(rect.id)!;
      scene = scene.updateElement(rectInFrame.copyWith(frameId: frame.id.value));

      controller.loadScene(scene);

      // Verify rect is a child of frame
      final children = FrameUtils.findFrameChildren(
        controller.editorState.scene,
        frame.id,
      );
      expect(children, hasLength(1));
      expect(children.first.id, rect.id);

      // Both should start with default opacity (1.0)
      expect(
        controller.editorState.scene.getElementById(rect.id)!.opacity,
        1.0,
      );
      expect(
        controller.editorState.scene.getElementById(frame.id)!.opacity,
        1.0,
      );

      // Select the frame
      controller.applyResult(SetSelectionResult({frame.id}));
      expect(controller.editorState.selectedIds, {frame.id});

      // Adjust opacity via style change (simulates property panel slider)
      controller.applyStyleChange(const ElementStyle(opacity: 0.5));

      // Frame should be 0.5
      final updatedFrame =
          controller.editorState.scene.getElementById(frame.id)!;
      expect(updatedFrame.opacity, 0.5);

      // Child rect should also be 0.5
      final updatedRect =
          controller.editorState.scene.getElementById(rect.id)!;
      expect(updatedRect.opacity, 0.5);
    });

    test('adjusting frame opacity updates multiple children', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 80,
        height: 60,
      );
      final ellipse = EllipseElement(
        id: const ElementId('e1'),
        x: 120,
        y: 50,
        width: 60,
        height: 60,
      );
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 10,
        y: 10,
        width: 300,
        height: 200,
        label: 'Frame 1',
      );

      var scene = Scene();
      scene = scene.addElement(rect);
      scene = scene.addElement(ellipse);
      scene = scene.addElement(frame);

      // Assign both to the frame
      scene = scene.updateElement(
        scene.getElementById(rect.id)!.copyWith(frameId: frame.id.value),
      );
      scene = scene.updateElement(
        scene.getElementById(ellipse.id)!.copyWith(frameId: frame.id.value),
      );

      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({frame.id}));
      controller.applyStyleChange(const ElementStyle(opacity: 0.3));

      expect(
        controller.editorState.scene.getElementById(frame.id)!.opacity,
        0.3,
      );
      expect(
        controller.editorState.scene.getElementById(rect.id)!.opacity,
        0.3,
      );
      expect(
        controller.editorState.scene.getElementById(ellipse.id)!.opacity,
        0.3,
      );
    });

    test('non-frame element opacity does not propagate', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 100,
        height: 80,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 200,
        y: 50,
        width: 100,
        height: 80,
      );

      var scene = Scene();
      scene = scene.addElement(rect1);
      scene = scene.addElement(rect2);

      controller.loadScene(scene);
      controller.applyResult(SetSelectionResult({rect1.id}));
      controller.applyStyleChange(const ElementStyle(opacity: 0.5));

      // Only rect1 should change
      expect(
        controller.editorState.scene.getElementById(rect1.id)!.opacity,
        0.5,
      );
      expect(
        controller.editorState.scene.getElementById(rect2.id)!.opacity,
        1.0,
      );
    });

    test('frame tool auto-assigns children, then opacity propagates', () {
      // Simulate: draw a rect, then draw a frame over it using the tool
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 50,
        y: 50,
        width: 100,
        height: 80,
      );

      var scene = Scene();
      scene = scene.addElement(rect);
      controller.loadScene(scene);

      // Use FrameTool directly to create a frame over the rect
      final frameTool = FrameTool();
      final toolContext = controller.toolContext;
      frameTool.onPointerDown(const Point(10, 10), toolContext);
      frameTool.onPointerMove(const Point(250, 250), toolContext);
      final result = frameTool.onPointerUp(const Point(250, 250), toolContext);

      // Apply the frame creation result
      controller.applyResult(result);

      // Should now have 2 elements: rect + frame
      final elements = controller.editorState.scene.activeElements;
      expect(elements, hasLength(2));

      // Find the frame
      final frame = elements.firstWhere((e) => e is FrameElement);

      // The rect should now be a child of the frame
      final updatedRect =
          controller.editorState.scene.getElementById(rect.id)!;
      expect(updatedRect.frameId, frame.id.value);

      // Select the frame and adjust opacity
      controller.applyResult(SetSelectionResult({frame.id}));
      controller.applyStyleChange(const ElementStyle(opacity: 0.4));

      // Both should be at 0.4
      expect(
        controller.editorState.scene.getElementById(frame.id)!.opacity,
        0.4,
      );
      expect(
        controller.editorState.scene.getElementById(rect.id)!.opacity,
        0.4,
      );
    });
  });
}
