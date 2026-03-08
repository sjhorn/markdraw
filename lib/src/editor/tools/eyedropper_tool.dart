import 'dart:ui';

import '../../core/math/math.dart';
import '../tool_result.dart';
import '../tool_type.dart';
import 'tool.dart';

/// Eye dropper tool — clicks canvas to sample a pixel color.
///
/// The actual color sampling is done by the controller (via PictureRecorder),
/// as it requires Flutter rendering infrastructure.
class EyedropperTool implements Tool {
  /// The scene-space point where the user clicked.
  Point? clickPoint;

  @override
  ToolType get type => ToolType.eyedropper;

  @override
  ToolResult? onPointerDown(Point point, ToolContext context) {
    clickPoint = point;
    return null;
  }

  @override
  ToolResult? onPointerMove(Point point, ToolContext context,
      {Offset? screenDelta}) {
    return null;
  }

  @override
  ToolResult? onPointerUp(Point point, ToolContext context) {
    // The controller handles async color sampling on pointer up
    return null;
  }

  @override
  ToolResult? onKeyEvent(String key,
      {bool shift = false, bool ctrl = false, ToolContext? context}) {
    return null;
  }

  @override
  ToolOverlay? get overlay => null;

  @override
  void reset() {
    clickPoint = null;
  }
}
