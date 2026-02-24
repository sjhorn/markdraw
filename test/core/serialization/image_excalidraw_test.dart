import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/image_crop.dart';
import 'package:markdraw/src/core/elements/image_element.dart';
import 'package:markdraw/src/core/elements/image_file.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

String _wrapElements(List<Map<String, dynamic>> elements,
    {Map<String, dynamic>? files}) {
  return jsonEncode({
    'type': 'excalidraw',
    'version': 2,
    'source': 'test',
    'elements': elements,
    'appState': {},
    'files': files ?? {},
  });
}

Map<String, dynamic> _imageElement({
  String id = 'img1',
  double x = 100,
  double y = 200,
  double width = 400,
  double height = 300,
  String fileId = 'abc12345',
  List<double>? scale,
  Map<String, dynamic>? crop,
}) {
  return {
    'id': id,
    'type': 'image',
    'x': x,
    'y': y,
    'width': width,
    'height': height,
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
    'versionNonce': 1,
    'isDeleted': false,
    'groupIds': <String>[],
    'boundElements': null,
    'updated': 1000,
    'link': null,
    'locked': false,
    'fileId': fileId,
    'status': 'saved',
    if (scale != null) 'scale': scale,
    if (crop != null) 'crop': crop,
  };
}

void main() {
  group('ExcalidrawJsonCodec - image', () {
    test('serializes ImageElement', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 100,
              y: 200,
              width: 400,
              height: 300,
              fileId: 'abc12345',
              imageScale: 1.5,
              seed: 42,
            ),
          ]),
        ],
      );

      final json = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final elements = decoded['elements'] as List;
      expect(elements, hasLength(1));

      final el = elements[0] as Map<String, dynamic>;
      expect(el['type'], 'image');
      expect(el['fileId'], 'abc12345');
      expect(el['scale'], [1.5, 1.5]);
      expect(el['status'], 'saved');
    });

    test('deserializes image element', () {
      final json = _wrapElements([_imageElement()]);
      final result = ExcalidrawJsonCodec.parse(json);

      expect(result.value.allElements, hasLength(1));
      final img = result.value.allElements.first as ImageElement;
      expect(img.fileId, 'abc12345');
      expect(img.x, 100);
      expect(img.y, 200);
      expect(img.width, 400);
      expect(img.height, 300);
    });

    test('round-trips ImageElement', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 100,
              y: 200,
              width: 400,
              height: 300,
              fileId: 'abc12345',
              imageScale: 2.0,
              seed: 42,
            ),
          ]),
        ],
      );

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);
      final img = parsed.value.allElements.first as ImageElement;
      expect(img.fileId, 'abc12345');
      expect(img.imageScale, 2.0);
    });

    test('serializes and parses files map', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 0,
              y: 0,
              width: 100,
              height: 100,
              fileId: 'abc12345',
              seed: 42,
            ),
          ]),
        ],
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        },
      );

      final json = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      expect(files, contains('abc12345'));
      final fileData = files['abc12345'] as Map<String, dynamic>;
      expect(fileData['mimeType'], 'image/png');
      expect(fileData['dataURL'], startsWith('data:image/png;base64,'));
    });

    test('parses files from data URL', () {
      final b64 = base64Encode([1, 2, 3]);
      final json = _wrapElements(
        [_imageElement()],
        files: {
          'abc12345': {
            'mimeType': 'image/png',
            'id': 'abc12345',
            'dataURL': 'data:image/png;base64,$b64',
          },
        },
      );

      final result = ExcalidrawJsonCodec.parse(json);
      expect(result.value.files, contains('abc12345'));
      expect(result.value.files['abc12345']!.mimeType, 'image/png');
      expect(result.value.files['abc12345']!.bytes, [1, 2, 3]);
    });

    test('image with crop round-trips', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 0,
              y: 0,
              width: 100,
              height: 100,
              fileId: 'abc12345',
              crop: const ImageCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6),
              seed: 42,
            ),
          ]),
        ],
      );

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);
      final img = parsed.value.allElements.first as ImageElement;
      expect(img.crop!.x, 0.1);
      expect(img.crop!.y, 0.2);
      expect(img.crop!.width, 0.8);
      expect(img.crop!.height, 0.6);
    });

    test('full document with images round-trips', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ImageElement(
              id: const ElementId('img1'),
              x: 50,
              y: 60,
              width: 200,
              height: 150,
              fileId: 'abc12345',
              imageScale: 1.5,
              seed: 42,
            ),
          ]),
        ],
        files: {
          'abc12345': ImageFile(
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([10, 20, 30, 40]),
          ),
        },
      );

      final json = ExcalidrawJsonCodec.serialize(doc);
      final parsed = ExcalidrawJsonCodec.parse(json);

      expect(parsed.value.allElements, hasLength(1));
      final img = parsed.value.allElements.first as ImageElement;
      expect(img.fileId, 'abc12345');
      expect(img.imageScale, 1.5);

      expect(parsed.value.files, contains('abc12345'));
      expect(parsed.value.files['abc12345']!.mimeType, 'image/jpeg');
      expect(parsed.value.files['abc12345']!.bytes, [10, 20, 30, 40]);
    });
  });
}
