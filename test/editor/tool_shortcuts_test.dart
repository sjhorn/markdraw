import 'package:markdraw/markdraw.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toolTypeForKey', () {
    test('1 maps to select', () {
      expect(toolTypeForKey('1'), ToolType.select);
    });

    test('2 maps to rectangle', () {
      expect(toolTypeForKey('2'), ToolType.rectangle);
    });

    test('3 maps to diamond', () {
      expect(toolTypeForKey('3'), ToolType.diamond);
    });

    test('4 maps to ellipse', () {
      expect(toolTypeForKey('4'), ToolType.ellipse);
    });

    test('5 maps to arrow', () {
      expect(toolTypeForKey('5'), ToolType.arrow);
    });

    test('6 maps to line', () {
      expect(toolTypeForKey('6'), ToolType.line);
    });

    test('7 maps to freedraw', () {
      expect(toolTypeForKey('7'), ToolType.freedraw);
    });

    test('8 maps to text', () {
      expect(toolTypeForKey('8'), ToolType.text);
    });

    test('f maps to frame', () {
      expect(toolTypeForKey('f'), ToolType.frame);
    });

    test('h maps to hand', () {
      expect(toolTypeForKey('h'), ToolType.hand);
    });

    test('9 is reserved (returns null)', () {
      expect(toolTypeForKey('9'), isNull);
    });

    test('0 maps to eraser', () {
      expect(toolTypeForKey('0'), ToolType.eraser);
    });

    test('unknown key returns null', () {
      expect(toolTypeForKey('x'), isNull);
      expect(toolTypeForKey('z'), isNull);
      expect(toolTypeForKey(' '), isNull);
    });

    test('letter aliases map to tools', () {
      expect(toolTypeForKey('v'), ToolType.select);
      expect(toolTypeForKey('r'), ToolType.rectangle);
      expect(toolTypeForKey('d'), ToolType.diamond);
      expect(toolTypeForKey('o'), ToolType.ellipse);
      expect(toolTypeForKey('a'), ToolType.arrow);
      expect(toolTypeForKey('l'), ToolType.line);
      expect(toolTypeForKey('p'), ToolType.freedraw);
      expect(toolTypeForKey('t'), ToolType.text);
      expect(toolTypeForKey('e'), ToolType.eraser);
    });

    test('all ToolType values have a shortcut', () {
      final reachable = <ToolType>{};
      for (final c in '1234567890fhvrdoalpt ek'.split('')) {
        final t = toolTypeForKey(c);
        if (t != null) reachable.add(t);
      }
      for (final type in ToolType.values) {
        expect(reachable, contains(type),
            reason: '${type.name} has no keyboard shortcut');
      }
    });
  });

  group('shortcutForToolType', () {
    test('every tool type has a shortcut label', () {
      for (final type in ToolType.values) {
        expect(shortcutForToolType(type), isNotNull,
            reason: '${type.name} should have a shortcut');
      }
    });

    test('shortcut round-trips with toolTypeForKey', () {
      for (final type in ToolType.values) {
        final key = shortcutForToolType(type)!.toLowerCase();
        expect(toolTypeForKey(key), type,
            reason: 'shortcut "$key" should map back to ${type.name}');
      }
    });
  });
}
