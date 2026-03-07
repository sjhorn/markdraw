import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart' hide TextAlign;

/// Tests for sketch line extraction logic used by MarkdrawSplitPane.
///
/// The _extractSketchLines method is private, so we test the same logic
/// with a standalone function.
String extractSketchLines(String fullText) {
  final lines = fullText.split('\n');
  final buffer = StringBuffer();
  var inSketch = false;
  for (final line in lines) {
    if (line.trim() == '```markdraw') {
      inSketch = true;
      continue;
    }
    if (line.trim() == '```' && inSketch) {
      inSketch = false;
      continue;
    }
    if (inSketch) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
    }
  }
  return buffer.toString();
}

void main() {
  group('extractSketchLines', () {
    test('extracts lines from simple document', () {
      const doc = '---\nmarkdraw: 1\n---\n\n```markdraw\nrect at 0,0 100x50\n```';
      expect(extractSketchLines(doc), 'rect at 0,0 100x50');
    });

    test('extracts multiple element lines', () {
      const doc = '```markdraw\n'
          'rect id=r1 at 0,0 100x50\n'
          'ellipse id=e1 at 200,100 80x80\n'
          'arrow from r1 to e1\n'
          '```';
      expect(
        extractSketchLines(doc),
        'rect id=r1 at 0,0 100x50\n'
        'ellipse id=e1 at 200,100 80x80\n'
        'arrow from r1 to e1',
      );
    });

    test('strips frontmatter', () {
      const doc = '---\nmarkdraw: 1\nbackground: "#ffffff"\n---\n\n'
          '```markdraw\nrect at 10,20 30x40\n```';
      expect(extractSketchLines(doc), 'rect at 10,20 30x40');
    });

    test('strips files block', () {
      const doc = '```markdraw\nimage id=i at 0,0 100x100 file=abc\n```\n\n'
          '```files\nabc image/png AQIDBA==\n```';
      expect(
        extractSketchLines(doc),
        'image id=i at 0,0 100x100 file=abc',
      );
    });

    test('returns empty string when no sketch block', () {
      const doc = '---\nmarkdraw: 1\n---\n\nSome prose.';
      expect(extractSketchLines(doc), '');
    });

    test('returns empty string for empty input', () {
      expect(extractSketchLines(''), '');
    });

    test('preserves empty lines within sketch block', () {
      const doc = '```markdraw\nrect at 0,0 100x50\n\narrow from r1 to r2\n```';
      expect(
        extractSketchLines(doc),
        'rect at 0,0 100x50\n\narrow from r1 to r2',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Parse status — tests the DocumentParser.parse() behavior that drives
  // the status bar in _syncTextToCanvas.
  // ---------------------------------------------------------------------------

  /// Wraps sketch lines with frontmatter + fences, same as _syncTextToCanvas.
  ParseResult<MarkdrawDocument> parseSketchText(String text) {
    final wrapped = '---\nmarkdraw: 1\nbackground: "#ffffff"\n---\n\n'
        '```markdraw\n$text\n```';
    return DocumentParser.parse(wrapped);
  }

  group('parse status', () {
    test('valid input produces no warnings', () {
      final result = parseSketchText('rect at 0,0 100x50');
      expect(result.warnings, isEmpty);
    });

    test('unknown keyword produces a warning', () {
      final result = parseSketchText('bogus at 0,0 100x50');
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first.message,
        contains('Unknown keyword'),
      );
    });

    test('multiple unknown keywords produce multiple warnings', () {
      final result = parseSketchText('foo at 0,0 100x50\nbar at 1,1 50x50');
      expect(result.warnings.length, 2);
    });

    test('valid lines mixed with unknown keywords', () {
      final result = parseSketchText(
        'rect at 0,0 100x50\nbogus at 1,1 50x50\nellipse at 200,100 80x80',
      );
      expect(result.warnings.length, 1);
      // Valid elements still parsed
      final elements = result.value.sections
          .whereType<SketchSection>()
          .expand((s) => s.elements)
          .toList();
      expect(elements.length, 2);
    });

    test('unresolved arrow alias produces warning', () {
      final result = parseSketchText('arrow from nonexistent to nowhere');
      expect(
        result.warnings.any((w) => w.message.contains('Unresolved alias')),
        isTrue,
      );
    });

    test('empty text produces no warnings', () {
      final result = DocumentParser.parse('');
      expect(result.warnings, isEmpty);
    });

    test('warnings include line numbers', () {
      final result = parseSketchText('bogus at 0,0 100x50');
      expect(result.warnings.first.line, greaterThan(0));
    });
  });
}
