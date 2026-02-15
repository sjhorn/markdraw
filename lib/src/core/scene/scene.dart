import '../elements/element.dart';
import '../elements/element_id.dart';
import '../math/bounds.dart';
import '../math/point.dart';

/// An immutable collection of drawing elements with CRUD operations.
class Scene {
  final List<Element> _elements;

  Scene() : _elements = const [];

  Scene._(List<Element> elements) : _elements = List.unmodifiable(elements);

  /// All elements in the scene (including soft-deleted).
  List<Element> get elements => _elements;

  /// Active (non-deleted) elements.
  List<Element> get activeElements =>
      _elements.where((e) => !e.isDeleted).toList();

  /// Elements ordered by fractional index (null index sorts last).
  List<Element> get orderedElements {
    final sorted = List<Element>.from(_elements);
    sorted.sort((a, b) {
      if (a.index == null && b.index == null) return 0;
      if (a.index == null) return 1;
      if (b.index == null) return -1;
      return a.index!.compareTo(b.index!);
    });
    return sorted;
  }

  /// Returns a new scene with the element added.
  Scene addElement(Element element) {
    return Scene._([..._elements, element]);
  }

  /// Returns a new scene with the element removed by [id].
  Scene removeElement(ElementId id) {
    final filtered = _elements.where((e) => e.id != id).toList();
    if (filtered.length == _elements.length) return this;
    return Scene._(filtered);
  }

  /// Returns a new scene with the element replaced.
  /// The replacement element's version is automatically bumped.
  Scene updateElement(Element element) {
    final updated = _elements.map((e) {
      if (e.id == element.id) {
        return element.bumpVersion();
      }
      return e;
    }).toList();
    return Scene._(updated);
  }

  /// Finds an element by [id], or returns null.
  Element? getElementById(ElementId id) {
    for (final e in _elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Soft-deletes the element with the given [id].
  Scene softDeleteElement(ElementId id) {
    final updated = _elements.map((e) {
      if (e.id == id) return e.softDelete();
      return e;
    }).toList();
    return Scene._(updated);
  }

  /// Returns the topmost active element whose bounding box contains [point],
  /// or null if no element is hit.
  Element? getElementAtPoint(Point point) {
    final ordered = orderedElements.where((e) => !e.isDeleted).toList();
    // Iterate in reverse to find topmost (highest index) first.
    for (var i = ordered.length - 1; i >= 0; i--) {
      final e = ordered[i];
      final bounds = Bounds.fromLTWH(e.x, e.y, e.width, e.height);
      if (bounds.containsPoint(point)) return e;
    }
    return null;
  }
}
