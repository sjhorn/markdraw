import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/ui/markdraw_grammar.dart';
import 'package:re_highlight/re_highlight.dart';

void main() {
  late Highlight hl;

  setUpAll(() {
    hl = Highlight();
    hl.registerLanguage('markdraw', langMarkdraw);
  });

  group('langMarkdraw Mode', () {
    test('is a valid Mode with name', () {
      expect(langMarkdraw, isA<Mode>());
      expect(langMarkdraw.name, 'markdraw');
    });

    test('contains sub-modes', () {
      expect(langMarkdraw.contains, isNotNull);
      expect(langMarkdraw.contains, isNotEmpty);
    });
  });

  group('markdraw highlighting', () {
    String html(String code) =>
        hl.highlight(code: code, language: 'markdraw').toHtml();

    test('parses element keywords', () {
      expect(html('rect at 0,0 100x50'), contains('keyword'));
    });

    test('parses all element keywords', () {
      for (final kw in [
        'rect', 'ellipse', 'diamond', 'line', 'arrow',
        'text', 'freedraw', 'frame', 'image',
      ]) {
        expect(html(kw), contains('keyword'),
            reason: '$kw should be highlighted as keyword');
      }
    });

    test('parses position keywords', () {
      expect(html('arrow from r1 to r2'), contains('keyword'));
    });

    test('parses quoted strings', () {
      expect(html('rect "Hello World" at 0,0 100x50'), contains('string'));
    });

    test('parses property keys', () {
      expect(html('fill=red stroke=dashed'), contains('attr'));
    });

    test('parses hex colors', () {
      expect(html('fill=#ff0000'), contains('number'));
    });

    test('parses dimensions', () {
      expect(html('rect at 0,0 100x50'), contains('number'));
    });

    test('parses comments', () {
      expect(html('# this is a comment'), contains('comment'));
    });

    test('parses numbers', () {
      expect(html('at 100,200'), contains('number'));
    });

    test('parses multiline input', () {
      final result = html('rect id=r1 at 0,0 100x50\narrow from r1 to r2');
      expect(result, contains('keyword'));
    });

    test('handles empty string', () {
      final result = html('');
      expect(result, isNotNull);
    });

    test('parses hyphenated property keys as attr, not keyword', () {
      final result = html('text-font=Nunito');
      // text-font should be highlighted as attr, not split into keyword + junk
      expect(result, contains('attr'));
      // 'text' should NOT be highlighted as a keyword here
      expect(result, isNot(contains('keyword')));
    });

    test('text keyword still works standalone', () {
      final result = html('text "Hello" at 0,0 100x50');
      expect(result, contains('keyword'));
    });

    test('produces rich output for complex line', () {
      final result =
          html('rect "Label" id=r1 at 10,20 50x60 fill=#ff0000 locked');
      expect(result, contains('keyword'));
      expect(result, contains('string'));
      expect(result, contains('attr'));
      expect(result, contains('number'));
    });

    test('font=hand-drawn highlights key as attr and value as string', () {
      final result = html('font=hand-drawn');
      expect(result, contains('attr'));
      expect(result, contains('string'));
    });

    test('font-size=small highlights key as attr and value as string', () {
      final result = html('font-size=small');
      expect(result, contains('attr'));
      expect(result, contains('string'));
    });

    test('font-size=xl highlights value as string', () {
      final result = html('font-size=xl');
      expect(result, contains('string'));
    });

    test('quoted property value after = highlights as string', () {
      final result = html('font="Lilita One"');
      expect(result, contains('attr'));
      expect(result, contains('string'));
    });

    test('known value aliases all highlight as string', () {
      for (final alias in [
        'hand-drawn', 'normal', 'code',
        'small', 'medium', 'large', 'extra-large',
        's', 'm', 'l', 'xl',
      ]) {
        final result = html('prop=$alias');
        expect(result, contains('string'),
            reason: '$alias should highlight as string');
      }
    });
  });
}
