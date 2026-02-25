import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('CanvasSettings', () {
    test('default values', () {
      const settings = CanvasSettings();
      expect(settings.formatVersion, 1);
      expect(settings.background, '#ffffff');
      expect(settings.grid, isNull);
    });

    test('custom values', () {
      const settings = CanvasSettings(
        formatVersion: 2,
        background: '#000000',
        grid: 20,
      );
      expect(settings.formatVersion, 2);
      expect(settings.background, '#000000');
      expect(settings.grid, 20);
    });

    test('copyWith replaces fields', () {
      const original = CanvasSettings();
      final modified = original.copyWith(background: '#f0f0f0', grid: 10);
      expect(modified.formatVersion, 1);
      expect(modified.background, '#f0f0f0');
      expect(modified.grid, 10);
    });

    test('copyWith preserves unspecified fields', () {
      const original = CanvasSettings(grid: 20);
      final modified = original.copyWith(background: '#aaa');
      expect(modified.grid, 20);
    });

    test('copyWith can clear grid', () {
      const original = CanvasSettings(grid: 20);
      final modified = original.copyWith(clearGrid: true);
      expect(modified.grid, isNull);
    });

    test('equality based on all fields', () {
      const a = CanvasSettings(background: '#fff', grid: 10);
      const b = CanvasSettings(background: '#fff', grid: 10);
      const c = CanvasSettings(background: '#000', grid: 10);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('isDefault returns true for default settings', () {
      expect(const CanvasSettings().isDefault, isTrue);
    });

    test('isDefault returns false for non-default settings', () {
      expect(const CanvasSettings(grid: 20).isDefault, isFalse);
      expect(const CanvasSettings(background: '#000').isDefault, isFalse);
      expect(const CanvasSettings(formatVersion: 2).isDefault, isFalse);
    });
  });
}
