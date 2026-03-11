library;

import 'package:flutter/material.dart' hide Element, SelectionOverlay;

import 'package:markdraw/markdraw.dart' hide TextAlign;


/// The main canvas area with pointer/gesture handling.
class EditorCanvas extends StatefulWidget {
  final MarkdrawController controller;

  const EditorCanvas({super.key, required this.controller});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  MarkdrawController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final toolOverlay = controller.activeTool.overlay;

    // Convert Bounds marqueeRect to Flutter Rect
    Rect? marqueeRect;
    if (toolOverlay?.marqueeRect != null) {
      final b = toolOverlay!.marqueeRect!;
      marqueeRect =
          Rect.fromLTWH(b.left, b.top, b.size.width, b.size.height);
    }

    return ColoredBox(
      color: parseColor(controller.canvasBackgroundColor),
      child: MouseRegion(
        cursor: controller.cursorForTool,
        child: Stack(
          children: [
            GestureDetector(
              onScaleStart: (details) => controller.onScaleStart(details),
              onScaleUpdate: (details) => controller.onScaleUpdate(details),
              onScaleEnd: (_) {},
              child: Listener(
                onPointerHover: (event) {
                  controller.onPointerHover(event.localPosition);
                },
                onPointerDown: (event) {
                  controller.onPointerDown(event.localPosition);
                },
                onPointerMove: (event) {
                  controller.onPointerMove(
                      event.localPosition, event.delta);
                },
                onPointerUp: (event) {
                  controller.onPointerUp(event.localPosition);
                },
                onPointerSignal: (event) {
                  controller.onPointerSignal(event);
                },
                child: CustomPaint(
                  painter: StaticCanvasPainter(
                    scene: controller.editorState.scene,
                    adapter: controller.adapter,
                    viewport: controller.editorState.viewport,
                    previewElement: controller.buildPreviewElement(toolOverlay),
                    editingElementId: controller.editingTextElementId,
                    resolvedImages: controller.resolveImages(),
                    pendingElements: controller.flowchartCreator.isCreating
                        ? controller.flowchartCreator.pendingElements
                        : null,
                    gridSize: controller.gridSize,
                    isDarkBackground: _isDark(controller.canvasBackgroundColor),
                  ),
                  foregroundPainter: InteractiveCanvasPainter(
                    viewport: controller.editorState.viewport,
                    interactionMode: controller.interactionMode,
                    selection: controller.isDraggingPointHandle()
                        ? null
                        : controller.buildSelectionOverlay(),
                    marqueeRect: marqueeRect,
                    snapLines: toolOverlay?.snapLines ?? const [],
                    bindTargetBounds: toolOverlay?.bindTargetBounds,
                    bindTargetAngle: toolOverlay?.bindTargetAngle ?? 0.0,
                    closeIndicatorCenter: toolOverlay?.closeIndicatorCenter,
                    pointHandles: controller.buildPointHandles(),
                    midpointHandles: controller.buildMidpointHandles(),
                    segmentMidpoints: controller.isDraggingPointHandle()
                        ? null
                        : controller.buildSegmentMidpoints(),
                    creationPoints: toolOverlay?.creationPoints,
                    creationBounds: toolOverlay?.creationBounds,
                    laserTrail: controller.activeTool is LaserTool
                        ? (controller.activeTool as LaserTool).activeTrail
                        : null,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (controller.editorState.activeToolType == ToolType.eraser &&
                controller.mousePosition != null)
              Positioned(
                left: controller.mousePosition!.dx - 10,
                top: controller.mousePosition!.dy - 10,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: EraserCursorPainter(),
                  ),
                ),
              ),
            if (controller.editingTextElementId != null)
              TextEditingOverlay(controller: controller),
            // Compact property panel trigger
            if (controller.isCompact &&
                controller.selectedElements.isNotEmpty)
              Positioned(
                bottom: 72,
                right: 12,
                child: _CompactPropertyButton(controller: controller),
              ),
          ],
        ),
      ),
    );
  }
}

/// Checks if a hex background color is dark (luminance < 0.5).
bool _isDark(String hexColor) {
  final c = parseColor(hexColor);
  return c.computeLuminance() < 0.5;
}

/// Floating button that opens the compact property panel bottom sheet.
class _CompactPropertyButton extends StatelessWidget {
  final MarkdrawController controller;
  const _CompactPropertyButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.17), blurRadius: 1),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 3),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.tune, size: 22),
        tooltip: 'Properties',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () => showCompactPropertyPanel(context, controller),
      ),
    );
  }
}
