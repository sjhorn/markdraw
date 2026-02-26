import '../elements/elements.dart';
import '../math/math.dart';

/// An immutable collection of drawing elements with CRUD operations.
class Scene {
  final List<Element> _elements;
  final Map<String, ImageFile> files;

  Scene()
      : _elements = const [],
        files = const {};

  Scene._(List<Element> elements, [Map<String, ImageFile>? files])
      : _elements = List.unmodifiable(elements),
        files = files != null
            ? Map.unmodifiable(files)
            : const {};

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
    return Scene._([..._elements, element], files);
  }

  /// Returns a new scene with the element removed by [id].
  Scene removeElement(ElementId id) {
    final filtered = _elements.where((e) => e.id != id).toList();
    if (filtered.length == _elements.length) return this;
    return Scene._(filtered, files);
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
    return Scene._(updated, files);
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
    return Scene._(updated, files);
  }

  /// Returns a new scene with the file added to the store.
  Scene addFile(String fileId, ImageFile file) {
    return Scene._(_elements.toList(), {...files, fileId: file});
  }

  /// Returns a new scene with the file removed from the store.
  Scene removeFile(String fileId) {
    final newFiles = Map<String, ImageFile>.of(files)..remove(fileId);
    return Scene._(_elements.toList(), newFiles);
  }

  /// Returns the bound text element whose [containerId] matches [parentId],
  /// or null if none exists.
  TextElement? findBoundText(ElementId parentId) {
    for (final e in _elements) {
      if (e.isDeleted) continue;
      if (e is TextElement && e.containerId == parentId.value) {
        return e;
      }
    }
    return null;
  }

  /// Returns the bounding box that encloses all active (non-deleted) elements,
  /// or null if there are no active elements.
  Bounds? sceneBounds() {
    Bounds? result;
    for (final e in _elements) {
      if (e.isDeleted) continue;
      final b = Bounds.fromLTWH(e.x, e.y, e.width, e.height);
      result = result == null ? b : result.union(b);
    }
    return result;
  }

  /// Returns the topmost active element whose bounding box contains [point],
  /// or null if no element is hit.
  ///
  /// Bound text elements (containerId != null) are skipped — hit the parent
  /// shape instead.
  Element? getElementAtPoint(Point point) {
    final ordered = orderedElements.where((e) => !e.isDeleted).toList();
    // Iterate in reverse to find topmost (highest index) first.
    for (var i = ordered.length - 1; i >= 0; i--) {
      final e = ordered[i];
      // Skip locked elements — they are invisible to hit-testing
      if (e.locked) continue;
      // Skip bound text — users interact with the parent shape
      if (e is TextElement && e.containerId != null) continue;
      final bounds = Bounds.fromLTWH(e.x, e.y, e.width, e.height);
      if (bounds.containsPoint(point)) return e;
    }
    return null;
  }
}
