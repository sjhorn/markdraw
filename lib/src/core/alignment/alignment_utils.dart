import '../elements/elements.dart';
import '../math/bounds.dart';

/// Stateless utilities for aligning and distributing elements.
class AlignmentUtils {
  AlignmentUtils._();

  /// Align all elements' left edges to the union bounding box's left.
  static List<Element> alignLeft(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    return [
      for (final e in elements)
        if (e.x != bounds.left) e.copyWith(x: bounds.left) else e,
    ];
  }

  /// Align all elements' horizontal centers to the union bounding box center.
  static List<Element> alignCenterH(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    final centerX = bounds.left + bounds.size.width / 2;
    return [
      for (final e in elements)
        e.copyWith(x: centerX - e.width / 2),
    ];
  }

  /// Align all elements' right edges to the union bounding box's right.
  static List<Element> alignRight(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    final right = bounds.left + bounds.size.width;
    return [
      for (final e in elements)
        e.copyWith(x: right - e.width),
    ];
  }

  /// Align all elements' top edges to the union bounding box's top.
  static List<Element> alignTop(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    return [
      for (final e in elements)
        if (e.y != bounds.top) e.copyWith(y: bounds.top) else e,
    ];
  }

  /// Align all elements' vertical centers to the union bounding box center.
  static List<Element> alignCenterV(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    final centerY = bounds.top + bounds.size.height / 2;
    return [
      for (final e in elements)
        e.copyWith(y: centerY - e.height / 2),
    ];
  }

  /// Align all elements' bottom edges to the union bounding box's bottom.
  static List<Element> alignBottom(List<Element> elements) {
    if (elements.length < 2) return [];
    final bounds = _unionBounds(elements);
    final bottom = bounds.top + bounds.size.height;
    return [
      for (final e in elements)
        e.copyWith(y: bottom - e.height),
    ];
  }

  /// Distribute elements evenly horizontally (by left edge spacing).
  ///
  /// Requires 3+ elements. Elements are sorted by x position; leftmost and
  /// rightmost stay fixed, others are evenly spaced between them.
  static List<Element> distributeH(List<Element> elements) {
    if (elements.length < 3) return [];
    final sorted = List<Element>.of(elements)
      ..sort((a, b) => a.x.compareTo(b.x));

    final first = sorted.first;
    final last = sorted.last;
    final totalWidth =
        (last.x + last.width) - first.x;
    final elemWidths =
        sorted.fold<double>(0, (sum, e) => sum + e.width);
    final gap = (totalWidth - elemWidths) / (sorted.length - 1);

    var currentX = first.x;
    final results = <Element>[];
    for (var i = 0; i < sorted.length; i++) {
      results.add(sorted[i].copyWith(x: currentX));
      currentX += sorted[i].width + gap;
    }
    return results;
  }

  /// Distribute elements evenly vertically (by top edge spacing).
  ///
  /// Requires 3+ elements. Elements are sorted by y position; topmost and
  /// bottommost stay fixed, others are evenly spaced between them.
  static List<Element> distributeV(List<Element> elements) {
    if (elements.length < 3) return [];
    final sorted = List<Element>.of(elements)
      ..sort((a, b) => a.y.compareTo(b.y));

    final first = sorted.first;
    final last = sorted.last;
    final totalHeight =
        (last.y + last.height) - first.y;
    final elemHeights =
        sorted.fold<double>(0, (sum, e) => sum + e.height);
    final gap = (totalHeight - elemHeights) / (sorted.length - 1);

    var currentY = first.y;
    final results = <Element>[];
    for (var i = 0; i < sorted.length; i++) {
      results.add(sorted[i].copyWith(y: currentY));
      currentY += sorted[i].height + gap;
    }
    return results;
  }

  static Bounds _unionBounds(List<Element> elements) {
    var b = Bounds.fromLTWH(
        elements.first.x, elements.first.y,
        elements.first.width, elements.first.height);
    for (var i = 1; i < elements.length; i++) {
      final e = elements[i];
      b = b.union(Bounds.fromLTWH(e.x, e.y, e.width, e.height));
    }
    return b;
  }
}
