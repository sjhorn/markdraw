import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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

  group('all properties round-trip through .markdraw', () {
    test('stroke color', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        strokeColor: '#ff0000',
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('color='));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.strokeColor, '#ff0000');
    });

    test('background color', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        backgroundColor: '#00ff00',
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('fill='));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.backgroundColor, '#00ff00');
    });

    test('stroke width', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        strokeWidth: 4.0,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('stroke-width=4'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.strokeWidth, 4.0);
    });

    test('stroke style dashed', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        strokeStyle: StrokeStyle.dashed,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('stroke=dashed'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.strokeStyle, StrokeStyle.dashed);
    });

    test('fill style hachure', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        fillStyle: FillStyle.hachure,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('fill-style=hachure'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.fillStyle, FillStyle.hachure);
    });

    test('roughness', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        roughness: 2.0,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('roughness=2'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.roughness, 2.0);
    });

    test('opacity', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        opacity: 0.6,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('opacity=0.6'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.opacity, 0.6);
    });

    test('angle', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        angle: 0.7854, // ~45 degrees
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('angle=45'));
      final parsed = parser.parseLine(line, 1);
      // Angle round-trips through degrees, so check within tolerance
      expect(parsed.value!.angle, closeTo(0.7854, 0.02));
    });

    test('locked', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        locked: true,
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('locked'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.locked, isTrue);
    });

    test('roundness', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        roundness: const Roundness.adaptive(value: 8.0),
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('rounded=8'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.roundness, isNotNull);
      expect(parsed.value!.roundness!.value, 8.0);
    });

    test('link', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        link: 'https://example.com',
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('link="https://example.com"'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.link, 'https://example.com');
    });

    test('groupIds', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        groupIds: ['g1', 'g2'],
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('group=g1,g2'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.groupIds, ['g1', 'g2']);
    });

    test('frameId', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        frameId: 'f1',
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, contains('frame=f1'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value!.frameId, 'f1');
    });

    test('frame label', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0, y: 0, width: 200, height: 200,
        label: 'My Section',
      );
      final line = serializer.serialize(frame, alias: 'f1');
      expect(line, contains('"My Section"'));
      final parsed = parser.parseLine(line, 1);
      expect(parsed.value, isA<FrameElement>());
      expect((parsed.value as FrameElement).label, 'My Section');
    });

    test('default values are omitted from output', () {
      final serializer = SketchLineSerializer();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 0, y: 0, width: 100, height: 50,
        // All defaults
      );
      final line = serializer.serialize(rect, alias: 'r1');
      expect(line, isNot(contains('color=')));
      expect(line, isNot(contains('fill=')));
      expect(line, isNot(contains('stroke=')));
      expect(line, isNot(contains('stroke-width=')));
      expect(line, isNot(contains('fill-style=')));
      expect(line, isNot(contains('roughness=')));
      expect(line, isNot(contains('opacity=')));
      expect(line, isNot(contains('angle=')));
      expect(line, isNot(contains('locked')));
      expect(line, isNot(contains('rounded=')));
      expect(line, isNot(contains('link=')));
      expect(line, isNot(contains('group=')));
      expect(line, isNot(contains('frame=')));
    });

    test('all properties combined on single element', () {
      final serializer = SketchLineSerializer();
      final parser = SketchLineParser();

      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10, y: 20, width: 100, height: 50,
        strokeColor: '#ff0000',
        backgroundColor: '#00ff00',
        strokeWidth: 4.0,
        strokeStyle: StrokeStyle.dashed,
        fillStyle: FillStyle.crossHatch,
        roughness: 0.0,
        opacity: 0.7,
        angle: 1.5708, // 90 degrees
        locked: true,
        roundness: const Roundness.adaptive(value: 12.0),
        link: 'https://dart.dev',
        groupIds: ['g1'],
        frameId: 'f1',
      );
      final line = serializer.serialize(rect, alias: 'r1');
      final parsed = parser.parseLine(line, 1);
      final r = parsed.value!;

      expect(r.strokeColor, '#ff0000');
      expect(r.backgroundColor, '#00ff00');
      expect(r.strokeWidth, 4.0);
      expect(r.strokeStyle, StrokeStyle.dashed);
      expect(r.fillStyle, FillStyle.crossHatch);
      expect(r.roughness, 0.0);
      expect(r.opacity, 0.7);
      expect(r.angle, closeTo(1.5708, 0.02));
      expect(r.locked, isTrue);
      expect(r.roundness!.value, 12.0);
      expect(r.link, 'https://dart.dev');
      expect(r.groupIds, ['g1']);
      expect(r.frameId, 'f1');
    });
  });
}
