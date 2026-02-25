import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

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
            'id': 'mf1',
            'type': 'magicframe',
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
      expect(result.warnings.first.message, contains('magicframe'));
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

  group('DocumentService.save', () {
    late Map<String, String> fs;
    late DocumentService service;
    late MarkdrawDocument doc;

    setUp(() {
      fs = _createFileSystem();
      service = _createService(fs);
      doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 10,
              y: 20,
              width: 100,
              height: 50,
            ),
          ]),
        ],
      );
    });

    test('saves as .markdraw format', () async {
      await service.save(doc, '/docs/output.markdraw');

      expect(fs.containsKey('/docs/output.markdraw'), isTrue);
      final content = fs['/docs/output.markdraw']!;
      expect(content, contains('rect'));
      expect(content, contains('sketch'));
    });

    test('saves as .excalidraw format', () async {
      await service.save(doc, '/docs/output.excalidraw');

      expect(fs.containsKey('/docs/output.excalidraw'), isTrue);
      final content = fs['/docs/output.excalidraw']!;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['type'], 'excalidraw');
      expect(decoded['elements'], hasLength(1));
      expect(decoded['elements'][0]['type'], 'rectangle');
    });

    test('format override saves markdraw doc as excalidraw', () async {
      await service.save(
        doc,
        '/docs/output.markdraw',
        format: DocumentFormat.excalidraw,
      );

      final content = fs['/docs/output.markdraw']!;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['type'], 'excalidraw');
    });

    test('save then load round-trip preserves elements', () async {
      await service.save(doc, '/docs/rt.markdraw');
      final result = await service.load('/docs/rt.markdraw');
      final loaded = result.value.allElements;

      expect(loaded, hasLength(1));
      expect(loaded.first, isA<RectangleElement>());
      expect(loaded.first.x, 10);
      expect(loaded.first.y, 20);
      expect(loaded.first.width, 100);
      expect(loaded.first.height, 50);
    });
  });

  group('DocumentService.convert', () {
    late Map<String, String> fs;
    late DocumentService service;

    setUp(() {
      fs = _createFileSystem();
      service = _createService(fs);
    });

    test('converts .excalidraw to .markdraw', () async {
      fs['/input.excalidraw'] = _excalidrawContent();

      final result = await service.convert(
        '/input.excalidraw',
        '/output.markdraw',
      );

      expect(result.value.allElements, hasLength(1));
      expect(fs.containsKey('/output.markdraw'), isTrue);

      // Verify output is valid .markdraw
      final reloaded = await service.load('/output.markdraw');
      expect(reloaded.value.allElements, hasLength(1));
      expect(reloaded.value.allElements.first, isA<RectangleElement>());
    });

    test('converts .markdraw to .excalidraw', () async {
      fs['/input.markdraw'] = _markdrawContent;

      final result = await service.convert(
        '/input.markdraw',
        '/output.excalidraw',
      );

      expect(result.value.allElements, hasLength(1));
      expect(fs.containsKey('/output.excalidraw'), isTrue);

      // Verify output is valid .excalidraw JSON
      final reloaded = await service.load('/output.excalidraw');
      expect(reloaded.value.allElements, hasLength(1));
      expect(reloaded.value.allElements.first, isA<RectangleElement>());
    });

    test('convert returns ParseResult with import warnings', () async {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'source': 'test',
        'elements': [
          {
            'id': 'mf1',
            'type': 'magicframe',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'rect1',
            'type': 'rectangle',
            'x': 10,
            'y': 20,
            'width': 50,
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
            'versionNonce': 0,
            'isDeleted': false,
            'groupIds': <String>[],
            'boundElements': null,
            'updated': 0,
            'locked': false,
          },
        ],
        'appState': <String, dynamic>{},
        'files': <String, dynamic>{},
      });
      fs['/input.excalidraw'] = json;

      final result = await service.convert(
        '/input.excalidraw',
        '/output.markdraw',
      );

      expect(result.hasWarnings, isTrue);
      expect(result.warnings.first.message, contains('magicframe'));
      // The supported rect should still be converted
      expect(result.value.allElements, hasLength(1));
    });

    test('converts all 7 element types from excalidraw to markdraw', () async {
      fs['/input.excalidraw'] = _allElementsExcalidraw();

      final result = await service.convert(
        '/input.excalidraw',
        '/output.markdraw',
      );

      final elements = result.value.allElements;
      expect(elements, hasLength(7));

      // Verify each type is present (ArrowElement extends LineElement,
      // so we check exact type for Line)
      expect(elements.whereType<RectangleElement>(), hasLength(1));
      expect(elements.whereType<EllipseElement>(), hasLength(1));
      expect(elements.whereType<DiamondElement>(), hasLength(1));
      expect(elements.whereType<TextElement>(), hasLength(1));
      expect(elements.where((e) => e.type == 'line'), hasLength(1));
      expect(elements.whereType<ArrowElement>(), hasLength(1));
      expect(elements.whereType<FreedrawElement>(), hasLength(1));

      // Reload the .markdraw output and verify
      final reloaded = await service.load('/output.markdraw');
      final reloadedElements = reloaded.value.allElements;
      expect(reloadedElements, hasLength(7));

      _expectElementsMatch(elements, reloadedElements);
    });

    test('converts all 7 element types from markdraw to excalidraw', () async {
      fs['/input.markdraw'] = _allElementsMarkdraw();

      final result = await service.convert(
        '/input.markdraw',
        '/output.excalidraw',
      );

      final elements = result.value.allElements;
      expect(elements, hasLength(7));

      // Reload the .excalidraw output and verify
      final reloaded = await service.load('/output.excalidraw');
      final reloadedElements = reloaded.value.allElements;
      expect(reloadedElements, hasLength(7));

      _expectElementsMatch(elements, reloadedElements);
    });
  });
}

/// Excalidraw JSON with all 7 element types.
String _allElementsExcalidraw() {
  Map<String, dynamic> base(String id, String type) => {
        'id': id,
        'type': type,
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
        'versionNonce': 0,
        'isDeleted': false,
        'groupIds': <String>[],
        'boundElements': null,
        'updated': 0,
        'locked': false,
      };

  return jsonEncode({
    'type': 'excalidraw',
    'version': 2,
    'source': 'test',
    'elements': [
      base('r1', 'rectangle'),
      base('e1', 'ellipse'),
      base('d1', 'diamond'),
      {
        ...base('t1', 'text'),
        'text': 'Hello',
        'fontSize': 20,
        'fontFamily': 1,
        'textAlign': 'left',
        'lineHeight': 1.25,
        'autoResize': true,
        'originalText': 'Hello',
        'verticalAlign': 'top',
      },
      {
        ...base('l1', 'line'),
        'points': [
          [0, 0],
          [100, 50],
        ],
      },
      {
        ...base('a1', 'arrow'),
        'points': [
          [0, 0],
          [200, 100],
        ],
        'startArrowhead': null,
        'endArrowhead': 'arrow',
      },
      {
        ...base('f1', 'freedraw'),
        'points': [
          [0, 0],
          [5, 2],
          [10, 8],
        ],
        'pressures': [0.5, 0.7, 0.9],
        'simulatePressure': false,
      },
    ],
    'appState': <String, dynamic>{},
    'files': <String, dynamic>{},
  });
}

/// Markdraw format with all 7 element types.
String _allElementsMarkdraw() {
  return '''```sketch
rect id=r1 at 10,20 size 100x50 seed=42
ellipse id=e1 at 10,20 size 100x50 seed=43
diamond id=d1 at 10,20 size 100x50 seed=44
text "Hello" at 10,20 size 100x50 seed=45
line points=[[0,0],[100,50]] at 10,20 size 100x50 seed=46
arrow points=[[0,0],[200,100]] at 10,20 size 100x50 seed=47 endArrowhead=arrow
freedraw points=[[0,0],[5,2],[10,8]] pressure=[0.5,0.7,0.9] at 10,20 size 100x50 seed=48
```''';
}

/// Verifies that two element lists have matching types and geometry.
///
/// Only geometric shapes (rect, ellipse, diamond) and text serialize
/// position through the .markdraw format. Line, arrow, and freedraw
/// only serialize their point arrays, not x/y/width/height.
void _expectElementsMatch(List<Element> original, List<Element> reloaded) {
  const positionedTypes = {'rectangle', 'ellipse', 'diamond', 'text'};
  const sizedTypes = {'rectangle', 'ellipse', 'diamond'};
  for (var i = 0; i < original.length; i++) {
    expect(reloaded[i].runtimeType, original[i].runtimeType,
        reason: 'Element $i type mismatch');
    if (positionedTypes.contains(original[i].type)) {
      expect(reloaded[i].x, original[i].x,
          reason: 'Element $i x mismatch');
      expect(reloaded[i].y, original[i].y,
          reason: 'Element $i y mismatch');
    }
    if (sizedTypes.contains(original[i].type)) {
      expect(reloaded[i].width, original[i].width,
          reason: 'Element $i width mismatch');
      expect(reloaded[i].height, original[i].height,
          reason: 'Element $i height mismatch');
    }
  }
}
