
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/math/bounds.dart';
import '../../core/math/point.dart';
import '../viewport_state.dart';
import 'handle.dart';
import 'selection_overlay.dart';
import 'selection_renderer.dart';
import 'snap_line.dart';

/// A [CustomPainter] that renders the interactive overlay layer.
///
/// This painter sits on top of [StaticCanvasPainter] and draws selection UI
/// (bounding boxes, resize handles, rotation handle), hover highlights,
/// snap/alignment lines, marquee selection rectangle, and in-progress
/// creation previews.
///
/// All inputs are data — no gesture handling occurs here.
class InteractiveCanvasPainter extends CustomPainter {
  final ViewportState viewport;
  final SelectionOverlay? selection;
  final Bounds? hoveredBounds;
  final List<SnapLine> snapLines;
  final Rect? marqueeRect;
  final List<Point>? creationPoints;
  final Bounds? creationBounds;
  final List<Point>? pointHandles;

  const InteractiveCanvasPainter({
    required this.viewport,
    this.selection,
    this.hoveredBounds,
    this.snapLines = const [],
    this.marqueeRect,
    this.creationPoints,
    this.creationBounds,
    this.pointHandles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply the same viewport transform as StaticCanvasPainter
    canvas.scale(viewport.zoom);
    canvas.translate(-viewport.offset.dx, -viewport.offset.dy);

    // Hover highlight (drawn under selection)
    if (hoveredBounds != null) {
      SelectionRenderer.drawHoverHighlight(canvas, hoveredBounds!);
    }

    // Selection box + handles (all drawn in the same rotated space)
    if (selection != null) {
      final hasAngle = selection!.angle != 0.0;

      if (hasAngle) {
        canvas.save();
        final center = selection!.bounds.center;
        canvas.translate(center.x, center.y);
        canvas.rotate(selection!.angle);
        canvas.translate(-center.x, -center.y);
      }

      SelectionRenderer.drawSelectionBox(canvas, selection!.bounds);
      SelectionRenderer.drawHandles(canvas, selection!.handles);

      // Draw rotation handle
      final rotationHandle = selection!.handles
          .where((h) => h.type == HandleType.rotation)
          .firstOrNull;
      final topCenterHandle = selection!.handles
          .where((h) => h.type == HandleType.topCenter)
          .firstOrNull;
      if (rotationHandle != null && topCenterHandle != null) {
        SelectionRenderer.drawRotationHandle(
          canvas,
          rotationHandle.position,
          topCenterHandle.position,
        );
      }

      if (hasAngle) {
        canvas.restore();
      }
    }

    // Point handles (for line/arrow vertex editing)
    if (pointHandles != null && pointHandles!.isNotEmpty) {
      SelectionRenderer.drawPointHandles(canvas, pointHandles!);
    }

    // Snap lines
    for (final snapLine in snapLines) {
      SelectionRenderer.drawSnapLine(canvas, snapLine);
    }

    // Marquee rectangle
    if (marqueeRect != null) {
      SelectionRenderer.drawMarquee(canvas, marqueeRect!);
    }

    // Creation preview line
    if (creationPoints != null && creationPoints!.length >= 2) {
      SelectionRenderer.drawCreationPreviewLine(canvas, creationPoints!);
    }

    // Creation preview shape
    if (creationBounds != null) {
      SelectionRenderer.drawCreationPreviewShape(canvas, creationBounds!);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InteractiveCanvasPainter oldDelegate) {
    return viewport != oldDelegate.viewport ||
        selection != oldDelegate.selection ||
        hoveredBounds != oldDelegate.hoveredBounds ||
        marqueeRect != oldDelegate.marqueeRect ||
        creationBounds != oldDelegate.creationBounds ||
        !listEquals(snapLines, oldDelegate.snapLines) ||
        !listEquals(creationPoints, oldDelegate.creationPoints) ||
        !listEquals(pointHandles, oldDelegate.pointHandles);
  }
}
