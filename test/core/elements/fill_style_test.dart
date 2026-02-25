import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('FillStyle', () {
    test('has four variants', () {
      expect(FillStyle.values.length, 4);
    });

    test('variants are solid, hachure, crossHatch, zigzag', () {
      expect(FillStyle.values, contains(FillStyle.solid));
      expect(FillStyle.values, contains(FillStyle.hachure));
      expect(FillStyle.values, contains(FillStyle.crossHatch));
      expect(FillStyle.values, contains(FillStyle.zigzag));
    });

    test('name returns the variant name', () {
      expect(FillStyle.solid.name, 'solid');
      expect(FillStyle.hachure.name, 'hachure');
      expect(FillStyle.crossHatch.name, 'crossHatch');
      expect(FillStyle.zigzag.name, 'zigzag');
    });
  });
}
