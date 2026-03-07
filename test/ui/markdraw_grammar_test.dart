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

    test('produces rich output for complex line', () {
      final result =
          html('rect "Label" id=r1 at 10,20 50x60 fill=#ff0000 locked');
      expect(result, contains('keyword'));
      expect(result, contains('string'));
      expect(result, contains('attr'));
      expect(result, contains('number'));
    });
  });
}
