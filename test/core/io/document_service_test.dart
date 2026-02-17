import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/io/document_format.dart';
import 'package:markdraw/src/core/io/document_service.dart';

/// In-memory file system for testing.
Map<String, String> _createFileSystem([Map<String, String>? initial]) {
  return Map<String, String>.from(initial ?? {});
}

DocumentService _createService(Map<String, String> fs) {
  return DocumentService(
    readFile: (path) async {
      if (!fs.containsKey(path)) {
        throw Exception('File not found: $path');
      }
      return fs[path]!;
    },
    writeFile: (path, content) async {
      fs[path] = content;
    },
  );
}

const _markdrawContent = '''```sketch
rect id=r1 at 10,20 size 100x50
```''';

String _excalidrawContent() {
  return jsonEncode({
    'type': 'excalidraw',
    'version': 2,
    'source': 'test',
    'elements': [
      {
        'id': 'rect1',
        'type': 'rectangle',
        'x': 10,
        'y': 20,
        'width': 100,
        'height': 50,
        'angle': 0,
        'strokeColor': '#000000',
        'backgroundColor': 'transparent',
        'fillStyle': 'solid',
        'strokeWidth': 2,
        'strokeStyle': 'solid',
        'roughness': 1,
        'opacity': 100,
        'seed': 42,
        'version': 1,
        'versionNonce': 123,
        'isDeleted': false,
        'groupIds': <String>[],
        'boundElements': null,
        'updated': 1000000,
        'locked': false,
      },
    ],
    'appState': <String, dynamic>{},
    'files': <String, dynamic>{},
  });
}

void main() {
  group('DocumentService.detectFormat', () {
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

  group('DocumentService.load', () {
    test('loads .markdraw file and parses elements', () async {
      final fs = _createFileSystem({
        '/docs/diagram.markdraw': _markdrawContent,
      });
      final service = _createService(fs);

      final result = await service.load('/docs/diagram.markdraw');
      final elements = result.value.allElements;

      expect(elements, hasLength(1));
      expect(elements.first, isA<RectangleElement>());
      expect(elements.first.x, 10);
      expect(elements.first.y, 20);
      expect(elements.first.width, 100);
      expect(elements.first.height, 50);
    });

    test('loads .excalidraw file and parses elements', () async {
      final fs = _createFileSystem({
        '/docs/diagram.excalidraw': _excalidrawContent(),
      });
      final service = _createService(fs);

      final result = await service.load('/docs/diagram.excalidraw');
      final elements = result.value.allElements;

      expect(elements, hasLength(1));
      expect(elements.first, isA<RectangleElement>());
      expect(elements.first.x, 10);
      expect(elements.first.y, 20);
    });

    test('loads .json file as excalidraw format', () async {
      final fs = _createFileSystem({
        '/docs/diagram.json': _excalidrawContent(),
      });
      final service = _createService(fs);

      final result = await service.load('/docs/diagram.json');

      expect(result.value.allElements, hasLength(1));
    });

    test('forwards parse warnings from excalidraw import', () async {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'source': 'test',
        'elements': [
          {
            'id': 'img1',
            'type': 'image',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
          },
        ],
        'appState': <String, dynamic>{},
        'files': <String, dynamic>{},
      });
      final fs = _createFileSystem({'/docs/file.excalidraw': json});
      final service = _createService(fs);

      final result = await service.load('/docs/file.excalidraw');

      expect(result.hasWarnings, isTrue);
      expect(result.warnings.first.message, contains('image'));
    });

    test('propagates readFile errors naturally', () async {
      final fs = _createFileSystem(); // empty
      final service = _createService(fs);

      expect(
        () => service.load('/docs/missing.markdraw'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
