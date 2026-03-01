
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../core/elements/elements.dart' as core show TextElement;
import '../core/elements/elements.dart' hide TextElement;
import '../core/math/math.dart';
import '../core/scene/scene_exports.dart';
import 'element_renderer.dart';
import 'rough/rough_adapter.dart';
import 'text_renderer.dart';
import 'viewport_culling.dart';
import 'viewport_state.dart';

/// A [CustomPainter] that renders all active scene elements with a
/// hand-drawn aesthetic via [RoughAdapter].
///
/// Elements are drawn in fractional-index order. Deleted elements,
/// bound text (containerId != null), and off-screen elements are skipped
/// via [cullElements]. Viewport pan/zoom transforms are applied to the
/// canvas before rendering.
///
/// An optional [previewElement] is rendered last, for live creation preview.
class StaticCanvasPainter extends CustomPainter {
  final Scene scene;
  final RoughAdapter adapter;
  final ViewportState viewport;
  final Element? previewElement;

  /// When set, the text element with this ID is not rendered — the editing
  /// overlay is shown instead.
  final ElementId? editingElementId;

  /// Decoded images keyed by fileId, passed through to ElementRenderer.
  final Map<String, ui.Image>? resolvedImages;

  const StaticCanvasPainter({
    required this.scene,
    required this.adapter,
    required this.viewport,
    this.previewElement,
    this.editingElementId,
    this.resolvedImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply viewport transform: scale then translate
    canvas.scale(viewport.zoom);
    canvas.translate(-viewport.offset.dx, -viewport.offset.dy);

    final visible = cullElements(scene.orderedElements, viewport, size);
    for (final element in visible) {
      // Skip standalone text that is being edited
      if (editingElementId != null &&
          element.id == editingElementId &&
          element is core.TextElement) {
        continue;
      }

      // Clip children of frames to frame bounds
      final hasClip = element.frameId != null;
      if (hasClip) {
        final frame = _findFrameElement(element.frameId!);
        if (frame != null) {
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(
            frame.x,
            frame.y,
            frame.width,
            frame.height,
          ));
        }
      }

      ElementRenderer.render(canvas, element, adapter,
          resolvedImages: resolvedImages);
      _renderBoundText(canvas, element);

      if (hasClip) {
        final frame = _findFrameElement(element.frameId!);
        if (frame != null) {
          canvas.restore();
        }
      }
    }

    // Render live creation preview on top
    if (previewElement != null) {
      ElementRenderer.render(canvas, previewElement!, adapter,
          resolvedImages: resolvedImages);
    }

    canvas.restore();
  }

  /// Finds a frame element by its ID value.
  FrameElement? _findFrameElement(String frameId) {
    final el = scene.getElementById(ElementId(frameId));
    return el is FrameElement ? el : null;
  }

  /// Renders bound text inside a container shape or at an arrow's midpoint.
  void _renderBoundText(Canvas canvas, Element element) {
    final boundText = scene.findBoundText(element.id);
    if (boundText == null || boundText.text.isEmpty) return;
    // Skip bound text that is being edited
    if (editingElementId != null && boundText.id == editingElementId) return;

    if (element is ArrowElement) {
      _renderArrowLabel(canvas, element, boundText);
    } else {
      _renderShapeLabel(canvas, element, boundText);
    }
  }

  /// Renders bound text centered inside a container shape.
  void _renderShapeLabel(
      Canvas canvas, Element shape, core.TextElement textElem) {
    final hasRotation = shape.angle != 0.0;
    if (hasRotation) {
      canvas.save();
      final cx = shape.x + shape.width / 2;
      final cy = shape.y + shape.height / 2;
      canvas.translate(cx, cy);
      canvas.rotate(shape.angle);
      canvas.translate(-cx, -cy);
    }

    const boundTextPadding = 5.0;
    final maxWidth = shape.width - boundTextPadding * 2;
    final painter = TextRenderer.buildTextPainter(textElem);
    painter.layout(maxWidth: maxWidth > 0 ? maxWidth : 0);

    // Paint at left padding edge; TextPainter handles textAlign within maxWidth
    final textX = shape.x + boundTextPadding;
    final textY = switch (textElem.verticalAlign) {
      VerticalAlign.top => shape.y + boundTextPadding,
      VerticalAlign.middle =>
        shape.y + (shape.height - painter.height) / 2,
      VerticalAlign.bottom =>
        shape.y + shape.height - painter.height - boundTextPadding,
    };
    painter.paint(canvas, Offset(textX, textY));
    painter.dispose();

    if (hasRotation) {
      canvas.restore();
    }
  }

  /// Renders a label at the arrow's midpoint.
  void _renderArrowLabel(
      Canvas canvas, ArrowElement arrow, core.TextElement textElem) {
    final mid = _computeArrowMidpoint(arrow);

    final painter = TextRenderer.buildTextPainter(textElem);
    painter.layout();

    // Position above the midpoint
    final textX = mid.x - painter.width / 2;
    final textY = mid.y - painter.height - 4;
    painter.paint(canvas, Offset(textX, textY));
    painter.dispose();
  }

  /// Compute the midpoint along an arrow's polyline path.
  static Point _computeArrowMidpoint(ArrowElement arrow) {
    final pts = arrow.points
        .map((p) => Point(p.x + arrow.x, p.y + arrow.y))
        .toList();
    if (pts.length < 2) {
      return Point(arrow.x + arrow.width / 2, arrow.y + arrow.height / 2);
    }

    var totalLength = 0.0;
    for (var i = 1; i < pts.length; i++) {
      totalLength += pts[i - 1].distanceTo(pts[i]);
    }

    final halfLength = totalLength / 2;
    var walked = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final segLen = pts[i - 1].distanceTo(pts[i]);
      if (walked + segLen >= halfLength) {
        final remaining = halfLength - walked;
        final t = segLen > 0 ? remaining / segLen : 0.0;
        return Point(
          pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t,
          pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t,
        );
      }
      walked += segLen;
    }
    return pts.last;
  }

  @override
  bool shouldRepaint(covariant StaticCanvasPainter oldDelegate) {
    return !identical(scene, oldDelegate.scene) ||
        !identical(adapter, oldDelegate.adapter) ||
        viewport != oldDelegate.viewport ||
        !identical(previewElement, oldDelegate.previewElement);
  }
}
