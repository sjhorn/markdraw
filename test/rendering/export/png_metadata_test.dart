import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

void main() {
  // Minimal valid PNG: 8-byte signature + IHDR chunk + IEND chunk
  Uint8List minimalPng() {
    final builder = BytesBuilder();
    // PNG signature
    builder.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    // IHDR chunk (13 bytes data)
    final ihdrData = Uint8List(13);
    // 1x1 pixel, 8-bit RGB
    ihdrData[0] = 0;
    ihdrData[1] = 0;
    ihdrData[2] = 0;
    ihdrData[3] = 1; // width=1
    ihdrData[4] = 0;
    ihdrData[5] = 0;
    ihdrData[6] = 0;
    ihdrData[7] = 1; // height=1
    ihdrData[8] = 8; // bit depth
    ihdrData[9] = 2; // color type (RGB)
    _writeChunk(builder, 'IHDR', ihdrData);
    // IEND chunk (0 bytes data)
    _writeChunk(builder, 'IEND', Uint8List(0));
    return builder.toBytes();
  }

  group('PngMetadata', () {
    group('injectTextChunk', () {
      test('inserts tEXt chunk into valid PNG', () {
        final png = minimalPng();
        final result = PngMetadata.injectTextChunk(
          png,
          'markdraw',
          'test-data',
        );
        expect(result, isNotNull);
        // Should still be valid PNG (starts with signature)
        expect(result![0], 0x89);
        expect(result[1], 0x50);
        expect(result[2], 0x4E);
        expect(result[3], 0x47);
        // Should be larger than original
        expect(result.length, greaterThan(png.length));
      });

      test('injected chunk can be extracted', () {
        final png = minimalPng();
        const data = 'hello world markdraw data';
        final withChunk = PngMetadata.injectTextChunk(png, 'markdraw', data);
        expect(withChunk, isNotNull);
        final extracted = PngMetadata.extractTextChunk(withChunk!, 'markdraw');
        expect(extracted, equals(data));
      });

      test('returns null for non-PNG bytes', () {
        final notPng = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final result = PngMetadata.injectTextChunk(notPng, 'key', 'val');
        expect(result, isNull);
      });

      test('returns null for bytes shorter than PNG signature', () {
        final tooShort = Uint8List.fromList([0x89, 0x50]);
        final result = PngMetadata.injectTextChunk(tooShort, 'key', 'val');
        expect(result, isNull);
      });

      test('chunk is inserted before IEND', () {
        final png = minimalPng();
        final result = PngMetadata.injectTextChunk(png, 'markdraw', 'data');
        expect(result, isNotNull);
        // IEND should still be the last chunk
        // IEND chunk: length(4) + 'IEND'(4) + crc(4) = 12 bytes at end
        final iendType = String.fromCharCodes(
          result!.sublist(result.length - 12 + 4, result.length - 12 + 8),
        );
        expect(iendType, 'IEND');
      });

      test('preserves existing chunks', () {
        final png = minimalPng();
        final result = PngMetadata.injectTextChunk(png, 'markdraw', 'data');
        expect(result, isNotNull);
        // IHDR should still be the first chunk after signature
        final ihdrType = String.fromCharCodes(result!.sublist(12, 16));
        expect(ihdrType, 'IHDR');
      });

      test('handles large data values', () {
        final png = minimalPng();
        final largeData = 'x' * 10000;
        final result = PngMetadata.injectTextChunk(png, 'markdraw', largeData);
        expect(result, isNotNull);
        final extracted = PngMetadata.extractTextChunk(result!, 'markdraw');
        expect(extracted, equals(largeData));
      });
    });

    group('extractTextChunk', () {
      test('returns null when no tEXt chunk exists', () {
        final png = minimalPng();
        final result = PngMetadata.extractTextChunk(png, 'markdraw');
        expect(result, isNull);
      });

      test('returns null for non-PNG bytes', () {
        final notPng = Uint8List.fromList([1, 2, 3, 4, 5]);
        final result = PngMetadata.extractTextChunk(notPng, 'markdraw');
        expect(result, isNull);
      });

      test('returns null when keyword does not match', () {
        final png = minimalPng();
        final withChunk = PngMetadata.injectTextChunk(png, 'other', 'data');
        final result = PngMetadata.extractTextChunk(withChunk!, 'markdraw');
        expect(result, isNull);
      });

      test('extracts correct value when multiple tEXt chunks exist', () {
        final png = minimalPng();
        final withAuthor = PngMetadata.injectTextChunk(png, 'author', 'Alice');
        final withBoth = PngMetadata.injectTextChunk(
          withAuthor!,
          'markdraw',
          'scene-data',
        );
        final extracted = PngMetadata.extractTextChunk(withBoth!, 'markdraw');
        expect(extracted, 'scene-data');
        final authorExtracted = PngMetadata.extractTextChunk(
          withBoth,
          'author',
        );
        expect(authorExtracted, 'Alice');
      });

      test('handles empty value', () {
        final png = minimalPng();
        final withChunk = PngMetadata.injectTextChunk(png, 'markdraw', '');
        final extracted = PngMetadata.extractTextChunk(withChunk!, 'markdraw');
        expect(extracted, '');
      });
    });

    group('embedMarkdrawData / extractMarkdrawData', () {
      test('embeds and extracts scene data round-trip', () {
        final png = minimalPng();
        final scene = Scene().addElement(
          RectangleElement(
            id: const ElementId('r1'),
            x: 10,
            y: 20,
            width: 100,
            height: 80,
            strokeColor: '#ff0000',
            seed: 42,
          ),
        );
        final withData = PngMetadata.embedMarkdrawData(png, scene);
        expect(withData, isNotNull);

        final extracted = PngMetadata.extractMarkdrawData(withData!);
        expect(extracted, isNotNull);
        // Should have one element with matching properties
        expect(extracted!.activeElements.length, 1);
        final elem = extracted.activeElements.first;
        expect(elem, isA<RectangleElement>());
        expect(elem.x, 10);
        expect(elem.y, 20);
        expect(elem.width, 100);
        expect(elem.height, 80);
        expect((elem as RectangleElement).strokeColor, '#ff0000');
      });

      test('round-trips multiple element types', () {
        final png = minimalPng();
        var scene = Scene();
        scene = scene.addElement(
          RectangleElement(
            id: const ElementId('r1'),
            x: 0,
            y: 0,
            width: 50,
            height: 50,
            seed: 1,
          ),
        );
        scene = scene.addElement(
          EllipseElement(
            id: const ElementId('e1'),
            x: 100,
            y: 0,
            width: 60,
            height: 60,
            seed: 2,
          ),
        );
        scene = scene.addElement(
          ArrowElement(
            id: const ElementId('a1'),
            x: 0,
            y: 100,
            width: 100,
            height: 0,
            points: [const Point(0, 0), const Point(100, 0)],
            seed: 3,
          ),
        );

        final withData = PngMetadata.embedMarkdrawData(png, scene);
        final extracted = PngMetadata.extractMarkdrawData(withData!);
        expect(extracted!.activeElements.length, 3);
      });

      test('extractMarkdrawData returns null for plain PNG', () {
        final png = minimalPng();
        final result = PngMetadata.extractMarkdrawData(png);
        expect(result, isNull);
      });

      test('extractMarkdrawData returns null for non-PNG', () {
        final result = PngMetadata.extractMarkdrawData(
          Uint8List.fromList([1, 2, 3]),
        );
        expect(result, isNull);
      });

      test('round-trips text elements with special characters', () {
        final png = minimalPng();
        final scene = Scene().addElement(
          TextElement(
            id: const ElementId('t1'),
            x: 0,
            y: 0,
            width: 100,
            height: 20,
            text: 'Hello world & friends!',
          ),
        );
        final withData = PngMetadata.embedMarkdrawData(png, scene);
        final extracted = PngMetadata.extractMarkdrawData(withData!);
        final textElem = extracted!.activeElements.first as TextElement;
        expect(textElem.text, 'Hello world & friends!');
      });
    });

    group('extractExcalidrawData', () {
      /// Creates a minimal Excalidraw scene JSON string with one rectangle.
      String excalidrawSceneJson({
        String id = 'rect1',
        double x = 10,
        double y = 20,
        double width = 100,
        double height = 80,
      }) {
        return jsonEncode({
          'type': 'excalidraw',
          'version': 2,
          'source': 'test',
          'elements': [
            {
              'type': 'rectangle',
              'id': id,
              'x': x,
              'y': y,
              'width': width,
              'height': height,
              'strokeColor': '#000000',
              'backgroundColor': 'transparent',
              'fillStyle': 'hachure',
              'strokeWidth': 1,
              'roughness': 1,
              'opacity': 100,
              'angle': 0,
              'seed': 42,
              'version': 1,
              'isDeleted': false,
              'groupIds': <String>[],
              'boundElements': null,
              'roundness': null,
            },
          ],
          'appState': {'viewBackgroundColor': '#ffffff'},
          'files': <String, Object?>{},
        });
      }

      /// Converts a UTF-8 string to a Latin-1 "byte string" (each byte as
      /// a char code ≤ 255), matching Excalidraw's bstring encoding.
      String toByteString(Uint8List bytes) {
        return String.fromCharCodes(bytes);
      }

      /// Injects Excalidraw data into a PNG as a tEXt chunk.
      Uint8List injectExcalidraw(Uint8List png, String payload) {
        return PngMetadata.injectTextChunk(
          png,
          'application/vnd.excalidraw+json',
          payload,
        )!;
      }

      test('returns null for plain PNG (no Excalidraw chunk)', () {
        final png = minimalPng();
        final result = PngMetadata.extractExcalidrawData(png);
        expect(result, isNull);
      });

      test('returns null for non-PNG bytes', () {
        final result = PngMetadata.extractExcalidrawData(
          Uint8List.fromList([1, 2, 3]),
        );
        expect(result, isNull);
      });

      test('extracts v1 legacy format (direct scene JSON)', () {
        final png = minimalPng();
        final sceneJson = excalidrawSceneJson();
        // V1: raw JSON stored directly as the tEXt value
        // Need to encode as Latin-1 safe string
        final withData = injectExcalidraw(png, sceneJson);

        final scene = PngMetadata.extractExcalidrawData(withData);
        expect(scene, isNotNull);
        expect(scene!.activeElements.length, 1);
        final elem = scene.activeElements.first;
        expect(elem, isA<RectangleElement>());
        expect(elem.x, 10);
        expect(elem.y, 20);
        expect(elem.width, 100);
        expect(elem.height, 80);
      });

      test('extracts v2 uncompressed format', () {
        final png = minimalPng();
        final sceneJson = excalidrawSceneJson();
        final sceneBytes = utf8.encode(sceneJson);
        final byteStr = toByteString(Uint8List.fromList(sceneBytes));

        final wrapper = jsonEncode({
          'encoded': byteStr,
          'encoding': 'bstring',
          'compressed': false,
          'version': '1',
        });

        final withData = injectExcalidraw(png, wrapper);
        final scene = PngMetadata.extractExcalidrawData(withData);
        expect(scene, isNotNull);
        expect(scene!.activeElements.length, 1);
        expect(scene.activeElements.first, isA<RectangleElement>());
      });

      test('extracts v2 compressed format', () {
        final png = minimalPng();
        final sceneJson = excalidrawSceneJson();
        final sceneBytes = utf8.encode(sceneJson);

        // Compress with zlib (same as pako.deflate)
        final encoder = ZLibEncoder();
        final compressed = encoder.convert(sceneBytes);
        final byteStr = toByteString(Uint8List.fromList(compressed));

        final wrapper = jsonEncode({
          'encoded': byteStr,
          'encoding': 'bstring',
          'compressed': true,
          'version': '1',
        });

        final withData = injectExcalidraw(png, wrapper);
        final scene = PngMetadata.extractExcalidrawData(withData);
        expect(scene, isNotNull);
        expect(scene!.activeElements.length, 1);
        expect(scene.activeElements.first, isA<RectangleElement>());
      });

      test('returns null for invalid JSON in tEXt chunk', () {
        final png = minimalPng();
        final withData = injectExcalidraw(png, 'not valid json {{{');
        final result = PngMetadata.extractExcalidrawData(withData);
        expect(result, isNull);
      });

      test('returns null for JSON that is neither v1 nor v2', () {
        final png = minimalPng();
        final wrapper = jsonEncode({'foo': 'bar', 'baz': 123});
        final withData = injectExcalidraw(png, wrapper);
        final result = PngMetadata.extractExcalidrawData(withData);
        expect(result, isNull);
      });

      test('returns null for corrupt compressed data', () {
        final png = minimalPng();
        // Garbage bytes that aren't valid zlib
        final corruptBytes = Uint8List.fromList([0x78, 0x9C, 1, 2, 3, 4, 5]);
        final byteStr = toByteString(corruptBytes);

        final wrapper = jsonEncode({
          'encoded': byteStr,
          'encoding': 'bstring',
          'compressed': true,
          'version': '1',
        });

        final withData = injectExcalidraw(png, wrapper);
        final result = PngMetadata.extractExcalidrawData(withData);
        expect(result, isNull);
      });

      test('extracts scene with multiple elements', () {
        final png = minimalPng();
        final sceneJson = jsonEncode({
          'type': 'excalidraw',
          'version': 2,
          'source': 'test',
          'elements': [
            {
              'type': 'rectangle',
              'id': 'r1',
              'x': 0,
              'y': 0,
              'width': 50,
              'height': 50,
              'strokeColor': '#000000',
              'backgroundColor': 'transparent',
              'fillStyle': 'hachure',
              'strokeWidth': 1,
              'roughness': 1,
              'opacity': 100,
              'angle': 0,
              'seed': 1,
              'version': 1,
              'isDeleted': false,
              'groupIds': <String>[],
              'boundElements': null,
              'roundness': null,
            },
            {
              'type': 'ellipse',
              'id': 'e1',
              'x': 100,
              'y': 0,
              'width': 60,
              'height': 60,
              'strokeColor': '#000000',
              'backgroundColor': 'transparent',
              'fillStyle': 'hachure',
              'strokeWidth': 1,
              'roughness': 1,
              'opacity': 100,
              'angle': 0,
              'seed': 2,
              'version': 1,
              'isDeleted': false,
              'groupIds': <String>[],
              'boundElements': null,
              'roundness': null,
            },
            {
              'type': 'diamond',
              'id': 'd1',
              'x': 200,
              'y': 0,
              'width': 40,
              'height': 40,
              'strokeColor': '#000000',
              'backgroundColor': 'transparent',
              'fillStyle': 'hachure',
              'strokeWidth': 1,
              'roughness': 1,
              'opacity': 100,
              'angle': 0,
              'seed': 3,
              'version': 1,
              'isDeleted': false,
              'groupIds': <String>[],
              'boundElements': null,
              'roundness': null,
            },
          ],
          'appState': {'viewBackgroundColor': '#ffffff'},
          'files': <String, Object?>{},
        });

        final withData = injectExcalidraw(png, sceneJson);
        final scene = PngMetadata.extractExcalidrawData(withData);
        expect(scene, isNotNull);
        expect(scene!.activeElements.length, 3);
        expect(scene.activeElements[0], isA<RectangleElement>());
        expect(scene.activeElements[1], isA<EllipseElement>());
        expect(scene.activeElements[2], isA<DiamondElement>());
      });

      test('markdraw and Excalidraw chunks coexist independently', () {
        final png = minimalPng();

        // Embed markdraw data with distinctive properties
        final markdrawScene = Scene().addElement(
          RectangleElement(
            id: const ElementId('md1'),
            x: 500,
            y: 600,
            width: 30,
            height: 30,
            seed: 1,
          ),
        );
        final withMarkdraw = PngMetadata.embedMarkdrawData(png, markdrawScene);

        // Also embed Excalidraw data with different properties
        final excalidrawJson = excalidrawSceneJson(
          id: 'ex1',
          x: 100,
          y: 100,
          width: 200,
          height: 200,
        );
        final withBoth = injectExcalidraw(withMarkdraw!, excalidrawJson);

        // Extract markdraw — should get markdraw scene (check by properties)
        final mdScene = PngMetadata.extractMarkdrawData(withBoth);
        expect(mdScene, isNotNull);
        expect(mdScene!.activeElements.length, 1);
        expect(mdScene.activeElements.first.x, 500);
        expect(mdScene.activeElements.first.y, 600);
        expect(mdScene.activeElements.first.width, 30);

        // Extract Excalidraw — should get Excalidraw scene
        final exScene = PngMetadata.extractExcalidrawData(withBoth);
        expect(exScene, isNotNull);
        expect(exScene!.activeElements.length, 1);
        expect(exScene.activeElements.first.x, 100);
        expect(exScene.activeElements.first.width, 200);
      });
    });
  });
}

/// Helper to write a PNG chunk to a BytesBuilder.
void _writeChunk(BytesBuilder builder, String type, Uint8List data) {
  // Length (4 bytes, big-endian)
  final length = data.length;
  builder.add([
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
  ]);
  // Type (4 bytes)
  final typeBytes = utf8.encode(type);
  builder.add(typeBytes);
  // Data
  builder.add(data);
  // CRC32 (over type + data)
  final crcInput = Uint8List(4 + data.length);
  crcInput.setAll(0, typeBytes);
  crcInput.setAll(4, data);
  final crc = _crc32(crcInput);
  builder.add([
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
}

/// Simple CRC32 for PNG chunks (same table as used in the implementation).
int _crc32(Uint8List data) {
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (int j = 0; j < 8; j++) {
      if ((crc & 1) == 1) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
