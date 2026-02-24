import 'dart:convert';
import 'dart:typed_data';

import '../elements/element.dart';
import '../elements/element_id.dart';
import '../elements/image_file.dart';
import '../elements/text_element.dart';
import 'document_section.dart';
import 'frontmatter_parser.dart';
import 'markdraw_document.dart';
import 'parse_result.dart';
import 'sketch_line_parser.dart';

/// Keywords that can have inline labels (e.g., rect "Label" ...).
const _labelableKeywords = {'rect', 'ellipse', 'diamond'};

/// Parses a .markdraw format string into a MarkdrawDocument.
class DocumentParser {
  static ParseResult<MarkdrawDocument> parse(String input) {
    if (input.isEmpty) {
      return ParseResult(value: MarkdrawDocument());
    }

    final allWarnings = <ParseWarning>[];

    // Parse frontmatter
    final fmResult = FrontmatterParser.parse(input);
    allWarnings.addAll(fmResult.warnings);
    final settings = fmResult.value.settings;
    final remaining = fmResult.value.remaining;

    if (remaining.trim().isEmpty) {
      return ParseResult(
        value: MarkdrawDocument(settings: settings),
        warnings: allWarnings,
      );
    }

    // Split into sections (prose vs sketch blocks)
    final sections = <DocumentSection>[];
    final parser = SketchLineParser();
    final lines = remaining.split('\n');

    var i = 0;
    var proseBuffer = StringBuffer();
    final files = <String, ImageFile>{};

    while (i < lines.length) {
      if (lines[i].trim() == '```sketch') {
        // Flush prose
        _flushProse(proseBuffer, sections);
        proseBuffer = StringBuffer();

        // Parse sketch block
        i++;
        final sketchLines = <String>[];
        while (i < lines.length && lines[i].trim() != '```') {
          sketchLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // skip closing ```

        final sketchResult = _parseSketchBlock(
          sketchLines,
          parser,
          allWarnings,
        );
        sections.add(SketchSection(sketchResult));
      } else if (lines[i].trim() == '```files') {
        // Flush prose
        _flushProse(proseBuffer, sections);
        proseBuffer = StringBuffer();

        // Parse files block
        i++;
        while (i < lines.length && lines[i].trim() != '```') {
          final fileLine = lines[i].trim();
          if (fileLine.isNotEmpty) {
            final spaceIdx = fileLine.indexOf(' ');
            if (spaceIdx > 0) {
              final fileId = fileLine.substring(0, spaceIdx);
              final rest = fileLine.substring(spaceIdx + 1);
              final spaceIdx2 = rest.indexOf(' ');
              if (spaceIdx2 > 0) {
                final mimeType = rest.substring(0, spaceIdx2);
                final b64Data = rest.substring(spaceIdx2 + 1);
                try {
                  final bytes = base64Decode(b64Data);
                  files[fileId] = ImageFile(
                    mimeType: mimeType,
                    bytes: Uint8List.fromList(bytes),
                  );
                } catch (_) {
                  allWarnings.add(ParseWarning(
                    line: i + 1,
                    message: 'Invalid base64 data for file $fileId',
                  ));
                }
              }
            }
          }
          i++;
        }
        if (i < lines.length) i++; // skip closing ```
      } else {
        if (proseBuffer.isNotEmpty) proseBuffer.write('\n');
        proseBuffer.write(lines[i]);
        i++;
      }
    }

    _flushProse(proseBuffer, sections);

    // Resolve arrow bindings
    final allElements = <Element>[];
    for (final section in sections) {
      if (section is SketchSection) {
        allElements.addAll(section.elements);
      }
    }

    if (parser.pendingBindings.isNotEmpty) {
      final bindingResult = parser.resolveBindings(allElements);
      allWarnings.addAll(bindingResult.warnings);

      // Replace arrow elements with resolved versions
      final resolvedMap = <String, Element>{};
      for (final resolved in bindingResult.value) {
        resolvedMap[resolved.id.value] = resolved;
      }

      if (resolvedMap.isNotEmpty) {
        final updatedSections = sections.map((section) {
          if (section is SketchSection) {
            final updatedElements = section.elements.map((e) {
              return resolvedMap[e.id.value] ?? e;
            }).toList();
            return SketchSection(updatedElements);
          }
          return section;
        }).toList();
        sections
          ..clear()
          ..addAll(updatedSections);
      }
    }

    return ParseResult(
      value: MarkdrawDocument(
        settings: settings,
        sections: sections,
        aliases: Map.from(parser.aliases),
        files: files,
      ),
      warnings: allWarnings,
    );
  }

  static void _flushProse(
    StringBuffer buffer,
    List<DocumentSection> sections,
  ) {
    final content = buffer.toString();
    if (content.isNotEmpty) {
      sections.add(ProseSection(content));
    }
  }

  static List<Element> _parseSketchBlock(
    List<String> lines,
    SketchLineParser parser,
    List<ParseWarning> warnings,
  ) {
    final elements = <Element>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // Check for inline label on shapes: keyword "Label" ...
      // Only applies to shape types (not text, which naturally has quotes)
      final labelMatch = RegExp(
        r'^(\w+)\s+"([^"]+)"\s+(.*)',
      ).firstMatch(line);

      if (labelMatch != null &&
          _labelableKeywords.contains(labelMatch.group(1)!.toLowerCase())) {
        final keyword = labelMatch.group(1)!;
        final label = labelMatch.group(2)!;
        final rest = labelMatch.group(3)!;

        // Parse the shape without the label
        final shapeLine = '$keyword $rest';
        final result = parser.parseLine(shapeLine, i + 1);
        warnings.addAll(result.warnings);

        if (result.value != null) {
          elements.add(result.value!);

          // Create bound text element
          final textElement = TextElement(
            id: ElementId.generate(),
            x: result.value!.x,
            y: result.value!.y,
            width: result.value!.width,
            height: 20,
            text: label,
            containerId: result.value!.id.value,
            seed: result.value!.seed + 1,
          );
          elements.add(textElement);
        }
      } else {
        final result = parser.parseLine(line, i + 1);
        warnings.addAll(result.warnings);
        if (result.value != null) {
          elements.add(result.value!);
        }
      }
    }

    return elements;
  }
}
