import '../serialization/document_parser.dart';
import '../serialization/excalidraw_json_codec.dart';
import '../serialization/markdraw_document.dart';
import '../serialization/parse_result.dart';
import 'document_format.dart';

/// Platform-agnostic service for loading and saving markdraw documents.
///
/// Takes file read/write functions as parameters (Dependency Inversion),
/// so it can work with any platform's file system without importing dart:io.
class DocumentService {
  final Future<String> Function(String path) readFile;
  final Future<void> Function(String path, String content) writeFile;

  const DocumentService({required this.readFile, required this.writeFile});

  /// Detects the document format from a file path's extension.
  ///
  /// Supported extensions:
  /// - `.markdraw` → [DocumentFormat.markdraw]
  /// - `.excalidraw`, `.json` → [DocumentFormat.excalidraw]
  ///
  /// Throws [ArgumentError] for unrecognized extensions.
  static DocumentFormat detectFormat(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) {
      throw ArgumentError('No file extension found in path: $path');
    }
    final ext = path.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'markdraw':
        return DocumentFormat.markdraw;
      case 'excalidraw':
      case 'json':
        return DocumentFormat.excalidraw;
      default:
        throw ArgumentError('Unsupported file extension: .$ext');
    }
  }

  /// Reads a file, detects its format, and parses it into a [MarkdrawDocument].
  ///
  /// Format is detected from the file extension. Throws if the file cannot
  /// be read or has an unsupported extension.
  Future<ParseResult<MarkdrawDocument>> load(String path) async {
    final format = detectFormat(path);
    final content = await readFile(path);
    switch (format) {
      case DocumentFormat.markdraw:
        return DocumentParser.parse(content);
      case DocumentFormat.excalidraw:
        return ExcalidrawJsonCodec.parse(content);
    }
  }
}
