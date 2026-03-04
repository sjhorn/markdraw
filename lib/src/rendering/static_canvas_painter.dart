
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../core/elements/elements.dart' as core show TextElement;
import '../core/elements/elements.dart' hide TextElement;
import '../core/scene/scene_exports.dart';
import '../editor/bindings/arrow_label_utils.dart';
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

      // For arrows with bound text, wrap in a saveLayer so we can
      // punch a clear hole behind the label (matching Excalidraw).
      // Keep the layer active during editing so the arrow line stays
      // cleared behind the editing overlay.
      final arrowLabel = element is ArrowElement
          ? scene.findBoundText(element.id)
          : null;
      final hasArrowLabel =
          arrowLabel != null && arrowLabel.text.isNotEmpty;
      if (hasArrowLabel) {
        canvas.saveLayer(null, Paint());
      }

      ElementRenderer.render(canvas, element, adapter,
          resolvedImages: resolvedImages);
      _renderBoundText(canvas, element);

      if (hasArrowLabel) {
        canvas.restore();
      }

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
    final isEditing =
        editingElementId != null && boundText.id == editingElementId;

    if (element is ArrowElement) {
      // Always clear the arrow behind the label (even during editing,
      // so the overlay text isn't drawn over the arrow line).
      _renderArrowLabel(canvas, element, boundText, skipText: isEditing);
    } else {
      if (!isEditing) {
        _renderShapeLabel(canvas, element, boundText);
      }
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
    // Use longestLine so painter.width reflects actual content width,
    // allowing us to manually position based on textAlign.
    painter.textWidthBasis = TextWidthBasis.longestLine;
    painter.layout(maxWidth: maxWidth > 0 ? maxWidth : 0);

    final textX = switch (textElem.textAlign) {
      TextAlign.left => shape.x + boundTextPadding,
      TextAlign.center => shape.x + (shape.width - painter.width) / 2,
      TextAlign.right =>
        shape.x + shape.width - painter.width - boundTextPadding,
    };
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

  /// Renders a label centered on the arrow's midpoint, clearing the arrow
  /// line behind the text (matching Excalidraw behavior).
  ///
  /// When [skipText] is true, only the clear rect is drawn (used during
  /// editing so the overlay text isn't drawn over the arrow line).
  void _renderArrowLabel(
      Canvas canvas, ArrowElement arrow, core.TextElement textElem,
      {bool skipText = false}) {
    final mid = ArrowLabelUtils.computeArrowMidpoint(arrow);

    final painter = TextRenderer.buildTextPainter(textElem);
    painter.layout();

    // Center text on midpoint
    final textX = mid.x - painter.width / 2;
    final textY = mid.y - painter.height / 2;

    // Clear the arrow behind the text with padding — the arrow and label
    // are wrapped in a saveLayer by the paint loop, so BlendMode.clear
    // punches a transparent hole through the arrow pixels, letting the
    // canvas background show through.
    canvas.drawRect(
      Rect.fromLTWH(
        textX - boundTextPadding,
        textY - boundTextPadding,
        painter.width + boundTextPadding * 2,
        painter.height + boundTextPadding * 2,
      ),
      Paint()..blendMode = ui.BlendMode.clear,
    );

    if (!skipText) {
      painter.paint(canvas, Offset(textX, textY));
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant StaticCanvasPainter oldDelegate) {
    return !identical(scene, oldDelegate.scene) ||
        !identical(adapter, oldDelegate.adapter) ||
        viewport != oldDelegate.viewport ||
        !identical(previewElement, oldDelegate.previewElement);
  }
}
