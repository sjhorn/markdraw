library;

import 'package:flutter/material.dart';

import 'markdraw_controller.dart';

/// Zoom in/out/reset controls (bottom-left on desktop).
class ZoomControls extends StatelessWidget {
  final MarkdrawController controller;
  final Size Function() getCanvasSize;

  const ZoomControls({
    super.key,
    required this.controller,
    required this.getCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zoomPercent =
        (controller.editorState.viewport.zoom * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.17), blurRadius: 1),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 3),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: () => controller.zoomOut(getCanvasSize()),
            tooltip: 'Zoom out (Ctrl+\u2212)',
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 16,
            padding: EdgeInsets.zero,
          ),
          InkWell(
            onTap: () => controller.resetZoom(),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '$zoomPercent%',
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => controller.zoomIn(getCanvasSize()),
            tooltip: 'Zoom in (Ctrl++)',
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 16,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
