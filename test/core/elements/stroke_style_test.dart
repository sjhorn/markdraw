import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('StrokeStyle', () {
    test('has three variants', () {
      expect(StrokeStyle.values.length, 3);
    });

    test('variants are solid, dashed, dotted', () {
      expect(StrokeStyle.values, contains(StrokeStyle.solid));
      expect(StrokeStyle.values, contains(StrokeStyle.dashed));
      expect(StrokeStyle.values, contains(StrokeStyle.dotted));
    });

    test('name returns the variant name', () {
      expect(StrokeStyle.solid.name, 'solid');
      expect(StrokeStyle.dashed.name, 'dashed');
      expect(StrokeStyle.dotted.name, 'dotted');
    });
  });
}
