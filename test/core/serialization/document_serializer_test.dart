import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  group('DocumentSerializer', () {
    test('empty document with default settings', () {
      final doc = MarkdrawDocument();
      final output = DocumentSerializer.serialize(doc);
      expect(output, '');
    });

    test('document with only frontmatter', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(grid: 20),
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('---'));
      expect(output, contains('markdraw: 1'));
      expect(output, contains('grid: 20'));
    });

    test('document with prose section', () {
      final doc = MarkdrawDocument(
        sections: [const ProseSection('# Title\n\nSome text')],
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('# Title'));
      expect(output, contains('Some text'));
    });

    test('document with sketch section', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [SketchSection([rect])],
        aliases: {'auth': 'r1'},
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('```sketch'));
      expect(output, contains('rect id=auth'));
      expect(output, contains('```'));
    });

    test('document with interleaved prose and sketch', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [
          const ProseSection('# Architecture'),
          SketchSection([rect]),
          const ProseSection('More details here.'),
        ],
        aliases: {'auth': 'r1'},
      );
      final output = DocumentSerializer.serialize(doc);
      final lines = output.split('\n');

      // Check order: prose, then sketch block, then prose
      final archIdx = lines.indexWhere((l) => l.contains('# Architecture'));
      final sketchStartIdx = lines.indexWhere((l) => l == '```sketch');
      final sketchEndIdx = lines.indexWhere(
        (l) => l == '```',
        sketchStartIdx + 1,
      );
      final detailsIdx = lines.indexWhere((l) => l.contains('More details'));

      expect(archIdx, lessThan(sketchStartIdx));
      expect(sketchStartIdx, lessThan(sketchEndIdx));
      expect(sketchEndIdx, lessThan(detailsIdx));
    });

    test('frontmatter emitted before sections', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(grid: 20),
        sections: [const ProseSection('content')],
      );
      final output = DocumentSerializer.serialize(doc);
      final fmEnd = output.indexOf('---\n', 4);
      final contentIdx = output.indexOf('content');
      expect(fmEnd, lessThan(contentIdx));
    });

    test('document with bound text labels', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 42,
        versionNonce: 1,
        updated: 0,
      );
      final label = TextElement(
        id: const ElementId('t1'),
        x: 110,
        y: 210,
        width: 140,
        height: 20,
        text: 'Auth Service',
        containerId: 'r1',
        seed: 43,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [SketchSection([rect, label])],
        aliases: {'auth': 'r1'},
      );
      final output = DocumentSerializer.serialize(doc);
      // Bound text should be inlined as label on the shape
      expect(output, contains('rect "Auth Service" id=auth'));
      // The bound text element should NOT appear as a separate line
      final sketchLines = _extractSketchLines(output);
      expect(
        sketchLines.where((l) => l.startsWith('text ')),
        isEmpty,
      );
    });

    test('unbound text appears as separate text line', () {
      final text = TextElement(
        id: const ElementId('t1'),
        x: 100,
        y: 50,
        width: 200,
        height: 30,
        text: 'Standalone text',
        seed: 5,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [SketchSection([text])],
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('text "Standalone text"'));
    });

    test('arrow with bindings uses from/to', () {
      final rect1 = RectangleElement(
        id: const ElementId('r1'),
        x: 100,
        y: 200,
        width: 160,
        height: 80,
        seed: 1,
        versionNonce: 1,
        updated: 0,
      );
      final rect2 = RectangleElement(
        id: const ElementId('r2'),
        x: 350,
        y: 200,
        width: 160,
        height: 80,
        seed: 2,
        versionNonce: 1,
        updated: 0,
      );
      final arrow = ArrowElement(
        id: const ElementId('a1'),
        x: 260,
        y: 240,
        width: 90,
        height: 0,
        points: [const Point(0, 0), const Point(90, 0)],
        startBinding: const PointBinding(
          elementId: 'r1',
          fixedPoint: Point(1, 0.5),
        ),
        endBinding: const PointBinding(
          elementId: 'r2',
          fixedPoint: Point(0, 0.5),
        ),
        seed: 3,
        versionNonce: 1,
        updated: 0,
      );
      final doc = MarkdrawDocument(
        sections: [SketchSection([rect1, rect2, arrow])],
        aliases: {'auth': 'r1', 'gateway': 'r2'},
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('from auth'));
      expect(output, contains('to gateway'));
    });

    test('non-default frontmatter background uses quotes', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(background: '#e0e0e0'),
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('background: "#e0e0e0"'));
    });

    test('default frontmatter is omitted for empty document', () {
      final doc = MarkdrawDocument();
      final output = DocumentSerializer.serialize(doc);
      expect(output, isNot(contains('---')));
    });

    test('frontmatter always emitted when non-default', () {
      final doc = MarkdrawDocument(
        settings: const CanvasSettings(background: '#000'),
      );
      final output = DocumentSerializer.serialize(doc);
      expect(output, contains('---'));
      expect(output, contains('markdraw: 1'));
    });
  });
}

List<String> _extractSketchLines(String output) {
  final lines = output.split('\n');
  final result = <String>[];
  var inSketch = false;
  for (final line in lines) {
    if (line == '```sketch') {
      inSketch = true;
      continue;
    }
    if (line == '```' && inSketch) {
      inSketch = false;
      continue;
    }
    if (inSketch) result.add(line);
  }
  return result;
}
