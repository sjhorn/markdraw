import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/ui/markdraw_autocomplete.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('markdrawPrompts', () {
    test('is non-empty', () {
      expect(markdrawPrompts, isNotEmpty);
    });

    test('contains element keywords', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      for (final kw in [
        'rect', 'ellipse', 'diamond', 'line', 'arrow',
        'text', 'freedraw', 'frame', 'image',
      ]) {
        expect(words, contains(kw), reason: 'missing element keyword: $kw');
      }
    });

    test('contains position keywords', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      expect(words, contains('from'));
      expect(words, contains('to'));
      expect(words, contains('at'));
    });

    test('contains property keys', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      for (final key in [
        'id', 'fill', 'color', 'stroke', 'fill-style', 'stroke-width',
        'roughness', 'opacity', 'angle', 'group', 'file', 'crop', 'scale',
      ]) {
        expect(words, contains(key), reason: 'missing property key: $key');
      }
    });

    test('contains property values', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      for (final val in [
        'solid', 'dashed', 'dotted', 'hachure', 'cross-hatch', 'zigzag',
        'left', 'center', 'right', 'top', 'middle', 'bottom',
      ]) {
        expect(words, contains(val), reason: 'missing property value: $val');
      }
    });

    test('contains arrowhead values', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      for (final val in ['arrow', 'bar', 'dot', 'triangle']) {
        expect(words, contains(val), reason: 'missing arrowhead: $val');
      }
    });

    test('contains flags', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      expect(words, contains('locked'));
      expect(words, contains('closed'));
      expect(words, contains('no-simulate-pressure'));
    });

    test('contains common color names', () {
      final words = markdrawPrompts.map((p) => p.word).toSet();
      for (final c in ['red', 'blue', 'green', 'black', 'white']) {
        expect(words, contains(c), reason: 'missing color: $c');
      }
    });

    test('all prompts are CodeKeywordPrompt instances', () {
      for (final prompt in markdrawPrompts) {
        expect(prompt, isA<CodeKeywordPrompt>());
      }
    });
  });

  group('prompt matching', () {
    test('prompt matches prefix', () {
      final rectPrompt = markdrawPrompts.firstWhere((p) => p.word == 'rect');
      expect(rectPrompt.match('re'), isTrue);
      expect(rectPrompt.match('rec'), isTrue);
      expect(rectPrompt.match('r'), isTrue);
    });

    test('prompt does not match full word', () {
      final rectPrompt = markdrawPrompts.firstWhere((p) => p.word == 'rect');
      expect(rectPrompt.match('rect'), isFalse);
    });

    test('prompt does not match non-prefix', () {
      final rectPrompt = markdrawPrompts.firstWhere((p) => p.word == 'rect');
      expect(rectPrompt.match('ec'), isFalse);
      expect(rectPrompt.match('xyz'), isFalse);
    });

    test('multiple prompts can match same prefix', () {
      final matches =
          markdrawPrompts.where((p) => p.match('re')).toList();
      expect(matches.length, greaterThanOrEqualTo(2)); // rect, red
    });
  });
}
