import '../core/elements/element.dart';
import '../core/elements/element_id.dart';
import '../core/math/bounds.dart';
import '../core/math/point.dart';
import '../core/scene/scene.dart';
import '../rendering/viewport_state.dart';
import 'tool_type.dart';

/// A mutation description produced by a tool. Tools return these instead of
/// directly modifying state, enabling undo/redo and decoupling from state
/// management.
sealed class ToolResult {}

/// Add a new element to the scene.
class AddElementResult extends ToolResult {
  final Element element;
  AddElementResult(this.element);
}

/// Update an existing element in the scene.
class UpdateElementResult extends ToolResult {
  final Element element;
  UpdateElementResult(this.element);
}

/// Remove an element from the scene by ID.
class RemoveElementResult extends ToolResult {
  final ElementId id;
  RemoveElementResult(this.id);
}

/// Set the current selection to the given element IDs.
class SetSelectionResult extends ToolResult {
  final Set<ElementId> selectedIds;
  SetSelectionResult(this.selectedIds);
}

/// Update the viewport (pan/zoom).
class UpdateViewportResult extends ToolResult {
  final ViewportState viewport;
  UpdateViewportResult(this.viewport);
}

/// Apply multiple results in order.
class CompoundResult extends ToolResult {
  final List<ToolResult> results;
  CompoundResult(this.results);
}

/// Switch to a different tool.
class SwitchToolResult extends ToolResult {
  final ToolType toolType;
  SwitchToolResult(this.toolType);
}

/// A read-only snapshot of the editor state, provided to tools for
/// decision-making.
class ToolContext {
  final Scene scene;
  final ViewportState viewport;
  final Set<ElementId> selectedIds;

  ToolContext({
    required this.scene,
    required this.viewport,
    required Set<ElementId> selectedIds,
  }) : selectedIds = Set.unmodifiable(selectedIds);
}

/// Transient UI overlay data produced by tools during interaction (e.g.,
/// shape preview, line points, marquee rectangle).
class ToolOverlay {
  final Bounds? creationBounds;
  final List<Point>? creationPoints;
  final Bounds? marqueeRect;

  const ToolOverlay({
    this.creationBounds,
    this.creationPoints,
    this.marqueeRect,
  });
}
