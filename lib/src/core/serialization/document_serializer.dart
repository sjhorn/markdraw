import '../elements/element.dart';
import '../elements/text_element.dart';
import 'document_section.dart';
import 'markdraw_document.dart';
import 'sketch_line_serializer.dart';

/// Serializes a MarkdrawDocument to a .markdraw format string.
class DocumentSerializer {
  /// Serialize a complete document to .markdraw format.
  static String serialize(MarkdrawDocument doc) {
    final buffer = StringBuffer();
    final hasContent = doc.sections.isNotEmpty;

    // Frontmatter
    if (!doc.settings.isDefault) {
      buffer.writeln('---');
      buffer.writeln('markdraw: ${doc.settings.formatVersion}');
      buffer.writeln('background: "${doc.settings.background}"');
      if (doc.settings.grid != null) {
        buffer.writeln('grid: ${doc.settings.grid}');
      }
      buffer.writeln('---');
      if (hasContent) {
        buffer.writeln();
      }
    }

    // Sections
    for (var i = 0; i < doc.sections.length; i++) {
      final section = doc.sections[i];
      switch (section) {
        case ProseSection():
          buffer.write(section.content);
        case SketchSection():
          _serializeSketch(buffer, section, doc);
      }

      // Add separator between sections
      if (i < doc.sections.length - 1) {
        buffer.writeln();
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  static void _serializeSketch(
    StringBuffer buffer,
    SketchSection section,
    MarkdrawDocument doc,
  ) {
    // Build reverse alias map: element ID → alias
    final reverseAliases = <String, String>{};
    for (final entry in doc.aliases.entries) {
      reverseAliases[entry.value] = entry.key;
    }

    // Find bound text elements (those with containerId)
    final boundTextMap = <String, TextElement>{};
    for (final element in section.elements) {
      if (element is TextElement && element.containerId != null) {
        boundTextMap[element.containerId!] = element;
      }
    }

    final serializer = SketchLineSerializer();
    buffer.writeln('```sketch');

    for (final element in section.elements) {
      // Skip bound text — it's inlined on the parent shape
      if (element is TextElement && element.containerId != null) {
        continue;
      }

      final alias = reverseAliases[element.id.value];
      final boundText = boundTextMap[element.id.value];

      if (boundText != null) {
        // Serialize shape with label inlined
        final line = serializer.serializeWithLabel(
          element,
          boundText.text,
          alias: alias,
          aliasMap: reverseAliases,
        );
        buffer.writeln(line);
      } else {
        final line = serializer.serialize(
          element,
          alias: alias,
          aliasMap: reverseAliases,
        );
        buffer.writeln(line);
      }
    }

    buffer.write('```');
  }
}
