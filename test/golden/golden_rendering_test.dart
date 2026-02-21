import 'dart:math' as math;

import 'package:flutter/material.dart' hide SelectionOverlay;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/text_element.dart' as core
    show TextElement;
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/rendering/interactive/interactive_canvas_painter.dart';
import 'package:markdraw/src/rendering/interactive/selection_overlay.dart';
import 'package:markdraw/src/rendering/rough/rough_canvas_adapter.dart';
import 'package:markdraw/src/rendering/static_canvas_painter.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

/// Wraps a [StaticCanvasPainter] in a deterministic widget for golden testing.
Widget _buildStaticCanvas(
  Scene scene, {
  ViewportState viewport = const ViewportState(),
  Size size = const Size(200, 150),
}) {
  return RepaintBoundary(
    child: SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        size: size,
        painter: StaticCanvasPainter(
          scene: scene,
          adapter: RoughCanvasAdapter(),
          viewport: viewport,
        ),
      ),
    ),
  );
}

/// Wraps static + interactive painters in a stacked widget for golden testing.
Widget _buildInteractiveCanvas(
  Scene scene, {
  ViewportState viewport = const ViewportState(),
  Size size = const Size(200, 150),
  SelectionOverlay? selection,
}) {
  return RepaintBoundary(
    child: SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        size: size,
        painter: StaticCanvasPainter(
          scene: scene,
          adapter: RoughCanvasAdapter(),
          viewport: viewport,
        ),
        foregroundPainter: InteractiveCanvasPainter(
          viewport: viewport,
          selection: selection,
        ),
      ),
    ),
  );
}

void main() {
  group('Golden rendering tests', () {
    testWidgets('renders rectangle', (tester) async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 100,
        height: 60,
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#e3f2fd',
        seed: 42,
      ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/rectangle_solid.png'),
      );
    });

    testWidgets('renders ellipse', (tester) async {
      final scene = Scene().addElement(EllipseElement(
        id: const ElementId('e1'),
        x: 20,
        y: 15,
        width: 120,
        height: 80,
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#e8f5e9',
        seed: 42,
      ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/ellipse_solid.png'),
      );
    });

    testWidgets('renders diamond', (tester) async {
      final scene = Scene().addElement(DiamondElement(
        id: const ElementId('d1'),
        x: 20,
        y: 10,
        width: 100,
        height: 80,
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#fff3e0',
        seed: 42,
      ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/diamond_solid.png'),
      );
    });

    testWidgets('renders mixed scene', (tester) async {
      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 5,
            y: 5,
            width: 60,
            height: 40,
            roughness: 0,
            fillStyle: FillStyle.solid,
            backgroundColor: '#e3f2fd',
            seed: 42,
          ))
          .addElement(EllipseElement(
            id: const ElementId('e1'),
            x: 80,
            y: 10,
            width: 50,
            height: 50,
            roughness: 0,
            fillStyle: FillStyle.solid,
            backgroundColor: '#e8f5e9',
            seed: 43,
          ))
          .addElement(DiamondElement(
            id: const ElementId('d1'),
            x: 140,
            y: 5,
            width: 50,
            height: 50,
            roughness: 0,
            fillStyle: FillStyle.solid,
            backgroundColor: '#fff3e0',
            seed: 44,
          ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/mixed_scene.png'),
      );
    });

    testWidgets('renders line and arrow', (tester) async {
      final scene = Scene()
          .addElement(LineElement(
            id: const ElementId('l1'),
            x: 10,
            y: 30,
            width: 80,
            height: 0,
            points: const [Point(0, 0), Point(80, 0)],
            roughness: 0,
            seed: 42,
          ))
          .addElement(ArrowElement(
            id: const ElementId('a1'),
            x: 10,
            y: 80,
            width: 80,
            height: 40,
            points: const [Point(0, 0), Point(80, 40)],
            endArrowhead: Arrowhead.arrow,
            roughness: 0,
            seed: 43,
          ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/line_and_arrow.png'),
      );
    });

    testWidgets('renders text element', (tester) async {
      final scene = Scene().addElement(core.TextElement(
        id: const ElementId('t1'),
        x: 10,
        y: 10,
        width: 150,
        height: 30,
        text: 'Hello Golden',
        fontSize: 20,
        seed: 42,
      ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/text_element.png'),
      );
    });

    testWidgets('renders bound text in rectangle', (tester) async {
      final scene = Scene()
          .addElement(RectangleElement(
            id: const ElementId('r1'),
            x: 10,
            y: 10,
            width: 150,
            height: 80,
            roughness: 0,
            fillStyle: FillStyle.solid,
            backgroundColor: '#e3f2fd',
            seed: 42,
          ))
          .addElement(core.TextElement(
            id: const ElementId('t1'),
            x: 10,
            y: 10,
            width: 135,
            height: 25,
            text: 'Label',
            fontSize: 20,
            containerId: 'r1',
            seed: 43,
          ));
      await tester.pumpWidget(
        Center(
          child: _buildStaticCanvas(scene, size: const Size(200, 120)),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/bound_text_in_rect.png'),
      );
    });

    testWidgets('renders rotated element', (tester) async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 30,
        y: 20,
        width: 100,
        height: 60,
        angle: math.pi / 6, // 30 degrees
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#e3f2fd',
        seed: 42,
      ));
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/rotated_rectangle.png'),
      );
    });

    testWidgets('renders viewport zoom 2x', (tester) async {
      final scene = Scene().addElement(RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 60,
        height: 40,
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#e3f2fd',
        seed: 42,
      ));
      const viewport = ViewportState(zoom: 2.0);
      await tester.pumpWidget(
        Center(child: _buildStaticCanvas(scene, viewport: viewport)),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/viewport_zoom_2x.png'),
      );
    });

    testWidgets('renders selection overlay with handles', (tester) async {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 20,
        y: 20,
        width: 100,
        height: 60,
        roughness: 0,
        fillStyle: FillStyle.solid,
        backgroundColor: '#e3f2fd',
        seed: 42,
      );
      final scene = Scene().addElement(rect);
      final selection = SelectionOverlay.fromElements([rect]);

      await tester.pumpWidget(
        Center(
          child: _buildInteractiveCanvas(
            scene,
            selection: selection,
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/selection_overlay.png'),
      );
    });
  });
}
