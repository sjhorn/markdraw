import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/frame_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

void main() {
  group('ExcalidrawJsonCodec — Frame support', () {
    test('serializes FrameElement to JSON with name field', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 100,
        y: 200,
        width: 400,
        height: 300,
        label: 'Section A',
        seed: 42,
      );
      final doc = MarkdrawDocument(sections: [
        SketchSection([frame]),
      ]);
      final json = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final elements = decoded['elements'] as List;
      expect(elements, hasLength(1));
      final el = elements[0] as Map<String, dynamic>;
      expect(el['type'], 'frame');
      expect(el['name'], 'Section A');
      expect(el['x'], 100);
      expect(el['y'], 200);
      expect(el['width'], 400);
      expect(el['height'], 300);
    });

    test('deserializes frame JSON to FrameElement', () {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'elements': [
          {
            'id': 'f1',
            'type': 'frame',
            'x': 100,
            'y': 200,
            'width': 400,
            'height': 300,
            'name': 'Section A',
            'angle': 0,
            'seed': 42,
            'version': 1,
            'versionNonce': 1,
            'isDeleted': false,
            'groupIds': <String>[],
            'frameId': null,
            'opacity': 100,
          },
        ],
      });
      final result = ExcalidrawJsonCodec.parse(json);
      final elements = result.value.allElements;
      expect(elements, hasLength(1));
      final frame = elements[0] as FrameElement;
      expect(frame.type, 'frame');
      expect(frame.label, 'Section A');
      expect(frame.x, 100);
      expect(frame.y, 200);
      expect(frame.width, 400);
      expect(frame.height, 300);
    });

    test('round-trips frame element', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 50,
        y: 60,
        width: 200,
        height: 150,
        label: 'My Frame',
        seed: 99,
      );
      final doc = MarkdrawDocument(sections: [
        SketchSection([frame]),
      ]);
      final json = ExcalidrawJsonCodec.serialize(doc);
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements[0] as FrameElement;
      expect(parsed.label, 'My Frame');
      expect(parsed.x, 50);
      expect(parsed.y, 60);
      expect(parsed.width, 200);
      expect(parsed.height, 150);
    });

    test('round-trips child element with frameId', () {
      final rect = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 50,
        height: 50,
        frameId: 'f1',
        seed: 7,
      );
      final doc = MarkdrawDocument(sections: [
        SketchSection([rect]),
      ]);
      final json = ExcalidrawJsonCodec.serialize(doc);
      final result = ExcalidrawJsonCodec.parse(json);
      final parsed = result.value.allElements[0];
      expect(parsed.frameId, 'f1');
    });

    test('full document round-trip with frame and children', () {
      final frame = FrameElement(
        id: const ElementId('f1'),
        x: 0,
        y: 0,
        width: 400,
        height: 300,
        label: 'Container',
        seed: 1,
      );
      final child = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        frameId: 'f1',
        seed: 2,
      );
      final doc = MarkdrawDocument(sections: [
        SketchSection([frame, child]),
      ]);
      final json = ExcalidrawJsonCodec.serialize(doc);
      final result = ExcalidrawJsonCodec.parse(json);
      final elements = result.value.allElements;
      expect(elements, hasLength(2));
      expect(elements[0], isA<FrameElement>());
      expect((elements[0] as FrameElement).label, 'Container');
      expect(elements[1].frameId, 'f1');
    });

    test('frame without name field defaults to Frame', () {
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'elements': [
          {
            'id': 'f1',
            'type': 'frame',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'angle': 0,
            'seed': 1,
            'version': 1,
            'versionNonce': 1,
            'isDeleted': false,
            'groupIds': <String>[],
            'opacity': 100,
          },
        ],
      });
      final result = ExcalidrawJsonCodec.parse(json);
      final frame = result.value.allElements[0] as FrameElement;
      expect(frame.label, 'Frame');
    });
  });
}
