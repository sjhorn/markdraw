import 'package:flutter/rendering.dart';

import '../core/scene/scene.dart';
import 'element_renderer.dart';
import 'rough/rough_adapter.dart';
import 'viewport_culling.dart';
import 'viewport_state.dart';

/// A [CustomPainter] that renders all active scene elements with a
/// hand-drawn aesthetic via [RoughAdapter].
///
/// Elements are drawn in fractional-index order. Deleted elements,
/// bound text (containerId != null), and off-screen elements are skipped
/// via [cullElements]. Viewport pan/zoom transforms are applied to the
/// canvas before rendering.
class StaticCanvasPainter extends CustomPainter {
  final Scene scene;
  final RoughAdapter adapter;
  final ViewportState viewport;

  const StaticCanvasPainter({
    required this.scene,
    required this.adapter,
    required this.viewport,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply viewport transform: scale then translate
    canvas.scale(viewport.zoom);
    canvas.translate(-viewport.offset.dx, -viewport.offset.dy);

    final visible = cullElements(scene.orderedElements, viewport, size);
    for (final element in visible) {
      ElementRenderer.render(canvas, element, adapter);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StaticCanvasPainter oldDelegate) {
    return !identical(scene, oldDelegate.scene) ||
        !identical(adapter, oldDelegate.adapter) ||
        viewport != oldDelegate.viewport;
  }
}
