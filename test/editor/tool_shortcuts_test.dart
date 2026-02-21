import 'package:markdraw/src/editor/tool_shortcuts.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toolTypeForKey', () {
    test('v maps to select', () {
      expect(toolTypeForKey('v'), ToolType.select);
    });

    test('r maps to rectangle', () {
      expect(toolTypeForKey('r'), ToolType.rectangle);
    });

    test('e maps to ellipse', () {
      expect(toolTypeForKey('e'), ToolType.ellipse);
    });

    test('d maps to diamond', () {
      expect(toolTypeForKey('d'), ToolType.diamond);
    });

    test('l maps to line', () {
      expect(toolTypeForKey('l'), ToolType.line);
    });

    test('a maps to arrow', () {
      expect(toolTypeForKey('a'), ToolType.arrow);
    });

    test('p maps to freedraw', () {
      expect(toolTypeForKey('p'), ToolType.freedraw);
    });

    test('t maps to text', () {
      expect(toolTypeForKey('t'), ToolType.text);
    });

    test('h maps to hand', () {
      expect(toolTypeForKey('h'), ToolType.hand);
    });

    test('unknown key returns null', () {
      expect(toolTypeForKey('x'), isNull);
      expect(toolTypeForKey('z'), isNull);
      expect(toolTypeForKey('1'), isNull);
      expect(toolTypeForKey(' '), isNull);
    });

    test('uppercase keys return null', () {
      expect(toolTypeForKey('V'), isNull);
      expect(toolTypeForKey('R'), isNull);
      expect(toolTypeForKey('E'), isNull);
      expect(toolTypeForKey('D'), isNull);
      expect(toolTypeForKey('L'), isNull);
      expect(toolTypeForKey('A'), isNull);
      expect(toolTypeForKey('P'), isNull);
      expect(toolTypeForKey('T'), isNull);
      expect(toolTypeForKey('H'), isNull);
    });

    test('all ToolType values have a shortcut', () {
      // Verify every ToolType is reachable via some key
      final reachable = <ToolType>{};
      for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        final t = toolTypeForKey(c);
        if (t != null) reachable.add(t);
      }
      for (final type in ToolType.values) {
        expect(reachable, contains(type),
            reason: '${type.name} has no keyboard shortcut');
      }
    });
  });
}
