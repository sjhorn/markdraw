import 'package:flutter/rendering.dart';

import '../core/elements/text_element.dart' as core show TextElement;
import '../core/scene/scene.dart';
import 'element_renderer.dart';
import 'rough/rough_adapter.dart';
import 'viewport_state.dart';

/// A [CustomPainter] that renders all active scene elements with a
/// hand-drawn aesthetic via [RoughAdapter].
///
/// Elements are drawn in fractional-index order. Deleted elements and
/// bound text (containerId != null) are skipped. Viewport pan/zoom
/// transforms are applied to the canvas before rendering.
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

    final elements = scene.orderedElements;
    for (final element in elements) {
      if (element.isDeleted) continue;

      // Skip bound text — it will be drawn with its parent shape in future
      if (element is core.TextElement && element.containerId != null) continue;

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
