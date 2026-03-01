
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/math/math.dart';
import '../viewport_state.dart';
import 'handle.dart';
import 'interaction_mode.dart';
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
  final InteractionMode interactionMode;
  final SelectionOverlay? selection;
  final Bounds? hoveredBounds;
  final List<SnapLine> snapLines;
  final Rect? marqueeRect;
  final List<Point>? creationPoints;
  final Bounds? creationBounds;
  final List<Point>? pointHandles;
  final Bounds? bindTargetBounds;
  final double bindTargetAngle;

  const InteractiveCanvasPainter({
    required this.viewport,
    this.interactionMode = InteractionMode.pointer,
    this.selection,
    this.hoveredBounds,
    this.snapLines = const [],
    this.marqueeRect,
    this.creationPoints,
    this.creationBounds,
    this.pointHandles,
    this.bindTargetBounds,
    this.bindTargetAngle = 0.0,
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
      final isMultiSelect = selection!.elementBounds.isNotEmpty;
      final hasAngle = selection!.angle != 0.0;

      // Multi-select: draw individual per-element outlines first
      if (isMultiSelect) {
        SelectionRenderer.drawElementOutlines(
            canvas, selection!.elementBounds,
            mode: interactionMode);
      }

      if (hasAngle) {
        canvas.save();
        final center = selection!.bounds.center;
        canvas.translate(center.x, center.y);
        canvas.rotate(selection!.angle);
        canvas.translate(-center.x, -center.y);
      }

      if (selection!.showBoundingBox) {
        if (isMultiSelect) {
          SelectionRenderer.drawDashedSelectionBox(canvas, selection!.bounds,
              mode: interactionMode);
        } else {
          SelectionRenderer.drawSelectionBox(canvas, selection!.bounds,
              mode: interactionMode);
        }
      }

      if (!selection!.isLocked) {
        if (selection!.showBoundingBox) {
          SelectionRenderer.drawHandles(canvas, selection!.handles,
              mode: interactionMode);

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
              mode: interactionMode,
            );
          }
        }

        // Point handles (for line/arrow vertex editing) — drawn in the
        // same rotated canvas space so they follow the element's rotation.
        if (pointHandles != null && pointHandles!.isNotEmpty) {
          SelectionRenderer.drawPointHandles(canvas, pointHandles!,
              mode: interactionMode);
        }
      }

      if (hasAngle) {
        canvas.restore();
      }
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

    // Binding indicator
    if (bindTargetBounds != null) {
      SelectionRenderer.drawBindingIndicator(
          canvas, bindTargetBounds!, bindTargetAngle);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InteractiveCanvasPainter oldDelegate) {
    return viewport != oldDelegate.viewport ||
        interactionMode != oldDelegate.interactionMode ||
        selection != oldDelegate.selection ||
        hoveredBounds != oldDelegate.hoveredBounds ||
        marqueeRect != oldDelegate.marqueeRect ||
        creationBounds != oldDelegate.creationBounds ||
        bindTargetBounds != oldDelegate.bindTargetBounds ||
        bindTargetAngle != oldDelegate.bindTargetAngle ||
        !listEquals(snapLines, oldDelegate.snapLines) ||
        !listEquals(creationPoints, oldDelegate.creationPoints) ||
        !listEquals(pointHandles, oldDelegate.pointHandles);
  }
}
