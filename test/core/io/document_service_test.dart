import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/io/document_format.dart';
import 'package:markdraw/src/core/io/document_service.dart';

void main() {
  group('DocumentFormat.detectFormat', () {
    test('detects .markdraw extension', () {
      expect(
        DocumentService.detectFormat('drawing.markdraw'),
        DocumentFormat.markdraw,
      );
    });

    test('detects .excalidraw extension', () {
      expect(
        DocumentService.detectFormat('drawing.excalidraw'),
        DocumentFormat.excalidraw,
      );
    });

    test('detects .json as excalidraw', () {
      expect(
        DocumentService.detectFormat('drawing.json'),
        DocumentFormat.excalidraw,
      );
    });

    test('handles full path with directories', () {
      expect(
        DocumentService.detectFormat('/home/user/docs/my-diagram.markdraw'),
        DocumentFormat.markdraw,
      );
      expect(
        DocumentService.detectFormat('/tmp/export.excalidraw'),
        DocumentFormat.excalidraw,
      );
    });

    test('is case-insensitive', () {
      expect(
        DocumentService.detectFormat('FILE.MARKDRAW'),
        DocumentFormat.markdraw,
      );
      expect(
        DocumentService.detectFormat('FILE.EXCALIDRAW'),
        DocumentFormat.excalidraw,
      );
      expect(
        DocumentService.detectFormat('FILE.JSON'),
        DocumentFormat.excalidraw,
      );
      expect(
        DocumentService.detectFormat('file.Markdraw'),
        DocumentFormat.markdraw,
      );
    });

    test('throws ArgumentError for unknown extension', () {
      expect(
        () => DocumentService.detectFormat('file.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for no extension', () {
      expect(
        () => DocumentService.detectFormat('noextension'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for .md extension', () {
      expect(
        () => DocumentService.detectFormat('readme.md'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
