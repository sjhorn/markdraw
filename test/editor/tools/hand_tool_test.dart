import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/editor/tools/hand_tool.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  late HandTool tool;
  late ToolContext context;

  setUp(() {
    tool = HandTool();
    context = ToolContext(
      scene: Scene(),
      viewport: const ViewportState(),
      selectedIds: {},
    );
  });

  group('HandTool', () {
    test('type is hand', () {
      expect(tool.type, ToolType.hand);
    });

    test('onPointerDown returns null', () {
      expect(tool.onPointerDown(const Point(0, 0), context), isNull);
    });

    test('onPointerMove with screenDelta pans viewport', () {
      tool.onPointerDown(const Point(0, 0), context);
      final result = tool.onPointerMove(
        const Point(0, 0),
        context,
        screenDelta: const Offset(10, 20),
      );
      expect(result, isA<UpdateViewportResult>());
      final viewport = (result! as UpdateViewportResult).viewport;
      // pan(Offset(10,20)) with zoom=1.0 → offset = (0 - 10/1, 0 - 20/1) = (-10, -20)
      expect(viewport.offset, const Offset(-10, -20));
    });

    test('onPointerMove without screenDelta returns null', () {
      tool.onPointerDown(const Point(0, 0), context);
      final result = tool.onPointerMove(const Point(10, 20), context);
      expect(result, isNull);
    });

    test('overlay is always null', () {
      expect(tool.overlay, isNull);
    });

    test('reset is safe', () {
      tool.reset();
      expect(tool.overlay, isNull);
    });
  });
}
