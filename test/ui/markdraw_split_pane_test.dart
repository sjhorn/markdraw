import 'package:flutter_test/flutter_test.dart';

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
}
