import '../elements/elements.dart';
import '../math/fractional_index.dart';
import '../scene/scene.dart';

/// Stateless utilities for layer ordering operations.
///
/// All methods return updated elements. The caller wraps them in
/// `UpdateElementResult` instances.
class LayerUtils {
  LayerUtils._();

  /// Assign fractional indices to any elements that have a null index.
  ///
  /// Returns updated copies only for elements that had null indices.
  static List<Element> ensureIndices(Scene scene) {
    final active = scene.activeElements;
    // Collect existing indices in order
    final withIndex = active.where((e) => e.index != null).toList()
      ..sort((a, b) => a.index!.compareTo(b.index!));

    final withoutIndex = active.where((e) => e.index == null).toList();
    if (withoutIndex.isEmpty) return [];

    // Generate keys after the last existing index
    final lastIndex = withIndex.isNotEmpty ? withIndex.last.index : null;
    final keys =
        FractionalIndex.generateNKeys(withoutIndex.length, after: lastIndex);

    final results = <Element>[];
    for (var i = 0; i < withoutIndex.length; i++) {
      results.add(withoutIndex[i].copyWith(index: keys[i]));
    }
    return results;
  }

  /// Move selected elements above all others.
  static List<Element> bringToFront(Scene scene, Set<ElementId> ids) {
    if (ids.isEmpty) return [];
    final ordered = _orderedActive(scene);
    final selected = <Element>[];
    final others = <Element>[];
    for (final e in ordered) {
      if (ids.contains(e.id)) {
        selected.add(e);
      } else {
        others.add(e);
      }
    }
    if (selected.isEmpty || others.isEmpty) return [];

    // Already at front?
    final topIndex = others.last.index;
    if (selected.first.index != null &&
        topIndex != null &&
        selected.first.index!.compareTo(topIndex) > 0 &&
        selected.length == 1) {
      return [];
    }

    final keys =
        FractionalIndex.generateNKeys(selected.length, after: topIndex);
    final results = <Element>[];
    for (var i = 0; i < selected.length; i++) {
      results.add(selected[i].copyWith(index: keys[i]));
    }
    return results;
  }

  /// Move selected elements below all others.
  static List<Element> sendToBack(Scene scene, Set<ElementId> ids) {
    if (ids.isEmpty) return [];
    final ordered = _orderedActive(scene);
    final selected = <Element>[];
    final others = <Element>[];
    for (final e in ordered) {
      if (ids.contains(e.id)) {
        selected.add(e);
      } else {
        others.add(e);
      }
    }
    if (selected.isEmpty || others.isEmpty) return [];

    final bottomIndex = others.first.index;
    final keys =
        FractionalIndex.generateNKeys(selected.length, before: bottomIndex);
    final results = <Element>[];
    for (var i = 0; i < selected.length; i++) {
      results.add(selected[i].copyWith(index: keys[i]));
    }
    return results;
  }

  /// Move selected elements one position forward (up) in the stack.
  static List<Element> bringForward(Scene scene, Set<ElementId> ids) {
    if (ids.isEmpty) return [];
    final ordered = _orderedActive(scene);

    // Find the first non-selected element that is above any selected element
    // and swap positions.
    final results = <Element>[];
    for (var i = ordered.length - 1; i >= 0; i--) {
      if (!ids.contains(ordered[i].id)) continue;

      // Find the next non-selected element above
      var j = i + 1;
      while (j < ordered.length && ids.contains(ordered[j].id)) {
        j++;
      }
      if (j >= ordered.length) continue; // already at top

      // Swap indices between ordered[i] and ordered[j]
      final above = ordered[j];
      final current = ordered[i];
      final aboveIdx = above.index;
      final currentIdx = current.index;
      results.add(current.copyWith(index: aboveIdx ?? 'V'));
      results.add(above.copyWith(index: currentIdx ?? '0'));

      // Update the ordered list so subsequent swaps see the new state
      ordered[i] = above.copyWith(index: currentIdx ?? '0');
      ordered[j] = current.copyWith(index: aboveIdx ?? 'V');
      break;
    }
    return results;
  }

  /// Move selected elements one position backward (down) in the stack.
  static List<Element> sendBackward(Scene scene, Set<ElementId> ids) {
    if (ids.isEmpty) return [];
    final ordered = _orderedActive(scene);

    final results = <Element>[];
    for (var i = 0; i < ordered.length; i++) {
      if (!ids.contains(ordered[i].id)) continue;

      // Find the next non-selected element below
      var j = i - 1;
      while (j >= 0 && ids.contains(ordered[j].id)) {
        j--;
      }
      if (j < 0) continue; // already at bottom

      final below = ordered[j];
      final current = ordered[i];
      final belowIdx = below.index;
      final currentIdx = current.index;
      results.add(current.copyWith(index: belowIdx ?? '0'));
      results.add(below.copyWith(index: currentIdx ?? 'V'));

      ordered[i] = below.copyWith(index: currentIdx ?? 'V');
      ordered[j] = current.copyWith(index: belowIdx ?? '0');
      break;
    }
    return results;
  }

  /// Get active elements ordered by fractional index.
  static List<Element> _orderedActive(Scene scene) {
    final active = scene.activeElements;
    active.sort((a, b) {
      if (a.index == null && b.index == null) return 0;
      if (a.index == null) return 1;
      if (b.index == null) return -1;
      return a.index!.compareTo(b.index!);
    });
    return active;
  }
}
