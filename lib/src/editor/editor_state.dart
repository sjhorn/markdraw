import '../core/elements/element_id.dart';
import '../core/scene/scene.dart';
import '../rendering/viewport_state.dart';
import 'tool_result.dart';
import 'tool_type.dart';

/// An immutable value object representing the editor's state.
///
/// Holds the scene, viewport, selection, and active tool type.
/// Use [applyResult] to produce a new state from a [ToolResult].
class EditorState {
  final Scene scene;
  final ViewportState viewport;
  final Set<ElementId> selectedIds;
  final ToolType activeToolType;

  EditorState({
    required this.scene,
    required this.viewport,
    required this.selectedIds,
    required this.activeToolType,
  });

  /// Applies a [ToolResult] to produce a new [EditorState].
  /// Returns this state unchanged if [result] is null.
  EditorState applyResult(ToolResult? result) {
    if (result == null) return this;

    return switch (result) {
      AddElementResult(:final element) => copyWith(
          scene: scene.addElement(element),
        ),
      UpdateElementResult(:final element) => copyWith(
          scene: scene.updateElement(element),
        ),
      RemoveElementResult(:final id) => copyWith(
          scene: scene.removeElement(id),
        ),
      SetSelectionResult(:final selectedIds) => copyWith(
          selectedIds: selectedIds,
        ),
      UpdateViewportResult(:final viewport) => copyWith(
          viewport: viewport,
        ),
      SwitchToolResult(:final toolType) => copyWith(
          activeToolType: toolType,
        ),
      CompoundResult(:final results) => results.fold(this,
          (state, r) => state.applyResult(r)),
    };
  }

  /// Creates a copy with the given fields replaced.
  EditorState copyWith({
    Scene? scene,
    ViewportState? viewport,
    Set<ElementId>? selectedIds,
    ToolType? activeToolType,
  }) {
    return EditorState(
      scene: scene ?? this.scene,
      viewport: viewport ?? this.viewport,
      selectedIds: selectedIds ?? this.selectedIds,
      activeToolType: activeToolType ?? this.activeToolType,
    );
  }
}
